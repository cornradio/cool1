import SwiftUI
import AppKit

struct HistoryItemView: View {
    let app: AppInfo
    let onLaunch: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    let onKill: () -> Void
    let onMove: (UUID, UUID) -> Void
    let isOptionPressed: Bool
    @State private var isRunning: Bool = false
    @State private var appIcon: NSImage?
    
    var body: some View {
        HStack {
            Button(action: onLaunch) {
                Image(systemName: isRunning ? "arrowtriangle.forward.fill" : "arrowtriangle.forward")
                    .foregroundColor(isRunning ? .green : .white)
            }
            
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            
            Text(app.name)
            Spacer()
            
            // 只有在按住 Option 键时才显示 kill 和 delete 按钮
            if isOptionPressed {
                if isRunning {
                    Button(action: onKill) {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                }
            }
            
            Button(action: onToggleFavorite) {
                Image(systemName: app.isFavorite ? "star.fill" : "star")
                    .foregroundColor(app.isFavorite ? .yellow : .gray)
            }
        }
        .draggable(app.id.uuidString) { Text(app.name) }
        .dropDestination(for: String.self) { items, location in
            guard let draggedId = items.first,
                  let draggedUUID = UUID(uuidString: draggedId),
                  draggedId != app.id.uuidString else {
                return false
            }
            onMove(draggedUUID, app.id)
            return true
        } isTargeted: { _ in }
        .onAppear {
            checkIfAppIsRunning()
            loadAppIcon()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            checkIfAppIsRunning()
        }
    }
    
    private func checkIfAppIsRunning() {
        let bundleURL = URL(fileURLWithPath: app.path)
        if let bundle = Bundle(url: bundleURL),
           let bundleIdentifier = bundle.bundleIdentifier {
            isRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == bundleIdentifier
            }
        }
    }
    
    private func loadAppIcon() {
        DispatchQueue.main.async {
            if FileManager.default.fileExists(atPath: app.path) {
                appIcon = NSWorkspace.shared.icon(forFile: app.path)
            }
        }
    }
}
