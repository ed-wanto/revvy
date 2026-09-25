import AppKit
import SwiftUI

/// どのアプリの上にも浮かぶ小さな撮影パネル。押しても Revvy を前面にしない。
@MainActor
final class CapturePanelController {
    private let controls: CaptureControls
    private let panel: NSPanel
    private let hosting: NSHostingView<CapturePanelView>

    init(controls: CaptureControls) {
        self.controls = controls
        let view = CapturePanelController.makeView(controls)
        hosting = NSHostingView(rootView: view)
        hosting.setFrameSize(hosting.fittingSize)

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        // 前回の位置を覚える。初回はカーソルのある画面の右上に置く。
        if !panel.setFrameUsingName(Self.autosaveName) {
            let screen = DisplayLocator.screen(containing: NSEvent.mouseLocation)
            let visible = screen.visibleFrame
            panel.setFrameTopLeftPoint(CGPoint(x: visible.maxX - panel.frame.width - 24, y: visible.maxY - 24))
        }
        panel.setFrameAutosaveName(Self.autosaveName)
        // 保存されていた大きさは畳む前後や大きさを変える前のものかもしれないので、いまの中身に合わせ直す
        applyFrame(for: Self.fittingSize(of: view))
    }

    /// 畳む／広げる、大きさや色を変えたときに呼ぶ。先に大きさと位置を決めてから中身を入れ替えるので、途中の形が一瞬見えない。
    func refresh() {
        let view = Self.makeView(controls)
        applyFrame(for: Self.fittingSize(of: view))
        hosting.rootView = view
        hosting.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
    }

    /// いまの状態（畳んだか・大きさ・色）で中身を作る。表示前に大きさを測れるよう、状態は外から渡す。
    private static func makeView(_ controls: CaptureControls) -> CapturePanelView {
        CapturePanelView(
            controls: controls,
            isCollapsed: controls.isPanelCollapsed,
            look: CapturePanelLook(size: controls.panelSize, color: controls.panelColor)
        )
    }

    /// 表示前の中身の大きさを測る
    private static func fittingSize(of view: CapturePanelView) -> CGSize {
        NSHostingView(rootView: view).fittingSize
    }

    /// 初期位置が画面の右上なので、右上の角を動かさずに大きさを変える（右端から飛び出さないように）
    private func applyFrame(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let corner = CGPoint(x: panel.frame.maxX, y: panel.frame.maxY)
        var frame = CGRect(x: corner.x - size.width, y: corner.y - size.height, width: size.width, height: size.height)
        let visible = (panel.screen ?? DisplayLocator.screen(containing: corner)).visibleFrame
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        guard frame != panel.frame else { return }
        panel.setFrame(frame, display: false, animate: false)
    }

    private static let autosaveName = "RevvyCapturePanel"

    func show() {
        // 繋いでいたディスプレイが外れて画面外に取り残されたら、カーソルのある画面へ戻す。
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) {
            let visible = DisplayLocator.screen(containing: NSEvent.mouseLocation).visibleFrame
            panel.setFrameTopLeftPoint(CGPoint(x: visible.maxX - panel.frame.width - 24, y: visible.maxY - 24))
        }
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}

private struct CapturePanelView: View {
    let controls: CaptureControls
    /// 大きさを先に測れるよう、状態は外から渡す
    let isCollapsed: Bool
    let look: CapturePanelLook
    @State private var isDropTargeted = false

    private var scale: CGFloat { look.size.scale }

    var body: some View {
        HStack(spacing: 2 * scale) {
            // 畳んでいても、左のつまみをドラッグして動かせるようにする
            grip(width: (isCollapsed ? 11 : 14) * scale)
            if isCollapsed {
                // 撮影ボタンと見間違えないよう、パネルが伸びる向き（左）を指す記号にする
                button("chevron.left.2", help: String(localized: "パネルを広げる")) {
                    controls.isPanelCollapsed = false
                }
            } else {
                buttons
            }
        }
        .padding(.leading, 3 * scale)
        .padding(.trailing, 5 * scale)
        .padding(.vertical, 4 * scale)
        .background(look.color.background, in: Capsule())
        .overlay(Capsule().strokeBorder(isDropTargeted ? look.color.dropHighlight : AnyShapeStyle(.separator), lineWidth: isDropTargeted ? 2 : 1))
        // どのアプリからでも、パネルに画像を落とせば取り込める（畳んでいても受ける）
        .onDrop(of: ImageDrop.acceptedTypes, isTargeted: $isDropTargeted) { providers in
            Task { await controls.importDroppedImage(providers) }
            return true
        }
        // 右クリックで大きさと色を変える（設定の「フローティングパネル」と同じ項目）
        .contextMenu { appearanceMenu }
        .padding(1)
        .fixedSize()
        .disabled(controls.isRecordingShortcut)
    }

