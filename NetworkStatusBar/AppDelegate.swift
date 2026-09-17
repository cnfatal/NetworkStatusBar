//
//  AppDelegate.swift
//  NetworkStatusBar
//
//  Owns the status item, the panel, and the sampler's lifecycle.
//

import AppKit
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model = TrafficModel()

  private let settings = AppSettings.shared
  private let sampler = TrafficSampler()
  private var signalSources: [DispatchSourceSignal] = []

  /// Width of the menu bar item, in points.
  ///
  /// Fixed so the item cannot resize as the figures change — and fixed here, on
  /// the status item, because that is the size the menu bar reserves. The label
  /// is hosted inside it with the same width, so the figures get the whole 62
  /// points and are never clipped.
  private static let itemWidth: CGFloat = 62

  private var statusItem: NSStatusItem?
  private var settingsWindow: NSWindow?
  private lazy var panel = NSPopover()

  func applicationWillFinishLaunching(_ notification: Notification) {
    // Menu bar only: no Dock icon, no app switcher entry.
    NSApp.setActivationPolicy(.prohibited)
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    sampler.onSample = { [model] snapshot in
      // The sampler runs off the main thread and calls back without holding its
      // lock, so hop to the actor the model lives on.
      Task { @MainActor in
        model.apply(snapshot)
      }
    }

    installSignalHandlers()
    startSampling()
    observeRefreshInterval()
    setUpStatusItem()
    setUpPanel()
  }

  func applicationWillTerminate(_ notification: Notification) {
    sampler.stop()
  }

  // MARK: - Status item

  private func setUpStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: Self.itemWidth)
    statusItem = item

    guard let button = item.button else {
      return
    }
    button.target = self
    button.action = #selector(togglePanel)

    let label = PassthroughHostingView(rootView: MenuBarLabel(model: model))
    label.frame = NSRect(x: 0, y: 0, width: Self.itemWidth, height: button.frame.height)
    button.addSubview(label)
  }

  /// A popover rather than a menu. The panel holds a chart and a list, which a
  /// menu cannot express — and a menu's event tracking would also block the
  /// chart's hover.
  private func setUpPanel() {
    panel.behavior = .transient
    panel.contentViewController = NSHostingController(
      rootView: TrafficPanel(
        model: model,
        onOpenSettings: { [weak self] in
          self?.openSettings()
        }))
  }

  @objc private func togglePanel() {
    if panel.isShown {
      panel.performClose(nil)
    } else if let button = statusItem?.button {
      panel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      panel.contentViewController?.view.window?.makeKey()
    }
  }

  // MARK: - Settings

  private func openSettings() {
    panel.performClose(nil)

    if let window = settingsWindow {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let window = NSWindow(
      contentViewController: NSHostingController(
        rootView: SettingsView(seenProcessNames: model.seenProcessNames)))
    window.title = NSLocalizedString("settings", comment: "Settings")
    window.styleMask = [.titled, .closable]
    window.center()
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    settingsWindow = window
  }

  // MARK: - Sampling

  private func startSampling() {
    let seconds = settings.refreshInterval
    let sampler = self.sampler
    DispatchQueue.global(qos: .userInitiated).async {
      sampler.run(refreshSeconds: seconds)
    }
  }

  private func restartSampling() {
    sampler.stop()
    startSampling()
  }

  /// Restarts sampling when the refresh interval changes.
  ///
  /// `withObservationTracking` fires once per registration, so the handler
  /// re-arms itself. The history resets too: samples taken at different
  /// spacings would otherwise be drawn as though they were evenly spaced.
  private func observeRefreshInterval() {
    withObservationTracking {
      _ = settings.refreshInterval
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self = self else { return }
        self.model.resetHistory()
        self.restartSampling()
        self.observeRefreshInterval()
      }
    }
  }

  /// Terminate the nettop child when the app is asked to die by signal.
  ///
  /// Orphaned children are reparented to launchd and keep sampling forever.
  /// macOS has nothing like Linux's PR_SET_PDEATHSIG, and nettop cannot be made
  /// to watch us, so catching the signals is the only lever available. SIGKILL
  /// and crashes are uncatchable by definition and will still orphan it — this
  /// narrows the window, it does not close it.
  private func installSignalHandlers() {
    for sig in [SIGTERM, SIGINT, SIGHUP] {
      // A dispatch source only fires if the default disposition, which would
      // terminate us immediately, is disabled first.
      signal(sig, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
      source.setEventHandler { [weak self] in
        self?.sampler.stop()
        exit(0)
      }
      source.resume()
      signalSources.append(source)
    }
  }
}

/// A hosting view that ignores the mouse.
///
/// The label is a subview of the status item's button, and the button owns the
/// action that opens the panel. Without this the label would sit on top and
/// swallow the click, leaving the panel unopenable.
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }
}

extension AppDelegate: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    if let window = notification.object as? NSWindow, window == settingsWindow {
      settingsWindow = nil
    }
  }
}
