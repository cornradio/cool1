import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "fish.fill", accessibilityDescription: "App Icon")
            
            // 添加左键点击手势
            let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
            button.addGestureRecognizer(clickGesture)
        }
        
        // 创建右键菜单
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "帮助", action: #selector(showHelp), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu

        // 创建弹出窗口
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
    }

    // 🎯 点击帮助时直接跳转到 GitHub 链接
    @objc func showHelp() {
        if let url = URL(string: "https://github.com/cornradio/cool1/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func handleClick(sender: NSClickGestureRecognizer) {
        if sender.buttonMask == 0x1 {  // 左键点击
            togglePopover()
        }
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            }
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
