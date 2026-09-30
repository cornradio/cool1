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

private struct AppPickerMenu: NSViewRepresentable {
    let apps: [AppInfo]
    @Binding var selectedApp: AppInfo?
    let onSelect: (AppInfo) -> Void

    func makeNSView(context: Context) -> NSPopUpButton {
            let button = NSPopUpButton()
            button.target = context.coordinator
            button.action = #selector(Coordinator.itemSelected(_:))
            button.isBordered = false
            button.controlSize = .small
            button.font = .systemFont(ofSize: 13)
            button.translatesAutoresizingMaskIntoConstraints = false
            rebuildMenu(button: button)
            return button
        }

        func updateNSView(_ nsView: NSPopUpButton, context: Context) {
            context.coordinator.apps = apps
            context.coordinator.onSelect = onSelect
            // 只在列表内容变化时重建
            let currentTitles = nsView.itemTitles
            let newTitles = ["（无选择）"] + apps.map(\.name)
            if currentTitles != newTitles {
                rebuildMenu(button: nsView)
            }
            // 同步选中项
            let targetTitle = selectedApp?.name ?? "（无选择）"
            if nsView.titleOfSelectedItem != targetTitle {
                nsView.selectItem(withTitle: targetTitle)
            }
        }

        private func rebuildMenu(button: NSPopUpButton) {
            button.removeAllItems()
            button.addItem(withTitle: "（无选择）")
            button.menu?.items[0].image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)

