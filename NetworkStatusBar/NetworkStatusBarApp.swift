//
//  NetworkStatusBarApp.swift
//  NetworkStatusBar
//
//  Created by fatal cn on 2021/10/31.
//

import SwiftUI

@main
struct NetworkStatusBarApp: App {
  /// Owns the status item, the panel and the sampler. The status item is built
  /// by hand rather than with `MenuBarExtra` because the label has to render as
  /// two lines at an exact width, and `MenuBarExtra` both pads its label and
  /// lays it out with the menu bar's own metrics.
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    // The settings window is presented by the delegate; this only satisfies the
    // requirement that an App declare a scene.
    Settings {
      EmptyView()
    }
  }
}