    /// 縦に並んだ点でつまみを示す。ここをドラッグするとパネルごと動く。
    private func grip(width: CGFloat) -> some View {
        Image(systemName: "ellipsis")
            .rotationEffect(.degrees(90))
            .font(.system(size: 11 * scale, weight: .bold))
            .foregroundStyle(look.color.subdued)
            .frame(width: width, height: look.size.buttonSize)
            .background(WindowDragHandle())
            .help("ドラッグで移動")
    }

    @ViewBuilder
    private var buttons: some View {
        button("viewfinder", help: help(String(localized: "範囲を選んで撮影"), .captureRegion)) {
            Task { await controls.capture(.interactive) }
        }
        button("display", help: help(String(localized: "画面全体を撮影"), .captureFullScreen)) {
            Task { await controls.capture(.fullScreen) }
        }
        button("ruler", help: help(String(localized: "画面にルーラーを追加"), .newRuler)) {
            controls.rulers.add()
        }
        button("rectangle.split.2x1", help: help(String(localized: "縦のガイド線を追加"), .newVerticalGuide)) {
            controls.rulers.addGuide(.vertical)
        }
        button("rectangle.split.1x2", help: help(String(localized: "横のガイド線を追加"), .newHorizontalGuide)) {
            controls.rulers.addGuide(.horizontal)
        }
        // 置いたルーラーとガイド線をまとめて片付ける。何も無いときは押せないだけで、パネルの形は変えない。
        button("eraser", help: help(String(localized: "ルーラーとガイド線をすべて消す"), .clearRulers)) {
            controls.rulers.closeAll()
        }
        .disabled(controls.rulers.isEmpty)
        Rectangle()
            .fill(look.color.divider)
            .frame(width: 1, height: 18 * scale)
            .padding(.horizontal, 2 * scale)
        button("macwindow", help: String(localized: "Revvy を開く")) {
            controls.presentMainWindow()
        }
        // 完全に消すとどこから撮るか分からなくなるので、ここでは畳むだけにする。
        // 閉じる（×）と間違えないよう、畳む向き（右）を指す記号にする。隠すのはメニューバー・設定・ショートカットから。
        button("chevron.right.2", help: String(localized: "パネルを小さくする")) {
            controls.isPanelCollapsed = true
        }
    }

    /// 右クリックのメニュー。設定の「フローティングパネル」でも同じものを変えられる。
    @ViewBuilder
    private var appearanceMenu: some View {
        Picker("サイズ", selection: Binding(get: { look.size }, set: { controls.panelSize = $0 })) {
            ForEach(CapturePanelSize.allCases) { size in
                Text(size.title).tag(size)
            }
        }
        Picker("色", selection: Binding(get: { look.color }, set: { controls.panelColor = $0 })) {
            ForEach(CapturePanelColor.allCases) { color in
                Text(color.title).tag(color)
            }
        }
    }

    private func button(_ systemImage: String, help: String, action: @escaping () -> Void) -> PanelButton {
        PanelButton(systemImage: systemImage, help: help, look: look, action: action)
    }

    private func help(_ title: String, _ action: ShortcutAction) -> String {
        guard let shortcut = controls.shortcuts[action] else { return title }
        return String(localized: "\(title)（\(shortcut.displayString)）")
    }
}

/// パネルを動かすための当たり判定。背景ドラッグ任せだと反応しないことがあるので、自分でウィンドウを動かす。
private struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ view: NSView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}

private struct PanelButton: View {
    let systemImage: String
    let help: String
    let look: CapturePanelLook
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: look.size.iconSize, weight: .medium))
                .foregroundStyle(look.color.foreground)
                .frame(width: look.size.buttonSize, height: look.size.buttonSize)
                .background(isHovering && isEnabled ? look.color.hover : AnyShapeStyle(.clear), in: Circle())
                .contentShape(Circle())
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(PanelButtonStyle())
        .onHover { isHovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// 押している間だけ少し薄くする。押せないときの見た目は PanelButton が決める（標準のスタイルと二重に薄くならないように）。
private struct PanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - 見た目

/// パネルの大きさ。「中」が以前からの大きさ（30pt のボタン）。
enum CapturePanelSize: String, CaseIterable, Identifiable, Sendable {
    case small
    case medium
    case large
    case extraLarge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: String(localized: "小")
        case .medium: String(localized: "中")
        case .large: String(localized: "大")
        case .extraLarge: String(localized: "特大")
        }
    }

    /// ボタンの一辺（pt）。記号・つまみ・余白もこれに比例させる。
    var buttonSize: CGFloat {
        switch self {
        case .small: 24
        case .medium: 30
        case .large: 38
        case .extraLarge: 46
        }
    }

    var scale: CGFloat { buttonSize / Self.medium.buttonSize }
    var iconSize: CGFloat { 14 * scale }
}

