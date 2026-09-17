//
//  TrafficTypes.swift
//  NetworkStatusBar
//
//  Value types shared by the sampler, the model and the views.
//

import Foundation

/// A pair of byte counters.
struct TrafficCounters: Equatable {
  var inbounds: Int = 0
  var outbounds: Int = 0

  var total: Int { inbounds + outbounds }

  static let zero = TrafficCounters()

  /// Traffic since an earlier reading. Clamped at zero so a process exiting or
  /// a counter resetting can never subtract from a total.
  func since(_ previous: TrafficCounters) -> TrafficCounters {
    TrafficCounters(
      inbounds: max(0, inbounds - previous.inbounds),
      outbounds: max(0, outbounds - previous.outbounds))
  }

  mutating func add(_ other: TrafficCounters) {
    inbounds += other.inbounds
    outbounds += other.outbounds
  }
}

/// One process, as listed in the panel.
struct ProcessTraffic: Identifiable {
  var id: String { "\(pid).\(name)" }
  var pid: Int = 0
  var name: String = ""
  var inbounds: Int = 0
  var outbounds: Int = 0
  /// Set on rows that stopped being reported and are being held briefly before
  /// removal. Purely a display concern, so the sampler never sets it.
  var isStale: Bool = false
  /// Derived rather than stored, so it cannot drift out of sync with the two
  /// components when a row is built from only part of them.
  var total: Int { inbounds + outbounds }
}

/// One interface's rates, for listing.
struct InterfaceRate: Identifiable {
  var id: String { name }
  let name: String
  let counters: TrafficCounters
}

extension Dictionary where Key == String, Value == TrafficCounters {
  /// Interfaces carrying traffic, busiest first.
  var activeInterfaces: [InterfaceRate] {
    filter { $0.value.total > 0 }
      .sorted { $0.value.total > $1.value.total }
      .map { InterfaceRate(name: $0.key, counters: $0.value) }
  }
}

/// One sample as delivered by the sampler.
struct TrafficSnapshot {
  var total: TrafficCounters = .zero
  var processes: [ProcessTraffic] = []
  var interfaces: [String: TrafficCounters] = [:]
}

/// One entry in the chart's history: the total it plots, plus the per-interface
/// split the hover readout needs.
///
/// The two are kept separately rather than deriving the total from the split:
/// nettop's per-connection counters account for slightly less than its
/// per-process totals, so a derived total would not match the menu bar figure.
struct TrafficSample {
  var total: TrafficCounters = .zero
  var interfaces: [String: TrafficCounters] = [:]
}
