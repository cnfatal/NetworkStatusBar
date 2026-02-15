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
  private var settingsWindow: NSWindow?

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

    menu.items = [
      detailsItem,
      NSMenuItem.separator(),
      NSMenuItem(
        title: NSLocalizedString("settings", comment: "Settings"),
        action: #selector(openSettings),
        keyEquivalent: ","
      ),
      NSMenuItem(
        title: NSLocalizedString("quit", comment: "quit the application"),
        action: #selector(quit),
        keyEquivalent: "q"
      ),
    ]

    statusItem?.menu = menu
  }

  @objc func openSettings() {
    if let window = settingsWindow {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let settingsView = SettingsView()
    let hostingController = NSHostingController(rootView: settingsView)

    let window = NSWindow(contentViewController: hostingController)
    window.title = NSLocalizedString("settings", comment: "Settings")
    window.styleMask = [.titled, .closable]
    window.center()
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.makeKeyAndOrderFront(nil)

    NSApp.activate(ignoringOtherApps: true)
    settingsWindow = window
  }

  func applicationWillTerminate(_ notification: Notification) {
    networkStatus.stop()
  }

  @IBAction func quit(obj: Any) {
    NSApp.terminate(nil)
  }
}

extension AppDelegate: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    if let window = notification.object as? NSWindow, window == settingsWindow {
      settingsWindow = nil
    }
  }
}

extension AppDelegate: NSMenuDelegate {
  func menuWillOpen(_ menu: NSMenu) {
    // Resize details view based on content
    if let detailsView = menu.items.first?.view as? NSHostingView<StatusBarDetailsView> {
      let fittingSize = detailsView.fittingSize
      detailsView.setFrameSize(NSSize(width: 280, height: max(fittingSize.height, 80)))
    }
  }
}
