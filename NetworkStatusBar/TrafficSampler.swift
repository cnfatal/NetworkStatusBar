//
//  TrafficSampler.swift
//  NetworkStatusBar
//
//  Drives nettop and turns its output into per-process and per-interface rates.
//

import Foundation

/// Runs one `nettop` process and reports the rates it implies.
///
/// `run` and `stop` are called from different threads, so the baseline, the
/// process handle and the handler are all reachable only under `lock`. That
/// discipline is what justifies the unchecked `Sendable` conformance.
final class TrafficSampler: @unchecked Sendable {
  /// Called on the sampler's own thread, never while the lock is held.
  var onSample: (TrafficSnapshot) -> Void {
    get { lock.withLock { handler } }
    set { lock.withLock { handler = newValue } }
  }

  private let lock = NSLock()
  private var handler: (TrafficSnapshot) -> Void = { _ in }
  private var lastSample: Sample?
  private var process: Process?

  func run(refreshSeconds: Int = 1) {
    stop()

    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
    // -n skips reverse DNS: resolved hostnames are never displayed and cost
    // both time and output size. No -P, because it is the per-connection rows
    // that carry the interface each flow used; -P leaves that column empty.
    proc.arguments = ["-n", "-L", "0", "-s", "\(refreshSeconds)"]

    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = pipe
    proc.standardInput = Pipe()

    Task { [weak self] in
      var lines: [String] = []
      for try await line in pipe.fileHandleForReading.bytes.lines {
        if line.hasPrefix("time") {
          self?.consume(lines)
          lines = []
        }
        lines.append(line)
      }
    }

    lock.lock()
    process = proc
    lock.unlock()

    try? proc.run()
    proc.waitUntilExit()
  }

  /// Terminates the running sampler.
  ///
  /// Waits for the child to exit rather than returning immediately. nettop dies
  /// promptly on SIGTERM so the wait is short, and it guarantees the child is
  /// gone before `run` starts its replacement — otherwise two nettops overlap.
  func stop() {
    lock.lock()
    let proc = process
    process = nil
    lock.unlock()

    if let proc = proc, proc.isRunning {
      proc.terminate()
      proc.waitUntilExit()
    }
  }

  /// Consumes one sample of raw output. Internal rather than private so tests
  /// can replay recorded nettop output instead of spawning it.
  func consume(_ lines: [String]) {
    guard !lines.isEmpty else {
      return
    }

    lock.lock()
    let snapshot = advance(with: lines)
    // Read the handler directly rather than through `onSample`: the lock is not
    // recursive, and the call itself is deliberately made outside the lock so
    // that a handler is free to call back into the sampler.
    let respond = handler
    lock.unlock()

    if let snapshot = snapshot {
      respond(snapshot)
    }
  }

  /// Folds a sample into the baseline and returns the rates since the previous
  /// one. Callers must hold `lock`, and this must not call out.
  private func advance(with lines: [String]) -> TrafficSnapshot? {
    let sample = Self.parse(lines)
    guard let previous = lastSample else {
      // The first sample only establishes a baseline.
      lastSample = sample
      return nil
    }
    lastSample = sample

    var processes: [ProcessTraffic] = []
    for (label, counters) in sample.processes {
      let delta = counters.since(previous.processes[label] ?? .zero)
      var row = ProcessTraffic()
      // nettop labels every row "<name>.<pid>" and process names frequently
      // contain dots, so split on the last one rather than the first.
      if let dot = label.lastIndex(of: ".") {
        row.name = String(label[label.startIndex..<dot])
        row.pid = Int(label[label.index(after: dot)...]) ?? 0
      } else {
        row.name = label
      }
      row.inbounds = delta.inbounds
      row.outbounds = delta.outbounds
      processes.append(row)
    }

    var interfaces: [String: TrafficCounters] = [:]
    for (key, connection) in sample.connections {
      // A socket with no earlier reading has no baseline, so it contributes
      // nothing this round rather than its whole lifetime in one sample.
      guard let before = previous.connections[key] else {
        continue
      }
      interfaces[connection.interface, default: .zero]
        .add(connection.counters.since(before.counters))
    }

    var total = TrafficCounters.zero
    for row in processes {
      total.add(TrafficCounters(inbounds: row.inbounds, outbounds: row.outbounds))
    }

    return TrafficSnapshot(total: total, processes: processes, interfaces: interfaces)
  }

  /// Splits one sample's lines into per-process and per-connection counters.
  ///
  /// nettop prints a process row followed by one row per connection, so a
  /// connection belongs to the process row above it. Rows that are too short,
  /// which is what a truncated final line looks like, are skipped rather than
  /// failing the whole sample.
  private static func parse(_ lines: [String]) -> Sample {
    var sample = Sample()
    var owner: String?

    for line in lines {
      let fields = line.split(separator: ",", omittingEmptySubsequences: false)
      // Both row shapes carry name, interface, bytes_in and bytes_out at the
      // same indexes.
      guard fields.count >= 6 else {
        continue
      }
      let label = String(fields[1])

      if label.contains("<->") {
        guard let owner = owner else {
          continue
        }
        let interface = String(fields[2])
        // Rows with no interface are the "*:*<->*:*" placeholders, which carry
        // no traffic of their own.
        guard !interface.isEmpty else {
          continue
        }
        sample.connections["\(owner)|\(label)"] = Connection(
          interface: interface,
          counters: TrafficCounters(
            inbounds: Int(fields[4]) ?? 0,
            outbounds: Int(fields[5]) ?? 0))
      } else if !label.isEmpty {
        // A process row. Its counters are the authoritative per-process total;
        // the connection rows below it only break that total down.
        owner = label
        sample.processes[label] = TrafficCounters(
          inbounds: Int(fields[4]) ?? 0,
          outbounds: Int(fields[5]) ?? 0)
      }
    }

    return sample
  }
}

/// One sample of nettop output, reduced to cumulative counters.
private struct Sample {
  /// Keyed by the "name.pid" label nettop uses.
  var processes: [String: TrafficCounters] = [:]
  /// One entry per socket, so each connection is measured against its own
  /// previous reading. Summing a process's connections per interface and
  /// diffing that would break whenever a socket closes, because the sum drops
  /// even though no traffic was undone.
  var connections: [String: Connection] = [:]
}

private struct Connection {
  var interface: String
  var counters: TrafficCounters
}
