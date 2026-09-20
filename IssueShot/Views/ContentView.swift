import SwiftUI

/// サイドバー（履歴）・キャンバス（画像）・インスペクタ（Issue）の三ペイン。
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(CaptureControls.self) private var controls
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("ui.showInspector") private var showInspector = true
    @State private var showConnect = false
    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $columnVisibility) {
            CaptureSidebarView(showConnect: $showConnect)
                .navigationSplitViewColumnWidth(min: 196, ideal: 216, max: 300)
        } detail: {
            EditorCanvasView()
                .navigationTitle(model.windowTitle)
                .navigationSubtitle(model.windowSubtitle)
                .toolbar { toolbar }
                .inspector(isPresented: $showInspector) {
                    ReportInspector(showConnect: $showConnect)
                        .inspectorColumnWidth(min: 290, ideal: 310, max: 420)
                }
        }
        .tint(RevvyStyle.accent)
        // ドロップはウィンドウ全体で受ける（サイドバーやインスペクタの上に落としても取り込む）
        .onDrop(of: ImageDrop.acceptedTypes, isTargeted: $isDropTargeted) { providers in
            Task { await model.importDroppedImage(providers) }
            return true
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(RevvyStyle.accent, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                    .background(RevvyStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        Label("ドロップして画像を取り込む", systemImage: "square.and.arrow.down")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        // 注釈はキャンバスで編集するので、保存と共有リンクの無効化はここで面倒を見る。
        .onChange(of: model.annotations) { _, _ in
            model.persistAnnotations()
            model.shareURL = nil
            if !model.isSharing { model.shareStatus = nil }
        }
        .onChange(of: model.selectedRepo) { _, _ in
            model.shareURL = nil
            if !model.isSharing { model.shareStatus = nil }
        }
        .onChange(of: model.user) { _, user in if user != nil { showConnect = false } }
        .sheet(isPresented: $showConnect) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("閉じる") { showConnect = false }
                }
                .padding(14)
                if model.auth == .checking { ProgressView("接続中…").padding(50) }
                else { ConnectView() }
            }
            .frame(width: 620)
        }
        .sheet(item: Binding(
            get: { model.result.map { ResultSheetItem(result: $0, warning: model.errorMessage) } },
            set: { if $0 == nil { model.result = nil; model.errorMessage = nil } }
        )) { ResultSheet(item: $0) }
        .alert("操作を完了できませんでした", isPresented: Binding(
            get: { model.errorMessage != nil && model.result == nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    /// 設定で登録したショートカットを出す（⌘⇧4 は macOS が使うので Revvy には届かない）
    private var captureHelp: String {
        let title = String(localized: "範囲を選んで撮影")
        guard let shortcut = controls.shortcuts[.captureRegion] else { return title }
        return String(localized: "\(title)（\(shortcut.displayString)）")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Menu {
                ForEach(CaptureMode.allCases) { mode in
                    Button(mode.title, systemImage: mode.systemImage) { Task { await model.capture(mode) } }
                }
                Divider()
                Button("画像ファイルを開く…") { model.importImage() }
                Button("クリップボードから貼り付け") { model.pasteScreenshot() }
                if model.screenshot != nil {
                    Divider()
                    Button("編集中の画像を閉じる") { model.clearScreenshot() }
                }
            } label: {
                Label("撮影", systemImage: "camera.viewfinder")
            } primaryAction: {
                Task { await model.capture(.interactive) }
            }
            .disabled(model.isCapturing)
            .help(captureHelp)
        }

        ToolbarItem {
            Menu {
                Toggle("座標ルーラー", isOn: Binding(get: { model.showPixelRulers }, set: { model.showPixelRulers = $0 }))
                Toggle("センターガイド", isOn: Binding(get: { model.showCenterGuides }, set: { model.showCenterGuides = $0 }))
                Divider()
                Text("どちらも書き出しには含まれません")
            } label: {
                Label("ガイド", systemImage: "ruler")
            }
            .disabled(model.screenshot == nil)
            .help("座標ルーラーとセンターガイドの表示")
        }

        ToolbarItem { ZoomControl() }

        ToolbarItem {
            Menu {
                Button("画像をコピー", systemImage: "square.on.square") { model.copyImage() }
                Button("PNG で保存…", systemImage: "arrow.down.to.line") { model.exportImage() }
                if model.user != nil {
                    Divider()
                    Button("リンクを作成してコピー", systemImage: "link") { Task { await model.shareScreenshot() } }
                        .disabled(model.selectedRepo == nil || model.isSharing || model.isSubmitting)
                    if let url = model.shareURL { Link("共有画像を開く", destination: url) }
                }
            } label: {
                Label("共有", systemImage: "square.and.arrow.up")
            }
            .disabled(model.screenshot == nil)
            .help("画像をコピー・保存・共有")
        }

        ToolbarItem {
            Button { showInspector.toggle() } label: {
                Label("インスペクタ", systemImage: "sidebar.trailing")
            }
            .help(showInspector ? "インスペクタを隠す" : "インスペクタを表示")
        }
    }
}

/// 倍率はキャンバスを覆わないようツールバーに置く。
private struct ZoomControl: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Toggle("全体表示", isOn: Binding(get: { model.requestedZoom == nil }, set: { _ in model.zoomToFit() }))
            Divider()
            ForEach([25, 50, 100, 200, 400], id: \.self) { percent in
                Toggle(percent == 100 ? "\(percent)%（実寸）" : "\(percent)%", isOn: Binding(
                    get: { model.requestedZoom.map { Int(($0 * 100).rounded()) == percent } ?? false },
                    set: { _ in model.requestedZoom = CGFloat(percent) / 100 }
                ))
            }
            Divider()
            Button("拡大") { model.zoomIn() }
            Button("縮小") { model.zoomOut() }
        } label: {
            Text(model.zoomLabel)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .frame(minWidth: 40)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(model.screenshot == nil)
        .help("倍率（100% は元画像 1px を画面 1pt で表示）")
    }
}
