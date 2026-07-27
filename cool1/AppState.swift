import Foundation
import Combine
import AppKit
import Carbon.HIToolbox

enum DisplayMode: String {
    case menuBar
    case window
}

func carbonModifierFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var result: UInt32 = 0
    if flags.contains(.command) { result |= UInt32(cmdKey) }
    if flags.contains(.option) { result |= UInt32(optionKey) }
    if flags.contains(.control) { result |= UInt32(controlKey) }
    if flags.contains(.shift) { result |= UInt32(shiftKey) }
    return result
}

final class AppState: ObservableObject {
    private let displayModeKey = "DisplayMode"
    private let hotKeyCodeKey = "HotKeyCode"
    private let hotKeyModifiersKey = "HotKeyModifiers"
    private let hotKeyDisplayKey = "HotKeyDisplay"
    private let hideDockIconKey = "HideDockIcon"

    @Published var displayMode: DisplayMode {
        didSet {
            UserDefaults.standard.set(displayMode.rawValue, forKey: displayModeKey)
        }
    }

    @Published var hideDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(hideDockIcon, forKey: hideDockIconKey)
        }
    }

    @Published var hotKeyCode: UInt32? {
        didSet {
            if let hotKeyCode {
                UserDefaults.standard.set(Int(hotKeyCode), forKey: hotKeyCodeKey)
            } else {
                UserDefaults.standard.removeObject(forKey: hotKeyCodeKey)
            }
        }
    }

    @Published var hotKeyModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(Int(hotKeyModifiers), forKey: hotKeyModifiersKey)
        }
    }

    @Published var hotKeyDisplay: String {
        didSet {
            UserDefaults.standard.set(hotKeyDisplay, forKey: hotKeyDisplayKey)
        }
    }

    init() {
        let savedMode = UserDefaults.standard.string(forKey: displayModeKey)
        displayMode = savedMode.flatMap(DisplayMode.init) ?? .menuBar
        hideDockIcon = UserDefaults.standard.bool(forKey: hideDockIconKey)

        if UserDefaults.standard.object(forKey: hotKeyCodeKey) != nil {
            hotKeyCode = UInt32(UserDefaults.standard.integer(forKey: hotKeyCodeKey))
        } else {
            hotKeyCode = nil
        }
        hotKeyModifiers = UInt32(UserDefaults.standard.integer(forKey: hotKeyModifiersKey))
        hotKeyDisplay = UserDefaults.standard.string(forKey: hotKeyDisplayKey) ?? "未设置"
    }

    func toggleDisplayMode() {
        displayMode = displayMode == .menuBar ? .window : .menuBar
    }

    func setHotKey(keyCode: UInt32, modifiers: UInt32, display: String) {
        hotKeyCode = keyCode
        hotKeyModifiers = modifiers
        hotKeyDisplay = display
    }

    func clearHotKey() {
        hotKeyCode = nil
        hotKeyModifiers = 0
        hotKeyDisplay = "未设置"
    }

    let openSettingsRequested = PassthroughSubject<Void, Never>()

    func requestOpenSettings() {
        openSettingsRequested.send(())
    }
}
