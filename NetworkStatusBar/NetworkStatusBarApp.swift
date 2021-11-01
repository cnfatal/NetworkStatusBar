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
        WindowGroup {}
    }
}

var StatusBarWidth = CGFloat(60)

class AppDelegate :NSObject, NSApplicationDelegate{

    var iostates : IOStates = IOStates()
    var statusItem : NSStatusItem?

    var networkStatus :NetworkDetails = NetworkDetails()

    func onUpdate(update:NetworkStates){
        DispatchQueue.main.async {
            self.iostates.total = update.Total
            self.iostates.items = update.Items
        }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.length = StatusBarWidth

        networkStatus.callback = onUpdate
        DispatchQueue.global(qos: .userInteractive).async {
            self.networkStatus.run(refreshSeconds: 1)
        }

        if let button = statusItem?.button{
           let statusbarview = NSHostingView(rootView: StatusBarView(iostates: iostates ))
           statusbarview.frame = button.frame
           button.addSubview(statusbarview)
        }

        statusItem?.menu={
            let menu = NSMenu()
            menu.items = [
                {
                    let menuitem = NSMenuItem()
                    menuitem.view = NSHostingView(rootView: StatusBarDetailsView(iostates: iostates))
                    // ListTableCellView has 16dp at left and right,ListScroll has a 15dp width
                    // 16 * 2 + 15 = 47
                    // Out DetailsItem has min length 200
                    menuitem.view?.setFrameSize(NSSize(width: 247, height: 300))
                    return menuitem
                }(),
                NSMenuItem(
                    title: NSLocalizedString("quit", comment: "quit the application"),
                    action: #selector(quit),
                    keyEquivalent: "q"
                )
            ]
            return menu
        }()
    }

    @IBAction func quit(obj:Any){
        NSApp.terminate(nil)
    }
}



