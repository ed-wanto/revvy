import AppKit

/// 画面の上に浮かべて測るルーラー（Linear 相当）。スクリーンショットを撮らずに、どのアプリの上でも使える。
/// 値はポイント単位。Web の CSS px と同じ尺度なので、そのまま px として表示する。
@MainActor
final class ScreenRulers {
    private var panels: [RulerPanel] = []
    private var guides: [GuidePanel] = []
    private(set) var isHidden = false

    var isEmpty: Bool { panels.isEmpty && guides.isEmpty }

    /// カーソルのある画面に、カーソルを中心として置く
    func add() {
        let mouse = NSEvent.mouseLocation
        let screen = DisplayLocator.screen(containing: mouse)
        let size = ScreenRulerGeometry.defaultSize
        // カーソル位置は小数になるので、整数ポイントに揃えないと大きさが 1pt ずれて表示される
        let frame = CGRect(x: (mouse.x - size.width / 2).rounded(), y: (mouse.y - size.height / 2).rounded(), width: size.width, height: size.height)
        add(frame: ScreenRulerGeometry.constrained(frame, to: screen.visibleFrame))
    }

    func add(frame: CGRect) {
        showAll()
        let panel = RulerPanel(frame: frame, owner: self)
        panels.append(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    func duplicate(_ panel: RulerPanel) {
        // 重なって見分けられないので少しずらす（Linear と同じ）
        add(frame: panel.frame.offsetBy(dx: 10, dy: -10))
    }

    func close(_ panel: RulerPanel) {
        panel.orderOut(nil)
        panels.removeAll { $0 === panel }
        if isEmpty { isHidden = false }
    }

    func closeAll() {
        panels.forEach { $0.orderOut(nil) }
        guides.forEach { $0.orderOut(nil) }
        panels = []
        guides = []
        isHidden = false
    }

    // MARK: ガイド線

    /// カーソルのある画面に、カーソルの位置を通る縦線／横線を引く
    func addGuide(_ orientation: GuideOrientation) {
        let mouse = NSEvent.mouseLocation
        let screen = DisplayLocator.screen(containing: mouse)
        addGuide(orientation, at: orientation == .vertical ? mouse.x : mouse.y, on: screen)
    }

    private func addGuide(_ orientation: GuideOrientation, at position: CGFloat, on screen: NSScreen) {
        showAll()
        let guide = GuidePanel(orientation: orientation, position: position, screen: screen, owner: self)
        guides.append(guide)
        guide.orderFrontRegardless()
        guide.makeKey()
        guidesDidChange()
    }

    func duplicate(_ guide: GuidePanel) {
        // 横線の位置は上が大きいので、どちらも「右／下」へ 10pt ずらす
        let offset: CGFloat = guide.orientation == .vertical ? 10 : -10
        guard let screen = NSScreen.screens.first(where: { $0.frame == guide.screenFrame }) else { return }
        addGuide(guide.orientation, at: guide.position + offset, on: screen)
    }

    func remove(_ guide: GuidePanel) {
        guide.orderOut(nil)
        guides.removeAll { $0 === guide }
        if isEmpty { isHidden = false }
        guidesDidChange()
    }

    /// 位置の表示を更新する。同じ画面・同じ向きの線があれば、いちばん近い線との距離も出す。
    func guidesDidChange() {
        let display = RulerDisplay.current()
        for guide in guides {
            let siblings = guides.filter { $0 !== guide && $0.orientation == guide.orientation && $0.screenFrame == guide.screenFrame }
            let gap = ScreenGuideGeometry.nearestGap(to: guide.position, among: siblings.map(\.position))
            let distance = ScreenGuideGeometry.distanceFromEdge(guide.position, orientation: guide.orientation, screen: guide.screenFrame)
            guide.showLabel(ScreenGuideGeometry.label(orientation: guide.orientation, distance: distance, gap: gap, display: display))
        }
    }

    // MARK: 表示

    /// 1 本も無ければ新しく出す。あれば全部（ルーラーとガイド線）を隠す／出す。
    func toggleVisibility() {
        guard !isEmpty else { add(); return }
        if isHidden { showAll() } else { hideAll() }
    }

    private func showAll() {
        guard isHidden else { return }
        isHidden = false
        panels.forEach { $0.orderFrontRegardless() }
        guides.forEach { $0.orderFrontRegardless() }
    }

    private func hideAll() {
        isHidden = true
        panels.forEach { $0.orderOut(nil) }
        guides.forEach { $0.orderOut(nil) }
    }
}

// MARK: - 計算

enum ScreenRulerGeometry {
    static let defaultSize = CGSize(width: 320, height: 200)
    static let minSize = CGSize(width: 24, height: 24)
    /// 端から何ポイントまでを「つまんでサイズ変更」とみなすか
    static let edgeGrip: CGFloat = 8

    struct Edges: OptionSet, Hashable {
        let rawValue: Int
        static let left = Edges(rawValue: 1)
        static let right = Edges(rawValue: 2)
        static let bottom = Edges(rawValue: 4)
        static let top = Edges(rawValue: 8)
    }

    /// ビュー内の位置（左下原点）が、どの辺をつまんでいるか
    static func edges(at point: CGPoint, in bounds: CGRect) -> Edges {
        var edges: Edges = []
        if point.x <= bounds.minX + edgeGrip { edges.insert(.left) }
        if point.x >= bounds.maxX - edgeGrip { edges.insert(.right) }
        if point.y <= bounds.minY + edgeGrip { edges.insert(.bottom) }
        if point.y >= bounds.maxY - edgeGrip { edges.insert(.top) }
        return edges
    }

    /// つまんだ辺を delta（スクリーン座標、上が +）だけ動かす。反対側の辺は動かさない。
    static func resized(_ frame: CGRect, edges: Edges, by delta: CGSize) -> CGRect {
        var minX = frame.minX, maxX = frame.maxX, minY = frame.minY, maxY = frame.maxY
        if edges.contains(.left) { minX = min(minX + delta.width, maxX - minSize.width) }
        if edges.contains(.right) { maxX = max(maxX + delta.width, minX + minSize.width) }
        if edges.contains(.bottom) { minY = min(minY + delta.height, maxY - minSize.height) }
        if edges.contains(.top) { maxY = max(maxY + delta.height, minY + minSize.height) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// 画面からはみ出さないように寄せる（大きすぎるときは画面に収まる大きさにする）
    static func constrained(_ frame: CGRect, to visible: CGRect) -> CGRect {
        let width = min(frame.width, visible.width), height = min(frame.height, visible.height)
        let x = min(max(frame.minX, visible.minX), visible.maxX - width)
        let y = min(max(frame.minY, visible.minY), visible.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// 目盛りの長さ。10 ごとに短く、50 で中、100 で長く。
    static func tickLength(at value: Int) -> CGFloat {
        if value % 100 == 0 { return 12 }
        if value % 50 == 0 { return 8 }
        return 4
    }

    static func sizeLabel(_ size: CGSize, display: RulerDisplay) -> String {
        "\(display.label(pixels: size.width)) × \(display.label(pixels: size.height))"
    }
}

// MARK: - ウィンドウ

final class RulerPanel: NSPanel {
    private weak var owner: ScreenRulers?

    init(frame: CGRect, owner: ScreenRulers) {
        self.owner = owner
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = RulerView(frame: CGRect(origin: .zero, size: frame.size))
        identifier = MeasureOverlay.identifier
    }

    override var canBecomeKey: Bool { true }

    private var rulerView: RulerView? { contentView as? RulerView }

    func duplicate() { owner?.duplicate(self) }
    func closeRuler() { owner?.close(self) }
    func hideAllRulers() { owner?.toggleVisibility() }
    func addGuide(_ orientation: GuideOrientation) { owner?.addGuide(orientation) }

    func nudge(dx: CGFloat, dy: CGFloat) {
        setFrameOrigin(CGPoint(x: frame.minX + dx, y: frame.minY + dy))
    }

    func grow(dx: CGFloat, dy: CGFloat) {
        // ⌥ + 矢印：右辺と下辺を動かす（左上を基準にする）
        var edges: ScreenRulerGeometry.Edges = []
        if dx != 0 { edges.insert(.right) }
        if dy != 0 { edges.insert(.bottom) }
        setFrame(ScreenRulerGeometry.resized(frame, edges: edges, by: CGSize(width: dx, height: -dy)), display: true)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        rulerView?.needsDisplay = true
    }
}

private final class RulerView: NSView {
    private enum Drag {
        case move(startFrame: CGRect, startMouse: CGPoint)
        case resize(edges: ScreenRulerGeometry.Edges, startFrame: CGRect, startMouse: CGPoint)
    }

    private var drag: Drag?
    private var isHovering = false
    private var showCenterGuides = false

    private var panel: RulerPanel? { window as? RulerPanel }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var isOpaque: Bool { false }

    // MARK: 描画

    private let tint = NSColor(srgbRed: 0.06, green: 0.62, blue: 0.47, alpha: 1)

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds
        tint.withAlphaComponent(0.16).setFill()
        bounds.fill()

        // 明るい背景でも暗い背景でも見えるよう、濃い線と白い線を重ねる
        NSColor.black.withAlphaComponent(0.35).setStroke()
        let outer = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)); outer.lineWidth = 1; outer.stroke()
        tint.setStroke()
        let inner = NSBezierPath(rect: bounds.insetBy(dx: 1.5, dy: 1.5)); inner.lineWidth = 1; inner.stroke()

        drawTicks(in: bounds)
        if showCenterGuides { drawCenterGuides(in: bounds) }
        drawSizeLabel(in: bounds)
        if isHovering && !MeasureOverlay.isCapturing { buttons().forEach { drawButton($0) } }
    }

    private func drawTicks(in bounds: CGRect) {
        let path = NSBezierPath()
        path.lineWidth = 1
        // 上辺：左から、左辺：上から数える（画面を見る向きと合わせる）
        for value in stride(from: 10, to: Int(bounds.width), by: 10) {
            let x = CGFloat(value) + 0.5
            path.move(to: CGPoint(x: x, y: bounds.maxY))
            path.line(to: CGPoint(x: x, y: bounds.maxY - ScreenRulerGeometry.tickLength(at: value)))
        }
        for value in stride(from: 10, to: Int(bounds.height), by: 10) {
            let y = bounds.maxY - CGFloat(value) - 0.5
            path.move(to: CGPoint(x: bounds.minX, y: y))
            path.line(to: CGPoint(x: bounds.minX + ScreenRulerGeometry.tickLength(at: value), y: y))
        }
        tint.withAlphaComponent(0.95).setStroke()
        path.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium),
            .foregroundColor: tint.shadow(withLevel: 0.35) ?? tint,
        ]
        for value in stride(from: 100, to: Int(bounds.width) - 20, by: 100) {
            ("\(value)" as NSString).draw(at: CGPoint(x: CGFloat(value) + 2, y: bounds.maxY - 13), withAttributes: attributes)
        }
        for value in stride(from: 100, to: Int(bounds.height) - 10, by: 100) {
            ("\(value)" as NSString).draw(at: CGPoint(x: 14, y: bounds.maxY - CGFloat(value) - 5), withAttributes: attributes)
        }
    }

    private func drawCenterGuides(in bounds: CGRect) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: bounds.midX, y: bounds.minY)); path.line(to: CGPoint(x: bounds.midX, y: bounds.maxY))
        path.move(to: CGPoint(x: bounds.minX, y: bounds.midY)); path.line(to: CGPoint(x: bounds.maxX, y: bounds.midY))
        path.lineWidth = 1
        path.setLineDash([6, 4], count: 2, phase: 0)
        NSColor(srgbRed: 1, green: 0.16, blue: 0.78, alpha: 0.85).setStroke()
        path.stroke()
    }

    private func drawSizeLabel(in bounds: CGRect) {
        let text = ScreenRulerGeometry.sizeLabel(bounds.size, display: .current()) as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        guard bounds.width > size.width + 12, bounds.height > size.height + 8 else { return }
        let origin = CGPoint(x: bounds.midX - size.width / 2, y: bounds.minY + 10)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: CGRect(origin: origin, size: size).insetBy(dx: -7, dy: -3), xRadius: 5, yRadius: 5).fill()
        text.draw(at: origin, withAttributes: attributes)
    }

    // MARK: ボタン（ホバー中だけ出す）

    private struct Button {
        let rect: CGRect
        let symbol: String
        let help: String
        let action: (RulerView) -> Void
    }

    private func buttons() -> [Button] {
        guard bounds.width >= 96, bounds.height >= 44 else { return [] }
        let size: CGFloat = 20, gap: CGFloat = 4
        let y = bounds.maxY - size - 16
        var x = bounds.maxX - size - 8
        func next() -> CGRect { defer { x -= size + gap }; return CGRect(x: x, y: y, width: size, height: size) }
        return [
            Button(rect: next(), symbol: "xmark", help: String(localized: "閉じる")) { $0.panel?.closeRuler() },
            Button(rect: next(), symbol: "plus.square.on.square", help: String(localized: "複製（⌘D）")) { $0.panel?.duplicate() },
            Button(rect: next(), symbol: "plus", help: String(localized: "センターガイド（⌘;）")) { $0.toggleCenterGuides() },
        ]
    }

    private func drawButton(_ button: Button) {
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(ovalIn: button.rect).fill()
        let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
        guard let image = NSImage(systemSymbolName: button.symbol, accessibilityDescription: button.help)?
            .withSymbolConfiguration(config) else { return }
        let tinted = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            NSColor.white.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.draw(in: CGRect(x: button.rect.midX - image.size.width / 2, y: button.rect.midY - image.size.height / 2,
                               width: image.size.width, height: image.size.height))
    }

    private func toggleCenterGuides() {
        showCenterGuides.toggle()
        needsDisplay = true
    }

    // MARK: マウス

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { isHovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovering = false; needsDisplay = true; NSCursor.arrow.set() }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if buttons().contains(where: { $0.rect.contains(point) }) {
            NSCursor.pointingHand.set()
        } else {
            cursor(for: ScreenRulerGeometry.edges(at: point, in: bounds)).set()
        }
    }

    private func cursor(for edges: ScreenRulerGeometry.Edges) -> NSCursor {
        switch edges {
        case []: return .openHand
        case .left: return .frameResize(position: .left, directions: .all)
        case .right: return .frameResize(position: .right, directions: .all)
        case .top: return .frameResize(position: .top, directions: .all)
        case .bottom: return .frameResize(position: .bottom, directions: .all)
        case [.left, .top]: return .frameResize(position: .topLeft, directions: .all)
        case [.right, .top]: return .frameResize(position: .topRight, directions: .all)
        case [.left, .bottom]: return .frameResize(position: .bottomLeft, directions: .all)
        default: return .frameResize(position: .bottomRight, directions: .all)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        if let button = buttons().first(where: { $0.rect.contains(point) }) {
            button.action(self)
            return
        }
        guard let frame = window?.frame else { return }
        let edges = ScreenRulerGeometry.edges(at: point, in: bounds)
        let mouse = NSEvent.mouseLocation
        if edges.isEmpty {
            drag = .move(startFrame: frame, startMouse: mouse)
            NSCursor.closedHand.set()
        } else {
            drag = .resize(edges: edges, startFrame: frame, startMouse: mouse)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let drag else { return }
        let mouse = NSEvent.mouseLocation
        switch drag {
        case .move(let startFrame, let startMouse):
            window.setFrameOrigin(CGPoint(x: (startFrame.minX + mouse.x - startMouse.x).rounded(),
                                          y: (startFrame.minY + mouse.y - startMouse.y).rounded()))
        case .resize(let edges, let startFrame, let startMouse):
            let delta = CGSize(width: (mouse.x - startMouse.x).rounded(), height: (mouse.y - startMouse.y).rounded())
            window.setFrame(ScreenRulerGeometry.resized(startFrame, edges: edges, by: delta), display: true)
        }
    }

    override func mouseUp(with event: NSEvent) {
        drag = nil
        mouseMoved(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "複製"), action: #selector(duplicateRuler), keyEquivalent: "").target = self
        let guides = menu.addItem(withTitle: String(localized: "センターガイド"), action: #selector(toggleGuides), keyEquivalent: "")
        guides.target = self
        guides.state = showCenterGuides ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "縦のガイド線を追加"), action: #selector(addVerticalGuide), keyEquivalent: "").target = self
        menu.addItem(withTitle: String(localized: "横のガイド線を追加"), action: #selector(addHorizontalGuide), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "すべてのルーラーを隠す"), action: #selector(hideRulers), keyEquivalent: "").target = self
        menu.addItem(withTitle: String(localized: "閉じる"), action: #selector(closeRuler), keyEquivalent: "").target = self
        return menu
    }

    @objc private func addVerticalGuide() { panel?.addGuide(.vertical) }
    @objc private func addHorizontalGuide() { panel?.addGuide(.horizontal) }

    @objc private func duplicateRuler() { panel?.duplicate() }
    @objc private func toggleGuides() { toggleCenterGuides() }
    @objc private func hideRulers() { panel?.hideAllRulers() }
    @objc private func closeRuler() { panel?.closeRuler() }

    // MARK: キーボード

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // メインメニューの ⌘D・⌘; より先に受ける（ルーラーがキーのときだけ呼ばれる）
        guard window?.isKeyWindow == true else { return false }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard flags == .command else { return false }
        switch event.charactersIgnoringModifiers {
        case "d": panel?.duplicate(); return true
        case ";": toggleCenterGuides(); return true
        case "w": panel?.closeRuler(); return true
        default: return false
        }
    }

    override func keyDown(with event: NSEvent) {
        let fast = event.modifierFlags.contains(.shift)
        let step: CGFloat = fast ? 10 : 1
        let resize = event.modifierFlags.contains(.option)
        let delta: (CGFloat, CGFloat)? = switch event.keyCode {
        case 123: (-step, 0)
        case 124: (step, 0)
        case 125: (0, -step)
        case 126: (0, step)
        default: nil
        }
        if let (dx, dy) = delta {
            if resize {
                // ⌥→ で幅を広げ、⌥↓ で高さを伸ばす
                panel?.grow(dx: dx, dy: -dy)
            } else {
                panel?.nudge(dx: dx, dy: dy)
            }
            return
        }
        switch event.keyCode {
        case 53, 51, 117: panel?.closeRuler() // Esc / ⌫ / ⌦
        default: super.keyDown(with: event)
        }
    }
}
