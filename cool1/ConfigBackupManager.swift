import Foundation

struct ConfigBackup: Codable {
    var history: [AppInfo]
    var displayMode: String
    var historyViewMode: String
    var hotKeyCode: UInt32?
    var hotKeyModifiers: UInt32
    var hotKeyDisplay: String
    var hideDockIcon: Bool?
}

enum ConfigBackupError: LocalizedError {
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "无法解析该配置文件"
        }
    }
}

enum ConfigBackupManager {
    static func exportConfig(to url: URL, appState: AppState, historyModel: HistoryModel) throws {
        let backup = ConfigBackup(
            history: historyModel.history,
            displayMode: appState.displayMode.rawValue,
            historyViewMode: UserDefaults.standard.string(forKey: PersistedKeys.historyViewMode) ?? "list",
            hotKeyCode: appState.hotKeyCode,
            hotKeyModifiers: appState.hotKeyModifiers,
            hotKeyDisplay: appState.hotKeyDisplay,
            hideDockIcon: appState.hideDockIcon
        )
        let data = try JSONEncoder().encode(backup)
        try data.write(to: url)
    }

    static func importConfig(from url: URL, appState: AppState, historyModel: HistoryModel) throws {
        let data = try Data(contentsOf: url)
        guard let backup = try? JSONDecoder().decode(ConfigBackup.self, from: data) else {
            throw ConfigBackupError.invalidFile
        }
        historyModel.applyImportedHistory(backup.history)
        UserDefaults.standard.set(backup.historyViewMode, forKey: PersistedKeys.historyViewMode)
        appState.displayMode = DisplayMode(rawValue: backup.displayMode) ?? appState.displayMode
        appState.hideDockIcon = backup.hideDockIcon ?? false
        if let keyCode = backup.hotKeyCode {
            appState.setHotKey(keyCode: keyCode, modifiers: backup.hotKeyModifiers, display: backup.hotKeyDisplay)
        } else {
            appState.clearHotKey()
        }
    }
}
