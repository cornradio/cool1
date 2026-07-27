import Foundation
import AppKit
import Combine

final class HistoryModel: ObservableObject {
    @Published var history: [AppInfo]
    @Published var apps: [AppInfo]
    @Published private(set) var runningBundleIdentifiers: Set<String> = []

    private var bundleIdentifierCache: [String: String] = [:]
    private var iconCache: [String: NSImage] = [:]
    private var runningAppsTimer: Timer?

    init() {
        history = HistoryStore.load()
        apps = scanInstalledApps()
    }

    func reloadApps() {
        apps = scanInstalledApps()
    }

    func reloadHistory() {
        history = HistoryStore.load()
    }

    func save() {
        HistoryStore.save(history)
    }

    func importAllInstalledApps() -> Int {
        reloadApps()
        var addedCount = 0
        for app in apps where !history.contains(where: { $0.path == app.path }) {
            history.append(app)
            addedCount += 1
        }
        save()
        return addedCount
    }

    func applyImportedHistory(_ importedHistory: [AppInfo]) {
        history = importedHistory
        save()
    }

    // MARK: - Running-app tracking (single shared poller instead of one timer per row/icon)

    func startMonitoringRunningApps() {
        refreshRunningApps()
        guard runningAppsTimer == nil else { return }
        runningAppsTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshRunningApps()
        }
    }

    /// 启动一个 app 之后调用：不用等下一次 2 秒轮询，尽快把它的运行状态刷出来
    func refreshRunningAppsSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.refreshRunningApps()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.refreshRunningApps()
        }
    }

    private func refreshRunningApps() {
        runningBundleIdentifiers = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
    }

    func isRunning(path: String) -> Bool {
        guard let identifier = bundleIdentifier(for: path) else { return false }
        return runningBundleIdentifiers.contains(identifier)
    }

    private func bundleIdentifier(for path: String) -> String? {
        if let cached = bundleIdentifierCache[path] {
            return cached
        }
        guard let identifier = Bundle(url: URL(fileURLWithPath: path))?.bundleIdentifier else {
            return nil
        }
        bundleIdentifierCache[path] = identifier
        return identifier
    }

    // MARK: - Icon cache (avoid re-reading the same icon from disk every time a row scrolls into view)

    func icon(for path: String) -> NSImage? {
        if let cached = iconCache[path] {
            return cached
        }
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: path)
        iconCache[path] = image
        return image
    }
}
