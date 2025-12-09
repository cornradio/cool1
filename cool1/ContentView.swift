import SwiftUI
import AppKit
import Darwin

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
    @State private var isOptionPressed: Bool = false
    
    private let historyKey = "AppLaunchHistory"
    
    var body: some View {
        HStack {
            VStack {
                HStack{
                    Button(action: selectAppManually) {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("手动选择一个 .app 文件")
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
                            onKill: { killApp(app: app) },
                            onMove: { fromId, toId in
                                if let fromIndex = history.firstIndex(where: { $0.id == fromId }),
                                   let toIndex = history.firstIndex(where: { $0.id == toId }) {
                                    let item = history.remove(at: fromIndex)
                                    history.insert(item, at: toIndex)
                                    saveHistory()
                                }
                            },
                            isOptionPressed: isOptionPressed
                        )
                    }
                }
                

            }
            .padding()
        }
        .frame(width: 500, height: 700)
        .onAppear {
            loadInstalledApps()
            loadHistory()
            setupOptionKeyMonitor()
        }
        .onDisappear {
            removeOptionKeyMonitor()
        }
    }
    
    private func loadInstalledApps() {
        let fileManager = FileManager.default
        let appDirectories = ["/Applications", "/Applications/Utilities", "/Sytem/Applications", "/Library/Application Support"]
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
    
    private func selectAppManually() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["app"]
        
        if panel.runModal() == .OK, let url = panel.url {
            let name = url.deletingPathExtension().lastPathComponent
            let path = url.path
            let appInfo = AppInfo(name: name, path: path)
            
            if !apps.contains(where: { $0.path == path }) {
                apps.append(appInfo)
                apps.sort { $0.name < $1.name }
            }
            
            // 确保选择器有对应项
            selectedApp = apps.first(where: { $0.path == path }) ?? appInfo
        }
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
    
    private func killApp(app: AppInfo) {
        let bundleURL = URL(fileURLWithPath: app.path)
        guard let bundle = Bundle(url: bundleURL),
              let bundleIdentifier = bundle.bundleIdentifier else {
            return
        }
        
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleIdentifier
        }
        
        guard !runningApps.isEmpty else {
            return
        }
        
        for runningApp in runningApps {
            let processIdentifier = runningApp.processIdentifier
            
            // 方法1: 先尝试正常终止
            runningApp.terminate()
            
            // 方法2: 如果正常终止失败，等待后强制终止
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !runningApp.isTerminated {
                    // 使用 forceTerminate
                    runningApp.forceTerminate()
                    
                    // 如果 forceTerminate 也失败，使用 kill 系统调用
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !runningApp.isTerminated {
                            kill(processIdentifier, SIGKILL)
                        }
                    }
                }
            }
        }
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
    
    private func setupOptionKeyMonitor() {
        // 使用 NSEvent 监听修饰键变化
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            let optionKeyPressed = event.modifierFlags.contains(.option)
            DispatchQueue.main.async {
                self.isOptionPressed = optionKeyPressed
            }
            return event
        }
        
        // 也监听普通按键事件来更新状态
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            let optionKeyPressed = event.modifierFlags.contains(.option)
            DispatchQueue.main.async {
                self.isOptionPressed = optionKeyPressed
            }
            return event
        }
        
        // 初始检查 Option 键状态
        checkOptionKeyState()
        
        // 定期检查 Option 键状态（作为备用方案）
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.checkOptionKeyState()
        }
    }
    
    private func checkOptionKeyState() {
        let currentFlags = NSEvent.modifierFlags
        let optionPressed = currentFlags.contains(.option)
        if isOptionPressed != optionPressed {
            isOptionPressed = optionPressed
        }
    }
    
    private func removeOptionKeyMonitor() {
        // 清理监控器（如果需要）
    }
}
