//
//  AppSettings.swift
//  NetworkStatusBar
//
//  Settings management using UserDefaults with observable properties.
//

import Combine
import Foundation

final class AppSettings: ObservableObject {
  static let shared = AppSettings()

  private let defaults = UserDefaults.standard

  private enum Keys {
    static let refreshInterval = "refreshInterval"
    static let blacklist = "blacklist"
    static let showInactiveApps = "showInactiveApps"
    static let minTrafficThreshold = "minTrafficThreshold"
  }

  /// Refresh interval in seconds (1-10)
  @Published var refreshInterval: Int {
    didSet {
      defaults.set(refreshInterval, forKey: Keys.refreshInterval)
    }
  }

  /// Blacklisted app names that won't appear in the details list
  @Published var blacklist: [String] {
    didSet {
      defaults.set(blacklist, forKey: Keys.blacklist)
    }
  }

  /// Whether to show apps with zero traffic
  @Published var showInactiveApps: Bool {
    didSet {
      defaults.set(showInactiveApps, forKey: Keys.showInactiveApps)
    }
  }

  /// Minimum traffic threshold in bytes to show an app (default 1024)
  @Published var minTrafficThreshold: Int {
    didSet {
      defaults.set(minTrafficThreshold, forKey: Keys.minTrafficThreshold)
    }
  }

  private init() {
    let interval = defaults.integer(forKey: Keys.refreshInterval)
    self.refreshInterval = interval > 0 ? interval : 1

    self.blacklist = defaults.stringArray(forKey: Keys.blacklist) ?? []

    if defaults.object(forKey: Keys.showInactiveApps) != nil {
      self.showInactiveApps = defaults.bool(forKey: Keys.showInactiveApps)
    } else {
      self.showInactiveApps = false
    }

    let threshold = defaults.integer(forKey: Keys.minTrafficThreshold)
    self.minTrafficThreshold = threshold > 0 ? threshold : 1024
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
    return blacklist.contains(name)
  }
}
