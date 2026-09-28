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

    for directory in appDirectories {
        if let appNames = try? fileManager.contentsOfDirectory(atPath: directory) {
            let appsInDirectory = appNames.compactMap { appName -> AppInfo? in
                guard appName.hasSuffix(".app") else { return nil }
                let name = (appName as NSString).deletingPathExtension
                return AppInfo(name: name, path: "\(directory)/\(appName)")
            }
            allApps.append(contentsOf: appsInDirectory)
        }
    }

    return allApps.sorted { $0.name < $1.name }
}
