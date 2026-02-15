//
//  NetworkStatusBarApp.swift
//  NetworkStatusBar
//
//  Created by fatal cn on 2021/10/31.
//

import Combine
import SwiftUI

@main
struct NetworkStatusBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appdelegate
  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {

  var iostates: IOStates = IOStates()
  var statusItem: NSStatusItem?

  var networkStatus: NetworkDetails = NetworkDetails()
  let settings = AppSettings.shared
  private var cancellables = Set<AnyCancellable>()

  func onUpdate(update: NetworkStates) {
    DispatchQueue.main.async {
      self.iostates.total = update.total
      let threshold = self.settings.minTrafficThreshold
      let blacklist = self.settings.blacklist
      self.iostates.items = update.items.filter { item in
        return item.total >= threshold && !blacklist.contains(item.name)
      }
    }
  }

  func applicationWillFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.prohibited)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: 62)

    networkStatus.callback = onUpdate
    startNetworkMonitoring()

    // Watch for refresh interval changes
    settings.$refreshInterval
      .dropFirst()
      .removeDuplicates()
      .sink { [weak self] _ in
        self?.restartNetworkMonitoring()
      }
      .store(in: &cancellables)

    if let button = statusItem?.button {
      let statusbarview = NSHostingView(rootView: StatusBarView(iostates: iostates))
      statusbarview.frame = NSRect(x: 0, y: 0, width: 62, height: button.frame.height)
      button.addSubview(statusbarview)
    }

    setupMenu()
  }

  private func startNetworkMonitoring() {
    DispatchQueue.global(qos: .userInteractive).async {
      self.networkStatus.run(refreshSeconds: self.settings.refreshInterval)
    }
  }

  private func restartNetworkMonitoring() {
    networkStatus.stop()
    startNetworkMonitoring()
  }

  private func setupMenu() {
    let menu = NSMenu()
    menu.delegate = self

    let detailsItem = NSMenuItem()
    let detailsView = StatusBarDetailsView(iostates: iostates)
    let hostingView = NSHostingView(rootView: detailsView)
    hostingView.setFrameSize(NSSize(width: 280, height: 320))
    detailsItem.view = hostingView

    let settingsItem = NSMenuItem()
    let settingsHostingView = NSHostingView(rootView: SettingsView())
    settingsHostingView.setFrameSize(NSSize(width: 280, height: 10))
    settingsItem.view = settingsHostingView

    menu.items = [
      detailsItem,
      NSMenuItem.separator(),
      settingsItem,
      NSMenuItem.separator(),
      NSMenuItem(
        title: NSLocalizedString("quit", comment: "quit the application"),
        action: #selector(quit),
        keyEquivalent: "q"
      ),
    ]

    statusItem?.menu = menu
  }

  func applicationWillTerminate(_ notification: Notification) {
    networkStatus.stop()
  }

  @IBAction func quit(obj: Any) {
    NSApp.terminate(nil)
  }
}

extension AppDelegate: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    // Resize details view based on content
    if let detailsView = menu.items.first?.view as? NSHostingView<StatusBarDetailsView> {
      let fittingSize = detailsView.fittingSize
      detailsView.setFrameSize(NSSize(width: 280, height: max(fittingSize.height, 80)))
    }
    // Resize settings view
    if menu.items.count > 2,
      let settingsView = menu.items[2].view as? NSHostingView<SettingsView>
    {
      let fittingSize = settingsView.fittingSize
      settingsView.setFrameSize(NSSize(width: 280, height: fittingSize.height))
    }
  }
}
