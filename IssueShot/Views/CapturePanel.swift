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
        hosting = NSHostingView(rootView: CapturePanelView(controls: controls, isCollapsed: controls.isPanelCollapsed))
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
        // 保存されていた大きさは畳む前後のどちらか分からないので、いまの中身に合わせ直す
        applyFrame(for: fittingSize(collapsed: controls.isPanelCollapsed))
    }

    /// 畳む／広げる。先に大きさと位置を決めてから中身を入れ替えるので、途中の形が一瞬見えない。
    func setCollapsed(_ collapsed: Bool) {
        applyFrame(for: fittingSize(collapsed: collapsed))
        hosting.rootView = CapturePanelView(controls: controls, isCollapsed: collapsed)
        hosting.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
    }

    /// 表示前の中身の大きさを測る（畳んだ形・広げた形のどちらでも）
    private func fittingSize(collapsed: Bool) -> CGSize {
        NSHostingView(rootView: CapturePanelView(controls: controls, isCollapsed: collapsed)).fittingSize
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
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 2) {
            // 畳んでいても、左のつまみをドラッグして動かせるようにする
            grip(width: isCollapsed ? 11 : 14)
            if isCollapsed {
                PanelButton(systemImage: "camera.viewfinder", help: String(localized: "パネルを広げる")) {
                    controls.isPanelCollapsed = false
                }
            } else {
                buttons
            }
        }
        .padding(.leading, 3)
        .padding(.trailing, 5)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(isDropTargeted ? AnyShapeStyle(RevvyStyle.accent) : AnyShapeStyle(.separator), lineWidth: isDropTargeted ? 2 : 1))
        // どのアプリからでも、パネルに画像を落とせば取り込める（畳んでいても受ける）
        .onDrop(of: ImageDrop.acceptedTypes, isTargeted: $isDropTargeted) { providers in
            Task { await controls.importDroppedImage(providers) }
            return true
        }
        .padding(1)
        .fixedSize()
        .disabled(controls.isRecordingShortcut)
    }

    /// 縦に並んだ点でつまみを示す。ここをドラッグするとパネルごと動く。
    private func grip(width: CGFloat) -> some View {
        Image(systemName: "ellipsis")
            .rotationEffect(.degrees(90))
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.tertiary)
            .frame(width: width, height: 30)
            .background(WindowDragHandle())
            .help("ドラッグで移動")
    }

    @ViewBuilder
    private var buttons: some View {
        PanelButton(systemImage: "viewfinder", help: help(String(localized: "範囲を選んで撮影"), .captureRegion)) {
            Task { await controls.capture(.interactive) }
        }
        PanelButton(systemImage: "display", help: help(String(localized: "画面全体を撮影"), .captureFullScreen)) {
            Task { await controls.capture(.fullScreen) }
        }
        PanelButton(systemImage: "ruler", help: help(String(localized: "画面にルーラーを追加"), .newRuler)) {
            controls.rulers.add()
        }
        PanelButton(systemImage: "rectangle.split.2x1", help: help(String(localized: "縦のガイド線を追加"), .newVerticalGuide)) {
            controls.rulers.addGuide(.vertical)
        }
        PanelButton(systemImage: "rectangle.split.1x2", help: help(String(localized: "横のガイド線を追加"), .newHorizontalGuide)) {
            controls.rulers.addGuide(.horizontal)
        }
        Rectangle()
            .fill(.separator)
            .frame(width: 1, height: 18)
            .padding(.horizontal, 2)
        PanelButton(systemImage: "macwindow", help: String(localized: "Revvy を開く")) {
            controls.presentMainWindow()
        }
        // 完全に消すとどこから撮るか分からなくなるので、× は畳むだけにする。
        // 隠すのはメニューバー・設定・ショートカットから。
        PanelButton(systemImage: "xmark", help: String(localized: "パネルを小さくする")) {
            controls.isPanelCollapsed = true
        }
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
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .background(isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}
