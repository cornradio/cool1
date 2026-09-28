import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var mainWindow: NSWindow?
    var settingsWindow: NSWindow?
    let appState = AppState()
    let historyModel = HistoryModel()
    private let hotKeyManager = HotKeyManager()
    private var displayModeCancellable: AnyCancellable?
    private var hotKeyCancellable: AnyCancellable?
    private var openSettingsCancellable: AnyCancellable?
    private var hideDockIconCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "fish.fill", accessibilityDescription: "App Icon")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 创建弹出窗口
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 500)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView().environmentObject(appState).environmentObject(historyModel))

        displayModeCancellable = appState.$displayMode
            .sink { [weak self] mode in
                self?.applyDisplayMode(mode)
            }
        applyDisplayMode(appState.displayMode)

        hotKeyCancellable = Publishers.CombineLatest(appState.$hotKeyCode, appState.$hotKeyModifiers)
            .sink { [weak self] keyCode, modifiers in
                self?.updateHotKey(keyCode: keyCode, modifiers: modifiers)
            }

        openSettingsCancellable = appState.openSettingsRequested
            .sink { [weak self] in
                self?.showSettingsWindow()
            }

        hideDockIconCancellable = appState.$hideDockIcon
            .dropFirst()
            .sink { [weak self] hideDockIcon in
                guard let self, self.appState.displayMode == .window else { return }
                // 直接用 sink 拿到的新值，不要再同步读 appState.hideDockIcon——
                // @Published 在 willSet 时就已经把新值发出去了，这时候属性本身还没写入，
                // 同步读会拿到切换前的旧值，导致这个开关表现得跟预期相反
                NSApp.setActivationPolicy(hideDockIcon ? .accessory : .regular)
            }
    }

    private func updateHotKey(keyCode: UInt32?, modifiers: UInt32) {
        hotKeyManager.unregister()
        guard let keyCode else { return }
        hotKeyManager.register(keyCode: keyCode, modifiers: modifiers) { [weak self] in
            self?.wakeUp()
        }
    }

    @objc func wakeUp() {
        switch appState.displayMode {
        case .menuBar:
            togglePopover()
        case .window:
            toggleMainWindow()
        }
    }

    private func applyDisplayMode(_ mode: DisplayMode) {
        switch mode {
        case .menuBar:
            mainWindow?.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
        case .window:
            if popover?.isShown == true {
                popover?.performClose(nil)
            }
            NSApp.setActivationPolicy(appState.hideDockIcon ? .accessory : .regular)
            showMainWindow()
        }
    }

    private func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "酷鱼"
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(rootView: ContentView().environmentObject(appState).environmentObject(historyModel))
            let hasSavedFrame = UserDefaults.standard.string(forKey: "NSWindow Frame cool1MainWindow") != nil
            window.setFrameAutosaveName("cool1MainWindow")
            if !hasSavedFrame {
                window.center()
            }
            mainWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    private func toggleMainWindow() {
        guard let window = mainWindow, window.isVisible else {
            showMainWindow()
            return
        }
        window.orderOut(nil)
    }

    private func showSettingsWindow() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 460),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "设置"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentViewController = NSHostingController(rootView: SettingsView().environmentObject(appState).environmentObject(historyModel))
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            // 右键：显示菜单
            let menu = buildStatusItemMenu()
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
        } else {
            // 左键：弹出/收起窗口
            wakeUp()
        }
    }

    private func buildStatusItemMenu() -> NSMenu {
        let menu = NSMenu()

        let menuBarItem = NSMenuItem(title: "任务栏模式", action: #selector(selectMenuBarMode), keyEquivalent: "")
        menuBarItem.state = appState.displayMode == .menuBar ? .on : .off
        menuBarItem.target = self
        menu.addItem(menuBarItem)

        let windowItem = NSMenuItem(title: "普通窗口模式", action: #selector(selectWindowMode), keyEquivalent: "")
        windowItem.state = appState.displayMode == .window ? .on : .off
        windowItem.target = self
        menu.addItem(windowItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "帮助", action: #selector(showHelp), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        return menu
    }

    @objc func selectMenuBarMode() {
        appState.displayMode = .menuBar
    }

    @objc func selectWindowMode() {
        appState.displayMode = .window
    }

    @objc func openSettings() {
        showSettingsWindow()
    }

    // 🎯 点击帮助时直接跳转到 GitHub 链接
    @objc func showHelp() {
        if let url = URL(string: "https://github.com/cornradio/cool1/") {
            NSWorkspace.shared.open(url)
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
