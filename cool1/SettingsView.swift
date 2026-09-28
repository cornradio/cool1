import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var historyModel: HistoryModel
    @AppStorage(PersistedKeys.gridIconSize) private var gridIconSize: Double = 64
    @AppStorage(PersistedKeys.appPickerStyle) private var appPickerStyleRaw: String = "text"
    @State private var statusMessage: String = ""

    private let usageText = """
    • 点鱼图标显示/隐藏；再点一次或已在最前时点击会收起。右键可切换模式、打开设置、退出
    • 选应用即启动：下拉框直接选；也可以把 app 拖进来，或用"..."菜单从文件夹/运行中的程序里选
    • 历史记录支持列表和大图标两种模式（右上角切换），可拖拽排序，右键收藏/在 Finder 中查看/停止程序/删除
    • 大图标模式按住 Option 键，只显示正在运行的应用
    • 搜索框按名称过滤历史记录
    • 窗口模式下窗口可自由调整大小和位置，下次打开会恢复
    • 设置里可以：录制全局快捷键唤醒/隐藏、调图标大小、设为不在 Dock 显示、一键导入所有已装应用、备份或恢复全部配置
    """

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 快捷键
                ShortcutSettingsSection()

                Divider()

                // 外观
                VStack(alignment: .leading, spacing: 10) {
                    Text("大图标模式")
                        .font(.headline)
                    HStack {
                        Text("图标大小")
                        Slider(value: $gridIconSize, in: 40...128, step: 4)
                        Text("\(Int(gridIconSize))")
                            .frame(width: 30, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    Text("窗口模式")
                        .font(.headline)
                    Toggle("不在 Dock 中显示", isOn: $appState.hideDockIcon)
                    Text("开启后，切换到普通窗口模式时也不会出现在 Dock 里，只能从状态栏图标或快捷键唤醒。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Text("应用选择器样式")
                        .font(.headline)
                    Picker("应用选择器", selection: $appPickerStyleRaw) {
                        Text("传统（纯文字）").tag("text")
                        Text("有图标").tag("icon")
                    }
                    .pickerStyle(. segmented)
                    .frame(width: 300)
                    Text("有图标模式下下拉列表会显示应用图标，但可能略卡。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // 数据
                VStack(alignment: .leading, spacing: 10) {
                    Text("导入应用")
                        .font(.headline)
                    Text("一次性把所有已安装的应用加入历史记录，方便直接在列表/大图标里启动。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("导入所有已安装应用") {
                        let count = historyModel.importAllInstalledApps()
                        statusMessage = count > 0 ? "已导入 \(count) 个新应用" : "没有新的应用需要导入"
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("备份与恢复")
                        .font(.headline)
                    Text("把历史记录、显示模式和快捷键等配置导出成文件，或从文件恢复。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Button("导出配置...") { exportConfig() }
                        Button("导入配置...") { importConfig() }
                    }
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // 帮助
                VStack(alignment: .leading, spacing: 12) {
                    Text("酷鱼 cool1")
                        .font(.headline)
                    Text("版本 \(appVersion)")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    Divider()

                    Button("查看更新 / 下载最新版") {
                        if let url = URL(string: "https://github.com/cornradio/cool1/releases") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    Button("GitHub 项目主页") {
                        if let url = URL(string: "https://github.com/cornradio/cool1/") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }

                Divider()

                // 使用说明放最下面
                VStack(alignment: .leading, spacing: 8) {
                    Text("使用说明")
                        .font(.headline)
                    Text(usageText)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .frame(width: 460, height: 520)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "cool1-config.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ConfigBackupManager.exportConfig(to: url, appState: appState, historyModel: historyModel)
            statusMessage = "已导出配置到 \(url.lastPathComponent)"
        } catch {
            statusMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ConfigBackupManager.importConfig(from: url, appState: appState, historyModel: historyModel)
            statusMessage = "已导入配置"
        } catch {
            statusMessage = "导入失败：\(error.localizedDescription)"
        }
    }
}