//
//  TrafficModel.swift
//  NetworkStatusBar
//
//  Everything the UI reads.
//

import Foundation

/// Holds the current readings and folds each new sample into them.
///
/// Main-actor bound: the sampler hops here, and only SwiftUI reads it.
@Observable
@MainActor
final class TrafficModel {
  /// The menu bar figures.
  var total = TrafficCounters.zero
  /// The process list: live rows first, departed ones greyed at the end.
  var processes: [ProcessTraffic] = []
  /// Per-interface rates, for the panel header.
  var interfaces: [String: TrafficCounters] = [:]
  /// Every process name ever seen, for the blacklist picker.
  var seenProcessNames: Set<String> = []
  /// Chart history, oldest first.
  var history: [TrafficSample] = []

  /// 120 samples is about two minutes at a 1 s refresh, twenty at 10 s.
  static let historyCapacity = 120
  /// How long a departed row lingers, greyed, before it is dropped.
  private static let linger: TimeInterval = 3

  @ObservationIgnored private let settings: AppSettings
  /// When each row was last reported, so one that stops being reported can be
  /// held briefly instead of vanishing mid-glance.
  @ObservationIgnored private var lastSeen: [String: Date] = [:]

  init(settings: AppSettings = .shared) {
    self.settings = settings
  }

  func apply(_ snapshot: TrafficSnapshot) {
    for row in snapshot.processes where !row.name.isEmpty {
      seenProcessNames.insert(row.name)
    }

    total = snapshot.total
    interfaces = snapshot.interfaces

    history.append(TrafficSample(total: snapshot.total, interfaces: snapshot.interfaces))
    if history.count > Self.historyCapacity {
      history.removeFirst(history.count - Self.historyCapacity)
    }

    let threshold = settings.minTrafficThreshold
    var fresh = snapshot.processes.filter {
      $0.total >= threshold && !settings.isBlacklisted($0.name)
    }

    // Hold rows that stopped being reported for a moment rather than dropping
    // them the instant traffic dips, which makes the list flicker as processes
    // go quiet and start up again. A row's last reading is reused, so the
    // greyed-out figure is what it last showed.
    let now = Date()
    for row in fresh {
      lastSeen[row.id] = now
    }
    let live = Set(fresh.map { $0.id })
    let leaving = processes.filter {
      !live.contains($0.id)
        && now.timeIntervalSince(lastSeen[$0.id] ?? .distantPast) < Self.linger
    }
    lastSeen = lastSeen.filter { now.timeIntervalSince($0.value) < Self.linger }

    switch settings.sortKey {
    case .total:
      fresh.sort { $0.total > $1.total }
    case .download:
      fresh.sort { $0.inbounds > $1.inbounds }
    case .upload:
      fresh.sort { $0.outbounds > $1.outbounds }
    }
    // Departing rows sink to the bottom so they never displace anything moving.
    processes = fresh + leaving.map {
      var stale = $0
      stale.isStale = true
      return stale
    }
  }

  /// Called when the refresh interval changes: samples taken at different
  /// spacings would otherwise be drawn as though they were evenly spaced.
  func resetHistory() {
    history.removeAll()
  }
}
