import SwiftUI

/// 画像を置く面。カードにも二重の角丸にも入れず、ウィンドウいっぱいのキャンバスに直接置く。
struct EditorCanvasView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            RevvyStyle.canvas
            DotGrid()
            if let image = model.screenshot {
                AnnotatorView(
                    image: image,
                    annotations: model.annotations,
                    selectedID: $model.selectedAnnotationID,
                    tool: model.tool,
                    color: model.annotationColor,
                    showPixelRulers: model.showPixelRulers,
                    showCenterGuides: model.showCenterGuides,
                    onCommit: model.commitAnnotations,
                    onNudge: { dx, dy, fast in model.nudgeSelectedAnnotation(dx: dx, dy: dy, fast: fast) },
                    requestedZoom: $model.requestedZoom,
                    displayScale: $model.displayedZoom,
                    handMode: $model.isPanningCanvas
                )
                // 下辺はパレットと目盛りのぶんだけ空ける。
                .padding(EdgeInsets(top: 30, leading: 30, bottom: 76, trailing: 30))
            } else {
                EmptyCanvasState()
            }
        }
        .overlay(alignment: .bottom) {
            if model.screenshot != nil { AnnotationPalette().padding(.bottom, 16) }
        }
        .overlay(alignment: .bottomLeading) { hud(model.screenshot.map { "\($0.width) × \($0.height) px" }) }
        .overlay(alignment: .bottomTrailing) { hud(model.screenshot == nil ? nil : hint) }
        .contextMenu {
            Button("複製") { model.duplicateSelectedAnnotation() }
                .disabled(model.selectedAnnotationID == nil)
            Button("削除", role: .destructive) { model.deleteSelectedAnnotation() }
                .disabled(model.selectedAnnotationID == nil)
            Divider()
            Toggle("座標ルーラー", isOn: Binding(get: { model.showPixelRulers }, set: { model.showPixelRulers = $0 }))
            Toggle("センターガイド", isOn: Binding(get: { model.showCenterGuides }, set: { model.showCenterGuides = $0 }))
        }
        .frame(minWidth: 380, minHeight: 320)
    }

    private var hint: String {
        if model.isPanningCanvas { return String(localized: "ドラッグで画像を移動") }
        if model.selectedAnnotationID != nil { return String(localized: "矢印キーで 1px 調整（⇧ で 10px）· ⌘D 複製 · ⌫ 削除") }
        if model.tool == .select { return String(localized: "図形をクリックで選択 · ドラッグで移動") }
        if model.tool == .text { return String(localized: "クリックで文字を置く · ↩ で確定 · ⌥↩ で改行 · 置いた文字はクリックで編集") }
        if model.tool == .ruler { return String(localized: "ドラッグで計測 · ⇧ で水平／垂直 · ⌥ で図形に重ねる") }
        return String(localized: "ドラッグで描画 · 図形の近くは移動 · ⌥ で重ねて描画")
    }

    @ViewBuilder
    private func hud(_ text: String?) -> some View {
        if let text {
            Text(text)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
                .allowsHitTesting(false)
        }
    }
}

/// 実寸の手がかりになる方眼。画像そのものには焼き込まれない。
private struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            let dot = Color.primary.opacity(0.10)
            for x in stride(from: 8.0, to: size.width, by: 15) {
                for y in stride(from: 8.0, to: size.height, by: 15) {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(dot))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 注釈ツール。ウィンドウ下辺ではなくキャンバスの上に浮かせる。
struct AnnotationPalette: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AnnotationTool.allCases) { tool in
                ToolButton(symbol: tool.systemImage,
                           title: tool.title,
                           selected: !model.isPanningCanvas && model.tool == tool) {
                    model.isPanningCanvas = false
                    model.tool = tool
                }
            }
            ToolButton(symbol: "hand.draw",
                       title: String(localized: "手のひら：画像をドラッグして移動"),
                       selected: model.isPanningCanvas) {
                model.isPanningCanvas.toggle()
            }

            ToolDivider()

            ForEach(AnnotationColor.allCases) { color in
                Button { model.annotationColor = color } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 15, height: 15)
                        .padding(5)
                        .overlay {
                            Circle()
                                .stroke(Color.primary.opacity(model.annotationColor == color ? 0.65 : 0), lineWidth: 1.5)
                                .frame(width: 21, height: 21)
                        }
                }
                .buttonStyle(.plain)
                .help(color.title)
                .accessibilityLabel(color.title)
            }

            ToolDivider()

            ToolButton(symbol: "arrow.uturn.backward", title: String(localized: "注釈を取り消す（⌘Z）")) { model.undoAnnotation() }
                .disabled(!model.canUndoAnnotation)
            ToolButton(symbol: "arrow.uturn.forward", title: String(localized: "注釈をやり直す（⇧⌘Z）")) { model.redoAnnotation() }
                .disabled(!model.canRedoAnnotation)
            ToolButton(symbol: "trash", title: String(localized: "選択した注釈を削除（⌫）")) { model.deleteSelectedAnnotation() }
                .disabled(model.selectedAnnotationID == nil)
        }
        .padding(5)
        .floatingPanel()
    }
}

/// 撮影前の状態。骨格は変えず、最初の一手だけを残す。
private struct EmptyCanvasState: View {
    @Environment(AppModel.self) private var model
    @Environment(CaptureControls.self) private var controls

    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: RevvyStyle.Radius.field)
                .strokeBorder(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .frame(width: 84, height: 64)
                .overlay {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 26, weight: .ultraLight))
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text("その画面を、会話のはじまりに。")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.3)
                Text("撮影して、書き込んで、すぐにシェア。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Button { Task { await model.capture(.interactive) } } label: {
                Label(model.isCapturing ? "撮影中…" : "範囲を選んで撮影", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isCapturing)
            Text(controls.shortcuts[.captureRegion].map { String(localized: "\($0.displayString) で撮影 · ⌘⇧V で貼り付け · 画像をここにドロップ") }
                 ?? String(localized: "⌘⇧V で貼り付け · 画像をここにドロップ"))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(28)
    }
}
