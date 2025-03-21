import SwiftUI
import AppKit

struct AppInfo: Identifiable, Codable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    var isFavorite: Bool = false
}

struct HistoryItemView: View {
    let app: AppInfo
    let onLaunch: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    let onMove: (UUID, UUID) -> Void
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
            
            Button(action: onToggleFavorite) {
                Image(systemName: app.isFavorite ? "star.fill" : "star")
                    .foregroundColor(app.isFavorite ? .yellow : .gray)
            }
            
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
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
//        .onTapGesture {
//            onLaunch()
//        }
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

struct ContentView: View {
    @State private var apps: [AppInfo] = []
    @State private var selectedApp: AppInfo?
    @State private var history: [AppInfo] = []
    
    private let historyKey = "AppLaunchHistory"
    
    var body: some View {
        HStack {
            VStack {
                HStack{
                    Picker("选择应用", selection: $selectedApp) {
                        ForEach(apps) { app in
                            Text(app.name).tag(app as AppInfo?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    Button("启动") {
                        launchSelectedApp()
                    }.disabled(selectedApp == nil)
                }

                Divider()
                HStack{
                    Text("历史记录")
                        .font(.headline)
                    Spacer()
                    Button(action: deleteAllNonFavoriteApps) {
                        Text("清空未收藏")
                    }
                    .disabled(history.filter { !$0.isFavorite }.isEmpty)
                }
                

                List {
                    ForEach(history) { app in
                        HistoryItemView(
                            app: app,
                            onLaunch: { launchAppFromHistory(app: app) },
                            onToggleFavorite: { toggleFavorite(app: app) },
                            onDelete: { deleteAppFromHistory(app: app) },
                            onMove: { fromId, toId in
                                if let fromIndex = history.firstIndex(where: { $0.id == fromId }),
                                   let toIndex = history.firstIndex(where: { $0.id == toId }) {
                                    let item = history.remove(at: fromIndex)
                                    history.insert(item, at: toIndex)
                                    saveHistory()
                                }
                            }
                        )
                    }
                }
                

            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .onAppear {
            loadInstalledApps()
            loadHistory()
        }
    }
    
    private func loadInstalledApps() {
        let fileManager = FileManager.default
        let appDirectories = ["/Applications", "/System/Applications", "/Library/Application Support"]
        var allApps: [AppInfo] = []

        for directory in appDirectories {
            do {
                let appUrls = try fileManager.contentsOfDirectory(atPath: directory)
                let appsInDirectory = appUrls.compactMap { appName in
                    let appPath = "\(directory)/\(appName)"
                    if appName.hasSuffix(".app") {
                        let name = (appName as NSString).deletingPathExtension
                        return AppInfo(name: name, path: appPath)
                    }
                    return nil
                }
                allApps.append(contentsOf: appsInDirectory)
            } catch {
                print("Failed to load apps from \(directory): \(error)")
            }
        }

        apps = allApps.sorted { $0.name < $1.name }
    }
    
    private func launchSelectedApp() {
        guard let app = selectedApp else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
        addToHistory(app: app)
    }
    
    private func launchAppFromHistory(app: AppInfo) {
        NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
        selectedApp = app
        addToHistory(app: app)
    }
    
    private func addToHistory(app: AppInfo) {
        if !history.contains(where: { $0.path == app.path }) {
            history.insert(app, at: 0)
        }
        saveHistory()
    }
    
    private func deleteAppFromHistory(app: AppInfo) {
        if let index = history.firstIndex(where: { $0.id == app.id }) {
            history.remove(at: index)
        }
        saveHistory()
    }
    
    private func toggleFavorite(app: AppInfo) {
        if let index = history.firstIndex(where: { $0.id == app.id }) {
            history[index].isFavorite.toggle()
        }
        saveHistory()
    }
    
    private func deleteAllNonFavoriteApps() {
        // Remove all history items that are not marked as favorite
        history.removeAll { !$0.isFavorite }
        saveHistory()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }
    
    private func loadHistory() {
        if let savedData = UserDefaults.standard.data(forKey: historyKey),
           let savedHistory = try? JSONDecoder().decode([AppInfo].self, from: savedData) {
            history = savedHistory
        }
    }
    
    // Function to get the app icon from its path
    private func getAppIcon(for appPath: String) -> NSImage {
        return NSWorkspace.shared.icon(forFile: appPath)
    }
}
