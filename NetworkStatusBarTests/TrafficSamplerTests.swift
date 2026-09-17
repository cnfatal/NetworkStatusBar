//
//  TrafficSamplerTests.swift
//  NetworkStatusBarTests
//
//  Replays nettop-shaped rows through the sampler, so the parsing and the
//  per-interval arithmetic are checked without spawning anything.
//

import XCTest

@testable import NetworkStatusBar

final class TrafficSamplerTests: XCTestCase {

  // MARK: - Fixtures

  /// nettop prints a process row followed by one row per connection. The parser
  /// reads fields 1, 4 and 5 of a process row, and 1, 2, 4 and 5 of a
  /// connection row, so the rest are left blank here.
  private func process(_ label: String, in inbounds: Int, out outbounds: Int) -> String {
    "t,\(label),,,\(inbounds),\(outbounds)"
  }

  private func connection(
    _ tuple: String, _ interface: String, in inbounds: Int, out outbounds: Int
  ) -> String {
    "t,\(tuple),\(interface),Established,\(inbounds),\(outbounds)"
  }

  /// Collects what the sampler reports.
  private func makeReportingSampler() -> (TrafficSampler, () -> TrafficSnapshot?) {
    let sampler = TrafficSampler()
    var latest: TrafficSnapshot?
    sampler.onSample = { latest = $0 }
    return (sampler, { latest })
  }

  // MARK: - Parsing

  func testNameSplitsOnTheLastDot() {
    let (sampler, reported) = makeReportingSampler()

    sampler.consume([process("io.nekohasekai..896", in: 0, out: 0)])
    sampler.consume([process("io.nekohasekai..896", in: 0, out: 100)])

    let row = reported()?.processes.first
    // Splitting on the first dot would give name "io" and no pid at all.
    XCTAssertEqual(row?.name, "io.nekohasekai.")
    XCTAssertEqual(row?.pid, 896)
  }

  func testOrdinaryNameSplitsCleanly() {
    let (sampler, reported) = makeReportingSampler()

    sampler.consume([process("Google Chrome.95928", in: 0, out: 0)])
    sampler.consume([process("Google Chrome.95928", in: 0, out: 2_048)])

    let row = reported()?.processes.first
    XCTAssertEqual(row?.name, "Google Chrome")
    XCTAssertEqual(row?.pid, 95928)
  }

  func testTruncatedRowDoesNotSinkTheSample() {
    let (sampler, reported) = makeReportingSampler()

    sampler.consume([process("a.1", in: 0, out: 0)])
    // nettop terminated mid-row leaves a partial line behind.
    sampler.consume([process("a.1", in: 0, out: 1_000), "13:00:00.000000,Google Chrome.95"])

    XCTAssertEqual(reported()?.processes.map(\.name), ["a"])
  }

  // MARK: - Deltas

  func testFirstSampleOnlyEstablishesABaseline() {
    let sampler = TrafficSampler()
    var calls = 0
    sampler.onSample = { _ in calls += 1 }

    sampler.consume([process("a.1", in: 5_000, out: 5_000)])

    // Reporting here would present a process's whole lifetime as one interval.
    XCTAssertEqual(calls, 0)
  }

  func testRatesAreTheDifferenceBetweenSamples() {
    let (sampler, reported) = makeReportingSampler()

    sampler.consume([process("a.1", in: 1_000, out: 2_000)])
    sampler.consume([process("a.1", in: 1_500, out: 2_400)])

    let row = reported()?.processes.first
    XCTAssertEqual(row?.inbounds, 500)
    XCTAssertEqual(row?.outbounds, 400)
  }

  func testExitingProcessIsDroppedRatherThanSubtracted() {
    let (sampler, reported) = makeReportingSampler()

    sampler.consume([process("a.1", in: 5_000, out: 5_000)])
    sampler.consume([process("b.2", in: 1_000, out: 0)])

    XCTAssertEqual(reported()?.processes.map(\.name), ["b"])
    let row = reported()?.processes.first
    XCTAssertEqual(row?.inbounds, 1_000)
  }

  func testCounterResetDoesNotProduceANegativeRate() {
    let (sampler, reported) = makeReportingSampler()

    sampler.consume([process("a.1", in: 9_000, out: 9_000)])
    sampler.consume([process("a.1", in: 100, out: 50)])

    let row = reported()?.processes.first
    XCTAssertEqual(row?.inbounds, 0)
    XCTAssertEqual(row?.outbounds, 0)
  }

  // MARK: - Interfaces

  func testInterfaceTotalsAreSummedAcrossProcesses() {
    let (sampler, reported) = makeReportingSampler()

    sampler.consume([
      process("a.1", in: 0, out: 0),
      connection("tcp4 x<->y", "en0", in: 0, out: 0),
      process("b.2", in: 0, out: 0),
      connection("tcp4 p<->q", "lo0", in: 0, out: 0),
    ])
    sampler.consume([
      process("a.1", in: 0, out: 0),
      connection("tcp4 x<->y", "en0", in: 0, out: 3_000),
      process("b.2", in: 0, out: 0),
      connection("tcp4 p<->q", "lo0", in: 0, out: 1_000),
    ])

    XCTAssertEqual(reported()?.interfaces["en0"]?.outbounds, 3_000)
    XCTAssertEqual(reported()?.interfaces["lo0"]?.outbounds, 1_000)
  }

  /// The reason interfaces are tracked per socket rather than as a per-process
  /// sum: a closing socket removes its whole cumulative counter from the sum,
  /// which would drag the interface to zero and swallow the traffic the
  /// surviving socket did in the same interval.
  func testClosingSocketDoesNotSwallowTheSurvivingOne() {
    let (sampler, reported) = makeReportingSampler()

    sampler.consume([
      process("a.1", in: 0, out: 0),
      connection("tcp4 x<->closing", "en0", in: 0, out: 100_000),
      connection("tcp4 x<->staying", "en0", in: 0, out: 0),
    ])
    // The first socket is gone; the second carried 4 KB this interval.
    sampler.consume([
      process("a.1", in: 0, out: 0),
      connection("tcp4 x<->staying", "en0", in: 0, out: 4_000),
    ])

    XCTAssertEqual(reported()?.interfaces["en0"]?.outbounds, 4_000)
  }

  func testSocketWithNoPreviousReadingContributesNothing() {
    let (sampler, reported) = makeReportingSampler()

    sampler.consume([
      process("a.1", in: 0, out: 0),
      connection("tcp4 x<->y", "en0", in: 0, out: 0),
    ])
    // A socket that just appeared has no baseline; counting its lifetime would
    // show hours of traffic in one interval.
    sampler.consume([
      process("a.1", in: 0, out: 0),
      connection("tcp4 x<->y", "en0", in: 0, out: 0),
      connection("tcp4 x<->new", "en0", in: 0, out: 900_000),
    ])

    XCTAssertEqual(reported()?.interfaces["en0"]?.outbounds, 0)
  }
}