/// パネルの色。標準はシステムの素材（ライト／ダークに合わせる）。ほかは塗りつぶし、記号は塗りの上で読める白か黒にする。
/// 並びは macOS のアクセントカラーに合わせる。
enum CapturePanelColor: String, CaseIterable, Identifiable, Sendable {
    case standard
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: String(localized: "標準")
        case .blue: String(localized: "ブルー")
        case .purple: String(localized: "パープル")
        case .pink: String(localized: "ピンク")
        case .red: String(localized: "レッド")
        case .orange: String(localized: "オレンジ")
        case .yellow: String(localized: "イエロー")
        case .green: String(localized: "グリーン")
        case .graphite: String(localized: "グラファイト")
        }
    }

    /// 塗りの色。標準は素材を敷くので nil。緑はブランドの緑（RevvyStyle.accent のライト）。
    var fillRGB: CapturePanelRGB? {
        switch self {
        case .standard: nil
        case .blue: CapturePanelRGB(hex: 0x0A64D6)
        case .purple: CapturePanelRGB(hex: 0x7B4AE2)
        case .pink: CapturePanelRGB(hex: 0xD63A78)
        case .red: CapturePanelRGB(hex: 0xD12F2F)
        case .orange: CapturePanelRGB(hex: 0xD2600A)
        case .yellow: CapturePanelRGB(hex: 0xF2C200)
        case .green: CapturePanelRGB(hex: 0x0C7A5A)
        case .graphite: CapturePanelRGB(hex: 0x2C2E33)
        }
    }

    /// 塗りの上に置く記号の色。明るい黄色だけは白だと読めないので黒にする。
    var inkRGB: CapturePanelRGB {
        self == .yellow ? CapturePanelRGB(hex: 0x1F1F1F) : CapturePanelRGB(hex: 0xFFFFFF)
    }

    var fill: Color? { fillRGB?.color }
}

/// sRGB の色。数値で持つのは、塗りと記号のコントラストをテストで確かめるため。
struct CapturePanelRGB: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }
}

/// パネルの大きさと色。描画するビューにまとめて渡す。
struct CapturePanelLook: Equatable {
    var size: CapturePanelSize
    var color: CapturePanelColor
}

private extension CapturePanelColor {
    var ink: Color { inkRGB.color }
    /// パネルの地
    var background: AnyShapeStyle { fill.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.regularMaterial) }
    /// ボタンの記号
    var foreground: AnyShapeStyle { self == .standard ? AnyShapeStyle(.primary) : AnyShapeStyle(ink) }
    /// つまみ
    var subdued: AnyShapeStyle { self == .standard ? AnyShapeStyle(.tertiary) : AnyShapeStyle(ink.opacity(0.55)) }
    /// マウスを乗せたボタンの丸
    var hover: AnyShapeStyle { self == .standard ? AnyShapeStyle(.quaternary) : AnyShapeStyle(ink.opacity(0.2)) }
    /// 区切り線
    var divider: AnyShapeStyle { self == .standard ? AnyShapeStyle(.separator) : AnyShapeStyle(ink.opacity(0.3)) }
    /// 画像をドロップできるときの縁。塗りがブランドの緑でも見えるよう、塗りのときは記号の色にする。
    var dropHighlight: AnyShapeStyle { self == .standard ? AnyShapeStyle(RevvyStyle.accent) : AnyShapeStyle(ink) }
}

/// 設定でパネルの色を選ぶ見本。macOS のアクセントカラーと同じく丸を並べる。
struct CapturePanelColorPicker: View {
    @Binding var selection: CapturePanelColor

    var body: some View {
        HStack(spacing: 2) {
            ForEach(CapturePanelColor.allCases) { color in
                Button { selection = color } label: {
                    swatch(color)
                        .frame(width: 16, height: 16)
                        .padding(4)
                        .overlay {
                            Circle()
                                .stroke(Color.primary.opacity(selection == color ? 0.65 : 0), lineWidth: 1.5)
                                .frame(width: 23, height: 23)
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(color.title)
                .accessibilityLabel(color.title)
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private func swatch(_ color: CapturePanelColor) -> some View {
        if let fill = color.fill {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15)))
        } else {
            // 標準はライト／ダークで変わるので、半分ずつ塗った丸で示す
            Image(systemName: "circle.lefthalf.filled")
                .resizable()
                .foregroundStyle(.secondary)
        }
    }
}
