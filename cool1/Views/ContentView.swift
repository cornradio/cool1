import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var manager = AppManager()
    
    var body: some View {
        HStack {
            VStack {
                // Top Bar
                HStack {
                    Button(action: manager.selectAppManually) {
                        Image(systemName: "folder.badge.plus")
                    }
                    .help("手动选择一个 .app 文件")

                    Button(action: {
                        manager.loadRunningApps()
                        manager.showRunningSheet = true
                    }) {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .help("查看并选择正在运行的程序")

                    Picker("选择应用", selection: $manager.selectedApp) {
                        Text("无选择").tag(nil as AppInfo?)
                        ForEach(manager.apps) { app in
                            Text(app.name).tag(app as AppInfo?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())

                    Button("启动") {
                        manager.launchSelectedApp()
                    }.disabled(manager.selectedApp == nil)
                }

                Divider()

                // Filter and Sort Bar
                HStack {
                    Picker("排序", selection: $manager.historySortMode) {
                        ForEach(AppManager.HistorySortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    
                    Spacer()
                    
                    Button(action: { manager.showOnlyFavorites.toggle() }) {
                        Image(systemName: manager.showOnlyFavorites ? "star.fill" : "star")
                    }
                    .help(manager.showOnlyFavorites ? "显示全部" : "仅显示收藏")
                    .disabled(manager.history.filter { $0.isFavorite }.isEmpty)
                    
                    Button(action: { manager.forceShowOptions.toggle() }) {
                        Image(systemName: manager.forceShowOptions ? "option" : "option")
                    }
                    .help(manager.forceShowOptions ? "隐藏额外操作" : "显示额外操作")
                }
                
                // History List
                List {
                    ForEach(manager.displayedHistory) { app in
                        HistoryItemView(
                            app: app,
                            onLaunch: { manager.launchAppFromHistory(app: app) },
                            onToggleFavorite: { manager.toggleFavorite(app: app) },
                            onDelete: { manager.deleteAppFromHistory(app: app) },
                            onKill: { manager.killApp(app: app) },
                            onMove: { fromId, toId in
                                manager.moveHistory(fromId: fromId, toId: toId)
                            },
                            isOptionPressed: manager.isOptionPressed || manager.forceShowOptions
                        )
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .padding()
        }
        .frame(width: 500, height: 700)
        .sheet(isPresented: $manager.showRunningSheet) {
            RunningAppsSheet(manager: manager)
        }
    }
}

struct RunningAppsSheet: View {
    @ObservedObject var manager: AppManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("正在运行的程序")
                .font(.headline)
            List(manager.runningApps) { app in
                Button {
                    manager.selectRunningApp(app)
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
                    manager.showRunningSheet = false
                }
            }
        }
        .padding()
        .frame(width: 420, height: 420)
    }
}
