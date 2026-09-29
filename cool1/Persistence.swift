import Foundation

enum PersistedKeys {
    static let historyViewMode = "HistoryViewMode"
    static let gridIconSize = "GridIconSize"
    static let appPickerStyle = "AppPickerStyle" // "icon" or "text"
}

struct HistoryStore {
    static let key = "AppLaunchHistory"

    static func load() -> [AppInfo] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AppInfo].self, from: data) else {
            return []
        }
        return decoded
    }

    static func save(_ history: [AppInfo]) {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}

func scanInstalledApps() -> [AppInfo] {
    let fileManager = FileManager.default
    let appDirectories = ["/Applications", "/Applications/Utilities", "/System/Applications", "/Library/Application Support"]
    var allApps: [AppInfo] = []
    let seenPaths = NSMutableSet()

    for directory in appDirectories {
        scanDirectory(directory, fileManager: fileManager, allApps: &allApps, seenPaths: seenPaths)
    }

    return allApps.sorted { $0.name < $1.name }
}

private func scanDirectory(_ directory: String, fileManager: FileManager, allApps: inout [AppInfo], seenPaths: NSMutableSet) {
    guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { return }

    for entry in entries {
        let fullPath = "\(directory)/\(entry)"

        if entry.hasSuffix(".app") {
            if !seenPaths.contains(fullPath) {
                seenPaths.add(fullPath)
                let name = (entry as NSString).deletingPathExtension
                allApps.append(AppInfo(name: name, path: fullPath))
            }
        } else {
            // 嵌套文件夹：递归扫描
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                scanDirectory(fullPath, fileManager: fileManager, allApps: &allApps, seenPaths: seenPaths)
            }
        }
    }
}
