//
//  AppSettings.swift
//  NetworkStatusBar
//
//  Preferences, persisted to UserDefaults.
//

import Foundation
import Observation

/// Which column the process list is ordered by.
enum SortKey: String, CaseIterable {
  case total
  case download
  case upload
}

@Observable
final class AppSettings {
  static let shared = AppSettings()

  @ObservationIgnored private let defaults = UserDefaults.standard

  private enum Keys {
    static let refreshInterval = "refreshInterval"
    static let blacklist = "blacklist"
    static let minTrafficThreshold = "minTrafficThreshold"
    static let sortKey = "sortKey"
  }

  /// Refresh interval in seconds (1-10)
  var refreshInterval: Int {
    didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
  }

  /// Blacklisted app names that won't appear in the details list
  var blacklist: [String] {
    didSet { defaults.set(blacklist, forKey: Keys.blacklist) }
  }

  /// Minimum traffic threshold in bytes to show an app (default 1024)
  var minTrafficThreshold: Int {
    didSet { defaults.set(minTrafficThreshold, forKey: Keys.minTrafficThreshold) }
  }

  /// Which column the process list is ordered by
  var sortKey: SortKey {
    didSet { defaults.set(sortKey.rawValue, forKey: Keys.sortKey) }
  }

  private init() {
    let interval = defaults.integer(forKey: Keys.refreshInterval)
    self.refreshInterval = interval > 0 ? interval : 1

    self.blacklist = defaults.stringArray(forKey: Keys.blacklist) ?? []

    let threshold = defaults.integer(forKey: Keys.minTrafficThreshold)
    self.minTrafficThreshold = threshold > 0 ? threshold : 1024

    self.sortKey = SortKey(rawValue: defaults.string(forKey: Keys.sortKey) ?? "") ?? .total
  }

  func addToBlacklist(_ name: String) {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, !blacklist.contains(trimmed) else { return }
    blacklist.append(trimmed)
  }

  func removeFromBlacklist(_ name: String) {
    blacklist.removeAll { $0 == name }
  }

  func isBlacklisted(_ name: String) -> Bool {
    blacklist.contains(name)
  }
}
