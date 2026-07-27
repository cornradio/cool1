import SwiftUI
import AppKit
import Darwin
import UniformTypeIdentifiers

struct AppInfo: Identifiable, Codable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    var isFavorite: Bool = false
    var lastLaunched: Date? = nil
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct HistoryItemView: View {
    let app: AppInfo
    let onLaunch: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    let onKill: () -> Void
    let onMove: (UUID, UUID) -> Void
    let isOptionPressed: Bool
    @EnvironmentObject var historyModel: HistoryModel
    
    var body: some View {
        HStack {
            Button(action: onLaunch) {
                Image(systemName: isRunning ? "arrowtriangle.forward.fill" : "arrowtriangle.forward")
                    .foregroundColor(isRunning ? .green : .white)
            }
            .buttonStyle(ScaleButtonStyle())
            
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
    }
    
    private var isRunning: Bool {
        historyModel.isRunning(path: app.path)
    }
    
    private var appIcon: NSImage? {
        historyModel.icon(for: app.path)
    }
}

struct HistoryGridItemView: View {
    let app: AppInfo
    let iconSize: CGFloat
    let onLaunch: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    let onKill: () -> Void
    @EnvironmentObject var historyModel: HistoryModel
    @State private var isPressed = false
    
    private var cellWidth: CGFloat { iconSize + 20 }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let icon = appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: iconSize, height: iconSize)
                    } else {
                        Image(systemName: "app.fill")
                            .resizable()
                            .frame(width: iconSize, height: iconSize)
                    }
                }
                .scaleEffect(isPressed ? 0.82 : 1.0)
                .opacity(isPressed ? 0.7 : 1.0)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.08)) {
                        isPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
                            isPressed = false
                        }
                        onLaunch()
                    }
                }
                
                Button(action: onToggleFavorite) {
                    Image(systemName: app.isFavorite ? "star.fill" : "star")
                        .foregroundColor(app.isFavorite ? .yellow : .gray)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
                
                if isRunning {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .offset(x: -2, y: 2)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isRunning)
            
            Text(app.name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: cellWidth - 4)
        }
        .frame(width: cellWidth)
        .contextMenu {
            Button(action: onToggleFavorite) {
                Label(app.isFavorite ? "取消收藏" : "收藏", systemImage: app.isFavorite ? "star.slash" : "star")
            }
            Button(action: revealInFinder) {
                Label("在 Finder 中查看", systemImage: "folder")
            }
            if isRunning {
                Button(action: onKill) {
                    Label("停止程序", systemImage: "xmark.circle")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
    }
    
    private var isRunning: Bool {
        historyModel.isRunning(path: app.path)
    }
    
    private var appIcon: NSImage? {
        historyModel.icon(for: app.path)
    }
}

private struct HistoryGridDropDelegate: DropDelegate {
    let item: AppInfo
    @Binding var history: [AppInfo]
    @Binding var draggedItem: AppInfo?
    let isManualSort: Bool
    let onReorder: () -> Void
    
    func dropEntered(info: DropInfo) {
        guard isManualSort,
              let dragged = draggedItem,
              dragged.id != item.id,
              let fromIndex = history.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = history.firstIndex(where: { $0.id == item.id }) else { return }
        
        if history[toIndex].id != dragged.id {
            withAnimation(.default) {
                history.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        onReorder()
        return true
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct ContentView: View {
    private enum HistorySortMode: String, CaseIterable, Identifiable {
        case manual = "手工顺序"
        case recent = "最近启动"
        
        var id: String { rawValue }
    }
    
    private enum HistoryViewMode: String {
        case list
        case grid
    }
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var historyModel: HistoryModel
    @State private var selectedApp: AppInfo?
    @State private var isOptionPressed: Bool = false
    @State private var isCommandPressed: Bool = false
    @State private var forceShowOptions: Bool = false
    @State private var runningApps: [AppInfo] = []
    @State private var showRunningSheet: Bool = false
    @State private var historySortMode: HistorySortMode = .manual
    @State private var showOnlyFavorites: Bool = false
    @State private var historySearchText: String = ""
    @AppStorage(PersistedKeys.historyViewMode) private var historyViewMode: HistoryViewMode = .list
    @AppStorage(PersistedKeys.gridIconSize) private var gridIconSize: Double = 64
    @State private var draggedHistoryApp: AppInfo?
    @State private var isTargetedForAppDrop = false
    
    var body: some View {
        HStack {
            VStack {
                if appState.displayMode == .window {
                    HStack {
                        appSelectorControls
                        Spacer()
                        modeAndSettingsControls
                        historySearchField
                    }
                } else {
                    HStack {
                        appSelectorControls
                        Spacer()
                        modeAndSettingsControls
                    }

                    HStack {
                        historySearchField
                    }
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
                    .disabled(historyModel.history.filter { $0.isFavorite }.isEmpty)
                    
                    Button(action: { forceShowOptions.toggle() }) {
                        Image(systemName: forceShowOptions ? "option" : "option")
                    }
                    .help(forceShowOptions ? "隐藏额外操作" : "显示额外操作")
                    
                    Button(action: { historyViewMode = historyViewMode == .list ? .grid : .list }) {
                        Image(systemName: historyViewMode == .list ? "square.grid.2x2" : "list.bullet")
                    }
                    .help(historyViewMode == .list ? "切换到大图标模式" : "切换到列表模式")
                }
                
                if historyViewMode == .list {
                    List {
                        ForEach(displayedHistory) { app in
                            HistoryItemView(
                                app: app,
                                onLaunch: { launchAppFromHistory(app: app) },
                                onToggleFavorite: { toggleFavorite(app: app) },
                                onDelete: { deleteAppFromHistory(app: app) },
                                onKill: { killApp(app: app) },
                                onMove: moveHistoryItem,
                                isOptionPressed: isOptionPressed || forceShowOptions
                            )
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                } else {
                    if isOptionPressed {
                        Text("⌥ 仅显示正在运行的应用")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: CGFloat(gridIconSize) + 20))], spacing: 16) {
                            ForEach(displayedHistory) { app in
                                HistoryGridItemView(
                                    app: app,
                                    iconSize: CGFloat(gridIconSize),
                                    onLaunch: { launchAppFromHistory(app: app) },
                                    onToggleFavorite: { toggleFavorite(app: app) },
                                    onDelete: { deleteAppFromHistory(app: app) },
                                    onKill: { killApp(app: app) }
                                )
                                .onDrag {
                                    draggedHistoryApp = app
                                    return NSItemProvider(object: app.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: HistoryGridDropDelegate(
                                    item: app,
                                    history: $historyModel.history,
                                    draggedItem: $draggedHistoryApp,
                                    isManualSort: historySortMode == .manual,
                                    onReorder: { historyModel.save() }
                                ))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

            }
            .padding()
        }
        .frame(minWidth: 420, idealWidth: 500, maxWidth: .infinity, minHeight: 400, idealHeight: 700, maxHeight: .infinity)
        .background(VisualEffectBackground())
        .overlay {
            if isTargetedForAppDrop {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(4)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            var didAdd = false
            for url in urls where url.pathExtension == "app" {
                addAppFromDrop(url: url)
                didAdd = true
            }
            return didAdd
        } isTargeted: { targeted in
            isTargetedForAppDrop = targeted
        }
        .onAppear {
            historyModel.reloadApps()
            historyModel.startMonitoringRunningApps()
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
    
    @ViewBuilder
    private var appSelectorControls: some View {
        Picker("选择应用", selection: Binding(
            get: { selectedApp },
            set: { newValue in
                selectedApp = newValue
                if newValue != nil {
                    launchSelectedApp()
                }
            }
        )) {
            ForEach(historyModel.apps) { app in
                Text(app.name).tag(app as AppInfo?)
            }
        }
        .pickerStyle(MenuPickerStyle())

        Menu {
            Button("从文件夹选择...") {
                selectAppManually()
            }
            Button("从运行中的程序选择...") {
                loadRunningApps()
                showRunningSheet = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28)
        .help("从文件夹或正在运行的程序中选择")
    }
    
    @ViewBuilder
    private var modeAndSettingsControls: some View {
        Button(action: { appState.toggleDisplayMode() }) {
            Image(systemName: "macwindow")
        }
        .help(appState.displayMode == .menuBar ? "切换到窗口模式" : "切换到任务栏模式")
        Button(action: { appState.requestOpenSettings() }) {
            Image(systemName: "gearshape")
        }
        .help("设置")
    }
    
    @ViewBuilder
    private var historySearchField: some View {
        TextField("过滤历史记录", text: $historySearchText)
            .textFieldStyle(.roundedBorder)
        if !historySearchText.isEmpty {
            Button(action: { historySearchText = "" }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var displayedHistory: [AppInfo] {
        let filterFavorites = showOnlyFavorites || isCommandPressed
        var base = filterFavorites ? historyModel.history.filter { $0.isFavorite } : historyModel.history
        if historyViewMode == .grid && isOptionPressed {
            base = base.filter { historyModel.isRunning(path: $0.path) }
        }
        if !historySearchText.isEmpty {
            base = base.filter { $0.name.localizedCaseInsensitiveContains(historySearchText) }
        }
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
        if !historyModel.apps.contains(where: { $0.path == app.path }) {
            historyModel.apps.append(app)
            historyModel.apps.sort { $0.name < $1.name }
        }
        selectedApp = historyModel.apps.first(where: { $0.path == app.path }) ?? app
        showRunningSheet = false
        launchSelectedApp()
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
            
            if !historyModel.apps.contains(where: { $0.path == path }) {
                historyModel.apps.append(appInfo)
                historyModel.apps.sort { $0.name < $1.name }
            }
            
            // 确保选择器有对应项
            selectedApp = historyModel.apps.first(where: { $0.path == path }) ?? appInfo
            launchSelectedApp()
        }
    }
    
    private func addAppFromDrop(url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        let path = url.path
        let appInfo = AppInfo(name: name, path: path)
        
        if !historyModel.apps.contains(where: { $0.path == path }) {
            historyModel.apps.append(appInfo)
            historyModel.apps.sort { $0.name < $1.name }
        }
        
        selectedApp = historyModel.apps.first(where: { $0.path == path }) ?? appInfo
        launchSelectedApp()
    }
    
    private func launchSelectedApp() {
        guard let app = selectedApp else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
        addToHistory(app: app)
        historyModel.refreshRunningAppsSoon()
    }
    
    private func launchAppFromHistory(app: AppInfo) {
        NSWorkspace.shared.open(URL(fileURLWithPath: app.path))
        selectedApp = app
        addToHistory(app: app)
        historyModel.refreshRunningAppsSoon()
    }
    
    private func addToHistory(app: AppInfo) {
        if let idx = historyModel.history.firstIndex(where: { $0.path == app.path }) {
            historyModel.history[idx].lastLaunched = Date()
        } else {
            var newApp = app
            newApp.lastLaunched = Date()
            historyModel.history.insert(newApp, at: 0)
        }
        historyModel.save()
    }
    
    private func deleteAppFromHistory(app: AppInfo) {
        if let index = historyModel.history.firstIndex(where: { $0.id == app.id }) {
            historyModel.history.remove(at: index)
        }
        historyModel.save()
    }
    
    private func toggleFavorite(app: AppInfo) {
        if let index = historyModel.history.firstIndex(where: { $0.id == app.id }) {
            historyModel.history[index].isFavorite.toggle()
        }
        historyModel.save()
    }
    
    private func moveHistoryItem(fromId: UUID, toId: UUID) {
        guard historySortMode == .manual else { return }
        if let fromIndex = historyModel.history.firstIndex(where: { $0.id == fromId }),
           let toIndex = historyModel.history.firstIndex(where: { $0.id == toId }) {
            let item = historyModel.history.remove(at: fromIndex)
            historyModel.history.insert(item, at: toIndex)
            historyModel.save()
        }
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