            for app in apps {
                let item = NSMenuItem(title: app.name, action: nil, keyEquivalent: "")
                item.image = NSWorkspace.shared.icon(forFile: app.path)
                item.image?.size = NSSize(width: 16, height: 16)
                button.menu?.addItem(item)
            }
            button.selectItem(withTitle: selectedApp?.name ?? "（无选择）")
        }

        func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
            let h: CGFloat = 22
            nsView.heightAnchor.constraint(equalToConstant: h).isActive = true
            return CGSize(width: proposal.width ?? 200, height: h)
        }

        func makeCoordinator() -> Coordinator { Coordinator(self) }

        final class Coordinator: NSObject {
            var parent: AppPickerMenu
            var apps: [AppInfo]
            var onSelect: (AppInfo) -> Void

            init(_ parent: AppPickerMenu) {
                self.parent = parent
                self.apps = parent.apps
                self.onSelect = parent.onSelect
            }

            @objc func itemSelected(_ sender: NSPopUpButton) {
                let index = sender.indexOfSelectedItem
                if index == 0 {
                    parent.selectedApp = nil
                } else if index > 0 && index - 1 < apps.count {
                    let app = apps[index - 1]
                    onSelect(app)
                }
            }
        }
    }

    private struct AppSearchResultRow: View {
    let app: AppInfo
    let onLaunch: () -> Void
    var isSelected: Bool = false
    @EnvironmentObject var historyModel: HistoryModel

    var body: some View {
        HStack {
            Button(action: onLaunch) {
                Image(systemName: "arrowtriangle.forward")
                    .foregroundColor(.white)
            }
            .buttonStyle(ScaleButtonStyle())
            .help("启动应用")

            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                    .overlay(
                        isSelected ? RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 2) : nil
                    )
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }

            Text(app.name)
                .fontWeight(isSelected ? .semibold : .regular)
            Spacer()
        }
    }

    private var appIcon: NSImage? {
        historyModel.icon(for: app.path)
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
    var isSelected: Bool = false
    @EnvironmentObject var historyModel: HistoryModel
    
    var body: some View {
        HStack {
            Button(action: onLaunch) {
                Image(systemName: isRunning ? "arrowtriangle.forward.fill" : "arrowtriangle.forward")
                    .foregroundColor(isRunning ? .green : .white)
            }
            .buttonStyle(ScaleButtonStyle())
            .help("启动应用")
            
            if let icon = appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                    .overlay(
                        isSelected ? RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor, lineWidth: 2) : nil
                    )
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: isSelected ? 28 : 20, height: isSelected ? 28 : 20)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            
            Text(app.name)
                .fontWeight(isSelected ? .semibold : .regular)
            Spacer()
            
            // 只有在按住 Option 键时才显示 kill 和 delete 按钮
            if isOptionPressed {
                if isRunning {
                    Button(action: onKill) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .help("停止程序")
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                }
                .help("删除")
            }
            
            Button(action: onToggleFavorite) {
                Image(systemName: app.isFavorite ? "star.fill" : "star")
                    .foregroundColor(app.isFavorite ? .yellow : .gray)
            }
            .help(app.isFavorite ? "取消收藏" : "收藏")
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
    var isSelected: Bool = false
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
                .help(app.isFavorite ? "取消收藏" : "收藏")
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
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
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

/// 收集图标网格里每个 cell 的实际布局 frame，用于二维方向键导航
private struct GridItemFramesPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private enum AppPickerStyle: String {
    case text
    case icon
}

private struct ArrowKeyHandler: ViewModifier {
    let onUp: () -> Void
    let onDown: () -> Void
    let onLeft: () -> Void
    let onRight: () -> Void
    let onReturn: () -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .onKeyPress(.upArrow) { onUp(); return .handled }
                .onKeyPress(.downArrow) { onDown(); return .handled }
                .onKeyPress(.leftArrow) { onLeft(); return .handled }
                .onKeyPress(.rightArrow) { onRight(); return .handled }
                .onKeyPress(.return) { onReturn(); return .handled }
        } else {
            content
        }
    }
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
    @State private var keyboardSelectedId: UUID?
    @State private var isInSelectMode: Bool = false
    @FocusState private var searchFieldFocused: Bool
    @State private var runningApps: [AppInfo] = []
    @State private var showRunningSheet: Bool = false
    @State private var historySortMode: HistorySortMode = .manual
    @State private var showOnlyFavorites: Bool = false
    @State private var historySearchText: String = ""
    @AppStorage(PersistedKeys.historyViewMode) private var historyViewMode: HistoryViewMode = .list
    @AppStorage(PersistedKeys.gridIconSize) private var gridIconSize: Double = 64
    @AppStorage(PersistedKeys.appPickerStyle) private var appPickerStyleRaw: String = "text"

    private var appPickerStyle: AppPickerStyle {
        AppPickerStyle(rawValue: appPickerStyleRaw) ?? .text
    }
    @State private var draggedHistoryApp: AppInfo?
    @State private var isTargetedForAppDrop = false
    @State private var flagsChangedMonitor: Any?
    @State private var keyEventMonitor: Any?
    @State private var gridItemFrames: [UUID: CGRect] = [:]
    
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
                    .help(showOnlyFavorites ? "显示全部（按住 ⌘ 临时仅显示收藏）" : "仅显示收藏（按住 ⌘ 临时启用）")
                    .disabled(historyModel.history.filter { $0.isFavorite }.isEmpty)
                    
                    Button(action: { forceShowOptions.toggle() }) {
                        Image(systemName: forceShowOptions ? "option" : "option")
                    }
                    .help(forceShowOptions ? "隐藏额外操作（按住 ⌥ 临时启用）" : "显示额外操作：停止 / 删除 / 仅运行应用（按住 ⌥ 临时启用）")
                    
                    Button(action: { historyViewMode = historyViewMode == .list ? .grid : .list }) {
                        Image(systemName: historyViewMode == .list ? "square.grid.2x2" : "list.bullet")
                    }
                    .help(historyViewMode == .list ? "切换到大图标模式" : "切换到列表模式")
                }
                
                if historyViewMode == .list {
                    if displayedHistory.isEmpty && !historySearchText.isEmpty {
                        ScrollViewReader { proxy in
                            List {
                                if appSearchResults.isEmpty {
                                    Text("没有找到匹配的应用")
                                        .foregroundColor(.secondary)
                                        .font(.callout)
                                } else {
                                    ForEach(appSearchResults) { app in
                                        AppSearchResultRow(app: app, onLaunch: { launchAppFromHistory(app: app) })
                                            .id(app.id)
                                            .tag(app.id)
                                            .listRowBackground(
                                                keyboardSelectedId == app.id && isInSelectMode
                                                    ? Color.accentColor.opacity(0.35)
                                                    : Color.clear
                                            )
                                            .listRowSeparator(.hidden)
                                    }
                                }
                            }
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .onChange(of: keyboardSelectedId) { id in
                                scrollListToSelection(proxy: proxy, id: id)
                            }
                        }
                    } else {
                        ScrollViewReader { proxy in
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
                                    .id(app.id)
                                    .tag(app.id)
                                    .listRowBackground(
                                        keyboardSelectedId == app.id && isInSelectMode
                                            ? Color.accentColor.opacity(0.35)
                                            : Color.clear
                                    )
                                    .listRowSeparator(.hidden)
                                }
                            }
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .onChange(of: keyboardSelectedId) { id in
                                scrollListToSelection(proxy: proxy, id: id)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        if isOptionPressed {
                            Text("⌥ 仅显示正在运行的应用")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if isCommandPressed {
                            Text("⌘ 仅显示收藏")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: CGFloat(gridIconSize) + 20), spacing: 16)], spacing: 16) {
                                ForEach(displayedHistory) { app in
                                    HistoryGridItemView(
                                        app: app,
                                        iconSize: CGFloat(gridIconSize),
                                        onLaunch: { launchAppFromHistory(app: app) },
                                        onToggleFavorite: { toggleFavorite(app: app) },
                                        onDelete: { deleteAppFromHistory(app: app) },
                                        onKill: { killApp(app: app) },
                                        isSelected: keyboardSelectedId == app.id && isInSelectMode
                                    )
                                    .id(app.id)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: GridItemFramesPreferenceKey.self,
                                                value: [app.id: geo.frame(in: .named("historyGrid"))]
                                            )
                                        }
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
                            .coordinateSpace(name: "historyGrid")
                            .onPreferenceChange(GridItemFramesPreferenceKey.self) { frames in
                                gridItemFrames = frames
                            }
                        }
                        .onChange(of: keyboardSelectedId) { id in
                            scrollListToSelection(proxy: proxy, id: id)
                        }
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
        if appPickerStyle == .icon {
            AppPickerMenu(
                apps: historyModel.apps,
                selectedApp: $selectedApp,
                onSelect: { app in
                    selectedApp = app
                    launchSelectedApp()
                }
            )
        } else {
            Picker("选择应用", selection: Binding(
                get: { selectedApp },
                set: { newValue in
                    selectedApp = newValue
                    if newValue != nil {
                        launchSelectedApp()
                    }
                }
            )) {
                Text("无选择").tag(nil as AppInfo?)
                ForEach(historyModel.apps) { app in
                    Text(app.name).tag(app as AppInfo?)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }

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

        // 刷新应用列表
        Button(action: { historyModel.reloadApps() }) {
            Image(systemName: "arrow.clockwise")
        }
        .help("刷新应用列表")
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
        TextField("过滤历史记录（Enter 进入选择模式）", text: $historySearchText)
            .textFieldStyle(.roundedBorder)
            .focused($searchFieldFocused)
            .onChange(of: historySearchText) { _ in
                keyboardSelectedId = nil
                if isInSelectMode { exitSelectMode() }
            }
        if !historySearchText.isEmpty {
            Button(action: { historySearchText = "" }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
    }
    
    private func enterSelectMode() {
        let candidates = displayedHistory.isEmpty ? appSearchResults : displayedHistory
        guard !candidates.isEmpty else { return }
        isInSelectMode = true
        searchFieldFocused = false
        // 默认选第一项
        if keyboardSelectedId == nil || !candidates.contains(where: { $0.id == keyboardSelectedId }) {
            keyboardSelectedId = candidates.first?.id
        }
    }

    private func exitSelectMode() {
        isInSelectMode = false
        searchFieldFocused = true
    }

    private func scrollListToSelection(proxy: ScrollViewProxy, id: UUID?) {
        guard isInSelectMode, let id else { return }
        withAnimation(.easeInOut(duration: 0.12)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    /// 从当前可见布局推断网格列数（取同行最多的那一行）
    private func inferredGridColumns() -> Int {
        let frames = Array(gridItemFrames.values)
        guard !frames.isEmpty else { return 1 }
        var maxCount = 1
        for frame in frames {
            let tol = max(frame.height * 0.55, 8)
            let count = frames.filter { abs($0.midY - frame.midY) <= tol }.count
            maxCount = max(maxCount, count)
        }
        return max(1, maxCount)
    }

    private func moveKeyboardSelection(dx: Int = 0, dy: Int = 0, toEdge: Bool = false) {
        let candidates = displayedHistory.isEmpty ? appSearchResults : displayedHistory
        guard !candidates.isEmpty else { return }

        // 列表模式：一维顺序；Shift = 跳到首/尾
        if historyViewMode == .list {
            if toEdge {
                if dy > 0 || dx > 0 {
                    keyboardSelectedId = candidates.last?.id
                } else if dy < 0 || dx < 0 {
                    keyboardSelectedId = candidates.first?.id
                }
            } else {
                let currentIndex = keyboardSelectedId.flatMap { id in candidates.firstIndex(where: { $0.id == id }) } ?? 0
                let newIndex = currentIndex + dx + dy
                if newIndex >= 0 && newIndex < candidates.count {
                    keyboardSelectedId = candidates[newIndex].id
                }
            }
            return
        }

        let currentIndex = keyboardSelectedId.flatMap { id in candidates.firstIndex(where: { $0.id == id }) } ?? 0

        // 图标模式 + Shift：按行列跳到该方向尽头
        if toEdge {
            let columns = inferredGridColumns()
            let row = currentIndex / columns
            let col = currentIndex % columns
            let count = candidates.count
            let newIndex: Int
            if dx > 0 {
                newIndex = min(row * columns + columns - 1, count - 1)
            } else if dx < 0 {
                newIndex = row * columns
            } else if dy > 0 {
                var i = col
                while i + columns < count { i += columns }
                newIndex = i
            } else if dy < 0 {
                newIndex = col
            } else {
                return
            }
            keyboardSelectedId = candidates[newIndex].id
            return
        }

        // 图标模式：根据实际布局 frame 找上下左右邻居
        guard let currentId = keyboardSelectedId,
              let currentFrame = gridItemFrames[currentId] else {
            keyboardSelectedId = candidates.first?.id
            return
        }

        let origin = CGPoint(x: currentFrame.midX, y: currentFrame.midY)
        let rowTolerance = max(currentFrame.height * 0.55, 8)

        struct Neighbor {
            let id: UUID
            let primary: CGFloat
            let secondary: CGFloat
        }

        var best: Neighbor?

        for app in candidates {
            guard app.id != currentId, let frame = gridItemFrames[app.id] else { continue }
            let deltaX = frame.midX - origin.x
            let deltaY = frame.midY - origin.y

            let neighbor: Neighbor?
            switch (dx, dy) {
            case (1, _):
                guard deltaX > 1, abs(deltaY) <= rowTolerance else { continue }
                neighbor = Neighbor(id: app.id, primary: deltaX, secondary: abs(deltaY))
            case (-1, _):
                guard deltaX < -1, abs(deltaY) <= rowTolerance else { continue }
                neighbor = Neighbor(id: app.id, primary: -deltaX, secondary: abs(deltaY))
            case (_, 1):
                guard deltaY > 1 else { continue }
                neighbor = Neighbor(id: app.id, primary: deltaY, secondary: abs(deltaX))
            case (_, -1):
                guard deltaY < -1 else { continue }
                neighbor = Neighbor(id: app.id, primary: -deltaY, secondary: abs(deltaX))
            default:
                continue
            }

            guard let neighbor else { continue }

            if let currentBest = best {
                let better: Bool
                if dy != 0 {
                    if abs(neighbor.secondary - currentBest.secondary) > 1 {
                        better = neighbor.secondary < currentBest.secondary
                    } else {
                        better = neighbor.primary < currentBest.primary
                    }
                } else {
                    better = neighbor.primary < currentBest.primary
                }
                if better { best = neighbor }
            } else {
                best = neighbor
            }
        }

        if let best {
            keyboardSelectedId = best.id
        }
    }

    private func launchKeyboardSelected() {
        guard let id = keyboardSelectedId else { return }
        let candidates = displayedHistory.isEmpty ? appSearchResults : displayedHistory
        if let app = candidates.first(where: { $0.id == id }) {
            launchAppFromHistory(app: app)
        }
        isInSelectMode = false
    }

    private var displayedHistory: [AppInfo] {
        let filterFavorites = showOnlyFavorites || isCommandPressed
        var base = filterFavorites ? historyModel.history.filter { $0.isFavorite } : historyModel.history
        if historyViewMode == .grid && isOptionPressed {
            base = base.filter { historyModel.isRunning(path: $0.path) }
        }
        if !historySearchText.isEmpty {
            base = base.filter { appNameMatches(query: historySearchText, name: $0.name) }
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
    
    private var appSearchResults: [AppInfo] {
        guard !historySearchText.isEmpty else { return [] }
        let historyPaths = Set(historyModel.history.map { $0.path })
        return historyModel.apps
            .filter { !historyPaths.contains($0.path) && appNameMatches(query: historySearchText, name: $0.name) }
            .sorted { $0.name < $1.name }
    }

    private func appNameMatches(query: String, name: String) -> Bool {
        // 1. 原始名称直接匹配
        if name.localizedCaseInsensitiveContains(query) {
            return true
        }
        // 2. 拼音首字母 + 全拼匹配
        let full = pinyinString(name)
        let initials = pinyinInitials(fromFullPinyin: full)
        let q = query.lowercased()
        return full.contains(q) || initials.hasPrefix(q) || initials.contains(q)
    }

    private func pinyinString(_ string: String) -> String {
        let ms = NSMutableString(string: string) as CFMutableString
        CFStringTransform(ms, nil, kCFStringTransformToLatin, false)
        CFStringTransform(ms, nil, kCFStringTransformStripDiacritics, false)
        return (ms as String).lowercased()
    }

    private func pinyinInitials(fromFullPinyin full: String) -> String {
        full.split(separator: " ").compactMap { $0.first }.map { String($0) }.joined()
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
        // 先清理一次，避免弹出面板反复打开时监听器越叠越多
        removeOptionKeyMonitor()
        
        // 只用事件驱动的本地监听（只有 cool1 是前台、真正收到键盘事件时才会触发，
        // 不会在别的 app 是前台时持续跑），不再用常驻的轮询 Timer
        flagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            self.isOptionPressed = event.modifierFlags.contains(.option)
            self.isCommandPressed = event.modifierFlags.contains(.command)
            return event
        }
        
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            self.isOptionPressed = event.modifierFlags.contains(.option)
            self.isCommandPressed = event.modifierFlags.contains(.command)

            if event.type == .keyDown {
                // Enter 键
                if event.keyCode == 36 {
                    if self.isInSelectMode {
                        // 选中模式下 Enter = 启动
                        self.launchKeyboardSelected()
                        return nil
                    } else {
                        // 搜索模式下 Enter = 进入选中模式
                        self.enterSelectMode()
                        return nil
                    }
                }

                // Esc 键：退出选中模式
                if event.keyCode == 53 {
                    if self.isInSelectMode {
                        self.exitSelectMode()
                        return nil
                    }
                }

                // 选中模式下拦截方向键（列表一维；图标网格二维；Shift = 跳到尽头）
                if self.isInSelectMode {
                    let toEdge = event.modifierFlags.contains(.shift)
                    switch event.keyCode {
                    case 125: // 下
                        self.moveKeyboardSelection(dy: 1, toEdge: toEdge)
                        return nil
                    case 126: // 上
                        self.moveKeyboardSelection(dy: -1, toEdge: toEdge)
                        return nil
                    case 124: // 右
                        self.moveKeyboardSelection(dx: 1, toEdge: toEdge)
                        return nil
                    case 123: // 左
                        self.moveKeyboardSelection(dx: -1, toEdge: toEdge)
                        return nil
                    default:
                        break
                    }
                }
            }

            return event
        }
        
        // 只在刚出现时读一次当前修饰键状态（比如面板打开时键已经按住了），之后全靠事件驱动
        checkModifierKeyState()
    }
    
    private func checkModifierKeyState() {
        let currentFlags = NSEvent.modifierFlags
        isOptionPressed = currentFlags.contains(.option)
        isCommandPressed = currentFlags.contains(.command)
    }
    
    private func removeOptionKeyMonitor() {
        if let flagsChangedMonitor {
            NSEvent.removeMonitor(flagsChangedMonitor)
            self.flagsChangedMonitor = nil
        }
        if let keyEventMonitor {
            NSEvent.removeMonitor(keyEventMonitor)
            self.keyEventMonitor = nil
        }
    }
}
