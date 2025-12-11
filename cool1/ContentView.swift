import SwiftUI
import AppKit
import Darwin

struct AppInfo: Identifiable, Codable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    var isFavorite: Bool = false
    var lastLaunched: Date? = nil
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
    private enum HistorySortMode: String, CaseIterable, Identifiable {
        case manual = "手工顺序"
        case recent = "最近启动"
        
        var id: String { rawValue }
    }
    
    @State private var apps: [AppInfo] = []
    @State private var selectedApp: AppInfo?
    @State private var history: [AppInfo] = []
    @State private var isOptionPressed: Bool = false
    @State private var isCommandPressed: Bool = false
    @State private var forceShowOptions: Bool = false
    @State private var runningApps: [AppInfo] = []
    @State private var showRunningSheet: Bool = false
    @State private var historySortMode: HistorySortMode = .manual
    @State private var showOnlyFavorites: Bool = false
    
    private let historyKey = "AppLaunchHistory"
    
    var body: some View {
        HStack {
            VStack {
                HStack{
                    Button(action: selectAppManually) {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("手动选择一个 .app 文件")
                    Button(action: {
                        loadRunningApps()
                        showRunningSheet = true
                    }) {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .help("查看并选择正在运行的程序")
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
                    // Text("历史记录")
                    //     .font(.headline)
                    Picker("排序", selection: $historySortMode) {
                        ForEach(HistorySortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    Spacer()
                    Button(action: { showOnlyFavorites.toggle() }) {
                        Image(systemName: showOnlyFavorites ? "command" : "command")
                    }
                    .help(showOnlyFavorites ? "显示全部" : "仅显示收藏")
                    .disabled(history.filter { $0.isFavorite }.isEmpty)
                    
                    Button(action: { forceShowOptions.toggle() }) {
                        Image(systemName: forceShowOptions ? "option" : "option")
                    }
                    .help(forceShowOptions ? "隐藏额外操作" : "显示额外操作")
                }
                
                List {
                    ForEach(displayedHistory) { app in
                        HistoryItemView(
                            app: app,
                            onLaunch: { launchAppFromHistory(app: app) },
                            onToggleFavorite: { toggleFavorite(app: app) },
                            onDelete: { deleteAppFromHistory(app: app) },
                            onKill: { killApp(app: app) },
                            onMove: { fromId, toId in
                                guard historySortMode == .manual else { return }
                                if let fromIndex = history.firstIndex(where: { $0.id == fromId }),
                                   let toIndex = history.firstIndex(where: { $0.id == toId }) {
                                    let item = history.remove(at: fromIndex)
                                    history.insert(item, at: toIndex)
                                    saveHistory()
                                }
                            },
                            isOptionPressed: isOptionPressed || forceShowOptions
                        )
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                

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
        .sheet(isPresented: $showRunningSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("正在运行的程序")
                    .font(.headline)
                List(runningApps) { app in
                    Button {
                        selectRunningApp(app)
                    } label: {
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(app.name)
                            Spacer()
                            Text(app.path)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
                HStack {
                    Spacer()
                    Button("关闭") {
                        showRunningSheet = false
                    }
                }
            }
            .padding()
            .frame(width: 420, height: 420)
            .onAppear {
                loadRunningApps()
            }
        }
    }
    
    private var displayedHistory: [AppInfo] {
        let filterFavorites = showOnlyFavorites || isCommandPressed
        let base = filterFavorites ? history.filter { $0.isFavorite } : history
        switch historySortMode {
        case .manual:
            return base
        case .recent:
            return base.sorted {
                let l1 = $0.lastLaunched ?? .distantPast
                let l2 = $1.lastLaunched ?? .distantPast
                if l1 == l2 {
                    return $0.name < $1.name
                }
                return l1 > l2
            }
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
    
    private func loadRunningApps() {
        let running = NSWorkspace.shared.runningApplications
            .compactMap { app -> AppInfo? in
                guard let url = app.bundleURL else { return nil }
                let name = app.localizedName ?? url.deletingPathExtension().lastPathComponent
                return AppInfo(name: name, path: url.path)
            }
        // 去重后按名称排序
        let unique = Dictionary(grouping: running, by: { $0.path }).values.compactMap { $0.first }
        runningApps = unique.sorted { $0.name < $1.name }
    }
    
    private func selectRunningApp(_ app: AppInfo) {
        if !apps.contains(where: { $0.path == app.path }) {
            apps.append(app)
            apps.sort { $0.name < $1.name }
        }
        selectedApp = apps.first(where: { $0.path == app.path }) ?? app
        showRunningSheet = false
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
        if let idx = history.firstIndex(where: { $0.path == app.path }) {
            history[idx].lastLaunched = Date()
        } else {
            var newApp = app
            newApp.lastLaunched = Date()
            history.insert(newApp, at: 0)
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
                let commandKeyPressed = event.modifierFlags.contains(.command)
            DispatchQueue.main.async {
                self.isOptionPressed = optionKeyPressed
                    self.isCommandPressed = commandKeyPressed
            }
            return event
        }
        
        // 也监听普通按键事件来更新状态
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
                let optionKeyPressed = event.modifierFlags.contains(.option)
                let commandKeyPressed = event.modifierFlags.contains(.command)
            DispatchQueue.main.async {
                self.isOptionPressed = optionKeyPressed
                    self.isCommandPressed = commandKeyPressed
            }
            return event
        }
        
        // 初始检查 Option 键状态
            checkModifierKeyState()
        
        // 定期检查 Option 键状态（作为备用方案）
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.checkModifierKeyState()
        }
    }
    
        private func checkModifierKeyState() {
        let currentFlags = NSEvent.modifierFlags
        let optionPressed = currentFlags.contains(.option)
            let commandPressed = currentFlags.contains(.command)
            if isOptionPressed != optionPressed { isOptionPressed = optionPressed }
            if isCommandPressed != commandPressed { isCommandPressed = commandPressed }
    }
    
    private func removeOptionKeyMonitor() {
        // 清理监控器（如果需要）
    }
}
