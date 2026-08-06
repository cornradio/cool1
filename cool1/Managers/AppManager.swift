import SwiftUI
import AppKit
import Darwin

class AppManager: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var selectedApp: AppInfo?
    @Published var history: [AppInfo] = []
    @Published var isOptionPressed: Bool = false
    @Published var isCommandPressed: Bool = false
    @Published var forceShowOptions: Bool = false
    @Published var runningApps: [AppInfo] = []
    @Published var showRunningSheet: Bool = false
    @Published var historySortMode: HistorySortMode = .manual
    @Published var showOnlyFavorites: Bool = false
    
    enum HistorySortMode: String, CaseIterable, Identifiable {
        case manual = "手工顺序"
        case recent = "最近启动"
        var id: String { rawValue }
    }
    
    private let historyKey = "AppLaunchHistory"
    private var eventMonitor: Any?
    private var keyMonitor: Any?
    private var timer: Timer?

    init() {
        loadInstalledApps()
        loadHistory()
        setupOptionKeyMonitor()
    }
    
    var displayedHistory: [AppInfo] {
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
    
    func loadInstalledApps() {
        let fileManager = FileManager.default
        let appDirectories = ["/Applications", "/Applications/Utilities", "/System/Applications", "/Library/Application Support"]
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
    
    func loadRunningApps() {
        let running = NSWorkspace.shared.runningApplications
            .compactMap { app -> AppInfo? in
                guard let url = app.bundleURL else { return nil }
                let name = app.localizedName ?? url.deletingPathExtension().lastPathComponent
                return AppInfo(name: name, path: url.path)
            }
        let unique = Dictionary(grouping: running, by: { $0.path }).values.compactMap { $0.first }
        runningApps = unique.sorted { $0.name < $1.name }
    }
    
    func selectRunningApp(_ app: AppInfo) {
        if !apps.contains(where: { $0.path == app.path }) {
            apps.append(app)
            apps.sort { $0.name < $1.name }
        }
        selectedApp = apps.first(where: { $0.path == app.path }) ?? app
        showRunningSheet = false
    }
    
    func selectAppManually() {
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
            selectedApp = apps.first(where: { $0.path == path }) ?? appInfo
        }
    }
    
    func launchSelectedApp() {
        guard let app = selectedApp else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
        addToHistory(app: app)
    }
    
    func launchAppFromHistory(app: AppInfo) {
        NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
        selectedApp = app
        addToHistory(app: app)
    }
    
    func addToHistory(app: AppInfo) {
        if let idx = history.firstIndex(where: { $0.path == app.path }) {
            history[idx].lastLaunched = Date()
        } else {
            var newApp = app
            newApp.lastLaunched = Date()
            history.insert(newApp, at: 0)
        }
        saveHistory()
    }
    
    func deleteAppFromHistory(app: AppInfo) {
        if let index = history.firstIndex(where: { $0.id == app.id }) {
            history.remove(at: index)
        }
        saveHistory()
    }
    
    func toggleFavorite(app: AppInfo) {
        if let index = history.firstIndex(where: { $0.id == app.id }) {
            history[index].isFavorite.toggle()
        }
        saveHistory()
    }
    
    func killApp(app: AppInfo) {
        let bundleURL = URL(fileURLWithPath: app.path)
        guard let bundle = Bundle(url: bundleURL),
              let bundleIdentifier = bundle.bundleIdentifier else {
            return
        }
        
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleIdentifier
        }
        
        for runningApp in runningApps {
            let processIdentifier = runningApp.processIdentifier
            runningApp.terminate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if !runningApp.isTerminated {
                    runningApp.forceTerminate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if !runningApp.isTerminated {
                            kill(processIdentifier, SIGKILL)
                        }
                    }
                }
            }
        }
    }
    
    func saveHistory() {
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
    
    private func setupOptionKeyMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            let optionKeyPressed = event.modifierFlags.contains(.option)
            let commandKeyPressed = event.modifierFlags.contains(.command)
            DispatchQueue.main.async {
                self.isOptionPressed = optionKeyPressed
                self.isCommandPressed = commandKeyPressed
            }
            return event
        }
        
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            let optionKeyPressed = event.modifierFlags.contains(.option)
            let commandKeyPressed = event.modifierFlags.contains(.command)
            DispatchQueue.main.async {
                self.isOptionPressed = optionKeyPressed
                self.isCommandPressed = commandKeyPressed
            }
            return event
        }
        
        checkModifierKeyState()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.checkModifierKeyState()
        }
    }
    
    private func checkModifierKeyState() {
        let currentFlags = NSEvent.modifierFlags
        let optionPressed = currentFlags.contains(.option)
        let commandPressed = currentFlags.contains(.command)
        DispatchQueue.main.async {
            if self.isOptionPressed != optionPressed { self.isOptionPressed = optionPressed }
            if self.isCommandPressed != commandPressed { self.isCommandPressed = commandPressed }
        }
    }
    
    func moveHistory(fromId: UUID, toId: UUID) {
        guard historySortMode == .manual else { return }
        if let fromIndex = history.firstIndex(where: { $0.id == fromId }),
           let toIndex = history.firstIndex(where: { $0.id == toId }) {
            let item = history.remove(at: fromIndex)
            history.insert(item, at: toIndex)
            saveHistory()
        }
    }
}
