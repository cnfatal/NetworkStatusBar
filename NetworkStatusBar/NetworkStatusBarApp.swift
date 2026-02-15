//
//  NetworkStatusBarApp.swift
//  NetworkStatusBar
//
//  Created by fatal cn on 2021/10/31.
//

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

  func onUpdate(update: NetworkStates) {
    DispatchQueue.main.async {
      self.iostates.total = update.total
      self.iostates.items = update.items.filter({ item in
        return item.total > 1024
      })
    }
  }

  func applicationWillFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.prohibited)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: 62)

    networkStatus.callback = onUpdate
    DispatchQueue.global(qos: .userInteractive).async {
      self.networkStatus.run(refreshSeconds: 1)
    }

    if let button = statusItem?.button {
      let statusbarview = NSHostingView(rootView: StatusBarView(iostates: iostates))
      statusbarview.frame = NSRect(x: 0, y: 0, width: 62, height: button.frame.height)
      button.addSubview(statusbarview)
    }

    statusItem?.menu = {
      let menu = NSMenu()
      menu.items = [
        {
          let menuitem = NSMenuItem()
          let detailsView = StatusBarDetailsView(iostates: iostates)
          let hostingView = NSHostingView(rootView: detailsView)
          hostingView.setFrameSize(NSSize(width: 280, height: 320))
          menuitem.view = hostingView
          return menuitem
        }(),
        NSMenuItem.separator(),
        NSMenuItem(
          title: NSLocalizedString("quit", comment: "quit the application"),
          action: #selector(quit),
          keyEquivalent: "q"
        ),
      ]
      return menu
    }()
  }

  func applicationWillTerminate(_ notification: Notification) {
    networkStatus.stop()
  }

  @IBAction func quit(obj: Any) {
    NSApp.terminate(nil)
  }
}
