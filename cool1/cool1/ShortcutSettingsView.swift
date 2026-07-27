import SwiftUI
import AppKit

struct ShortcutSettingsSection: View {
    @EnvironmentObject var appState: AppState
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("全局快捷键")
                .font(.headline)
            Text("设置后，任务栏模式或窗口模式下按下该快捷键都可以唤醒或隐藏酷鱼。")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text("当前：\(appState.hotKeyDisplay)")
                Spacer()
                if appState.hotKeyCode != nil {
                    Button("清除") {
                        stopRecording()
                        appState.clearHotKey()
                    }
                }
            }

            Button(isRecording ? "请按下新的快捷键…" : "录制新快捷键") {
                startRecording()
            }
            .disabled(isRecording)
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let modifiers = carbonModifierFlags(from: event.modifierFlags)
            guard modifiers != 0 else { return event } // 至少要带一个修饰键，避免误触发
            appState.setHotKey(
                keyCode: UInt32(event.keyCode),
                modifiers: modifiers,
                display: shortcutDisplayString(event: event)
            )
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func shortcutDisplayString(event: NSEvent) -> String {
        var parts: [String] = []
        if event.modifierFlags.contains(.control) { parts.append("⌃") }
        if event.modifierFlags.contains(.option) { parts.append("⌥") }
        if event.modifierFlags.contains(.shift) { parts.append("⇧") }
        if event.modifierFlags.contains(.command) { parts.append("⌘") }
        let key = event.charactersIgnoringModifiers?.uppercased() ?? "Key\(event.keyCode)"
        parts.append(key)
        return parts.joined()
    }
}
