import AppKit

/// 画面の端から端まで引く縦線・横線（デザインツールのガイド相当）。離れた要素の位置合わせに使う。
/// 位置はディスプレイの左端／上端からのポイント数（CSS px と同じ尺度）。
enum GuideOrientation: Sendable {
    case vertical
    case horizontal
}

/// 画面ルーラー・ガイド線・位置表示のウィンドウ。スクリーンショットには Revvy のウィンドウのうちこれだけを写す。
@MainActor
enum MeasureOverlay {
    static let identifier = NSUserInterfaceItemIdentifier("RevvyMeasureOverlay")
    /// 撮影の瞬間は、ホバー時だけ出るボタンや当たり判定の帯を描かない
    private(set) static var isCapturing = false

    static var visibleWindowNumbers: Set<CGWindowID> {
        Set(NSApp.windows.filter { $0.identifier == identifier && $0.isVisible }.map { CGWindowID($0.windowNumber) })
    }

    static func beginCapture() {
        isCapturing = true
        redraw()
    }

    static func endCapture() {
        isCapturing = false
        redraw()
    }

    private static func redraw() {
        for window in NSApp.windows where window.identifier == identifier {
            window.contentView?.display()
        }
    }
}

// MARK: - 計算

enum ScreenGuideGeometry {
    /// つかめる幅。線そのものは 1pt で、その両側を当たり判定にする。
    static let thickness: CGFloat = 9
    static let lineOffset: CGFloat = 4

    /// 線の位置（スクリーン座標）を、ディスプレイの左端・上端からの距離にする
    static func distanceFromEdge(_ position: CGFloat, orientation: GuideOrientation, screen: CGRect) -> CGFloat {
        switch orientation {
        case .vertical: position - screen.minX
        case .horizontal: screen.maxY - position
        }
    }

    /// 同じ向きの線のうち、いちばん近いものとの距離。ほかに無ければ nil。
    static func nearestGap(to position: CGFloat, among others: [CGFloat]) -> CGFloat? {
        others.map { abs($0 - position) }.filter { $0 > 0 }.min()
    }

    /// 線がディスプレイの外へ出ないようにする
    static func clamped(_ position: CGFloat, orientation: GuideOrientation, screen: CGRect) -> CGFloat {
        switch orientation {
        case .vertical: min(max(position, screen.minX), screen.maxX - 1)
        case .horizontal: min(max(position, screen.minY + 1), screen.maxY)
        }
    }

    /// 線の位置から、つかめる幅を含んだウィンドウの枠を作る
    static func frame(for position: CGFloat, orientation: GuideOrientation, screen: CGRect) -> CGRect {
        switch orientation {
        case .vertical:
            CGRect(x: position - lineOffset, y: screen.minY, width: thickness, height: screen.height)
        case .horizontal:
            // 横線は「上端からの距離」で数えるので、線の上辺を position に合わせる
            CGRect(x: screen.minX, y: position - thickness + lineOffset, width: screen.width, height: thickness)
        }
    }

    /// 位置表示の置き場所。縦線は画面上端の少し下で線の右、横線は画面左端の少し右で線の上。
    /// 画面の端で収まらないときは線の反対側に回す。
    static func labelOrigin(for position: CGFloat, orientation: GuideOrientation, labelSize: CGSize, screen: CGRect) -> CGPoint {
        let gap: CGFloat = 6
        switch orientation {
        case .vertical:
            let right = position + gap
            let x = right + labelSize.width <= screen.maxX ? right : position - gap - labelSize.width
            return CGPoint(x: x, y: screen.maxY - labelSize.height - 40)
        case .horizontal:
            let above = position + gap
            let y = above + labelSize.height <= screen.maxY ? above : position - gap - labelSize.height
            return CGPoint(x: screen.minX + 12, y: y)
        }
    }

    static func label(orientation: GuideOrientation, distance: CGFloat, gap: CGFloat?, display: RulerDisplay) -> String {
        let axis = orientation == .vertical ? "X" : "Y"
        let position = "\(axis) \(display.label(pixels: distance))"
        guard let gap else { return position }
        let arrow = orientation == .vertical ? "↔" : "↕"
        return "\(position)  \(arrow) \(display.label(pixels: gap))"
    }
}

// MARK: - ウィンドウ

final class GuidePanel: NSPanel {
    let orientation: GuideOrientation
    let screenFrame: CGRect
    private weak var owner: ScreenRulers?
    private let labelPanel = GuideLabelPanel()

    /// 線の位置（スクリーン座標）。縦線は x、横線は y。
    var position: CGFloat {
        switch orientation {
        case .vertical: frame.minX + ScreenGuideGeometry.lineOffset
        case .horizontal: frame.maxY - ScreenGuideGeometry.lineOffset
        }
    }

    init(orientation: GuideOrientation, position: CGFloat, screen: NSScreen, owner: ScreenRulers) {
        self.orientation = orientation
        self.screenFrame = screen.frame
        self.owner = owner
        let clamped = ScreenGuideGeometry.clamped(position.rounded(), orientation: orientation, screen: screen.frame)
        let frame = ScreenGuideGeometry.frame(for: clamped, orientation: orientation, screen: screen.frame)
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        contentView = GuideView(frame: CGRect(origin: .zero, size: frame.size), orientation: orientation)
        identifier = MeasureOverlay.identifier
        addChildWindow(labelPanel, ordered: .above)
    }

    override var canBecomeKey: Bool { true }

    func move(to newPosition: CGFloat) {
        let clamped = ScreenGuideGeometry.clamped(newPosition.rounded(), orientation: orientation, screen: screenFrame)
        setFrame(ScreenGuideGeometry.frame(for: clamped, orientation: orientation, screen: screenFrame), display: true)
        owner?.guidesDidChange()
    }

    func nudge(by delta: CGFloat) { move(to: position + delta) }
    func duplicate() { owner?.duplicate(self) }
    func remove() { owner?.remove(self) }
    func hideAll() { owner?.toggleVisibility() }
    func clearAllRulers() { owner?.closeAll() }
    var showsGuideDistances: Bool { owner?.showGuideDistances ?? true }
    func toggleGuideDistances() { owner?.showGuideDistances.toggle() }

    func showLabel(_ text: String) {
        labelPanel.setText(text)
        // 縦線は画面上端の少し下、横線は画面左端の少し右に置く。線のすぐ隣に出して、線を隠さない。
        // 画面の端で収まらないときは、線の反対側に回す。
        labelPanel.setFrameOrigin(ScreenGuideGeometry.labelOrigin(
            for: position, orientation: orientation, labelSize: labelPanel.frame.size, screen: screenFrame
        ))
    }

    override func orderOut(_ sender: Any?) {
        labelPanel.orderOut(sender)
        super.orderOut(sender)
    }

    override func orderFrontRegardless() {
        super.orderFrontRegardless()
        labelPanel.orderFrontRegardless()
    }
}

/// 位置の表示。クリックは下へ通す。
private final class GuideLabelPanel: NSPanel {
    private let field = NSTextField(labelWithString: "")

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        identifier = MeasureOverlay.identifier
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        let background = NSView()
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        background.layer?.cornerRadius = 5
        field.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        field.textColor = .white
        field.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 7),
            field.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -7),
            field.topAnchor.constraint(equalTo: background.topAnchor, constant: 3),
            field.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -3),
        ])
        contentView = background
    }

    func setText(_ text: String) {
        field.stringValue = text
        guard let contentView else { return }
        contentView.layoutSubtreeIfNeeded()
        setContentSize(contentView.fittingSize)
    }
}

private final class GuideView: NSView {
    private let orientation: GuideOrientation
    private var dragStart: (position: CGFloat, mouse: CGPoint)?
    private var isHovering = false

    private var panel: GuidePanel? { window as? GuidePanel }

    init(frame: CGRect, orientation: GuideOrientation) {
        self.orientation = orientation
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var isOpaque: Bool { false }

    private let tint = NSColor(srgbRed: 1, green: 0.16, blue: 0.62, alpha: 1)

    override func draw(_ dirtyRect: NSRect) {
        // 当たり判定の帯はほぼ透明。ホバー中だけうっすら見せて、つかめる場所を示す。
        NSColor.black.withAlphaComponent(isHovering && !MeasureOverlay.isCapturing ? 0.08 : 0.001).setFill()
        bounds.fill()

        let line = NSBezierPath()
        switch orientation {
        case .vertical:
            let x = ScreenGuideGeometry.lineOffset + 0.5
            line.move(to: CGPoint(x: x, y: bounds.minY)); line.line(to: CGPoint(x: x, y: bounds.maxY))
        case .horizontal:
            let y = bounds.maxY - ScreenGuideGeometry.lineOffset - 0.5
            line.move(to: CGPoint(x: bounds.minX, y: y)); line.line(to: CGPoint(x: bounds.maxX, y: y))
        }
        // どんな背景でも見えるよう、半透明の黒で縁取ってから色を乗せる
        line.lineWidth = 3
        NSColor.black.withAlphaComponent(0.25).setStroke()
        line.stroke()
        line.lineWidth = 1
        tint.setStroke()
        line.stroke()
    }

    // MARK: マウス

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self))
    }

    override func cursorUpdate(with event: NSEvent) { resizeCursor.set() }
    override func mouseEntered(with event: NSEvent) { isHovering = true; needsDisplay = true; resizeCursor.set() }
    override func mouseExited(with event: NSEvent) { isHovering = false; needsDisplay = true; NSCursor.arrow.set() }

    private var resizeCursor: NSCursor {
        orientation == .vertical ? .resizeLeftRight : .resizeUpDown
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        guard let panel else { return }
        dragStart = (panel.position, NSEvent.mouseLocation)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let panel, let dragStart else { return }
        let mouse = NSEvent.mouseLocation
        let delta = orientation == .vertical ? mouse.x - dragStart.mouse.x : mouse.y - dragStart.mouse.y
        panel.move(to: dragStart.position + delta)
    }

    override func mouseUp(with event: NSEvent) {
        dragStart = nil
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: String(localized: "複製"), action: #selector(duplicateGuide), keyEquivalent: "").target = self
        let distances = menu.addItem(withTitle: String(localized: "ガイド線同士の距離を表示"), action: #selector(toggleGuideDistances), keyEquivalent: "")
        distances.target = self
        distances.state = panel?.showsGuideDistances == true ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "すべてのルーラーを隠す"), action: #selector(hideAll), keyEquivalent: "").target = self
        menu.addItem(withTitle: String(localized: "ルーラーとガイド線をすべて消す"), action: #selector(clearRulers), keyEquivalent: "").target = self
        menu.addItem(withTitle: String(localized: "削除"), action: #selector(removeGuide), keyEquivalent: "").target = self
        return menu
    }

    @objc private func duplicateGuide() { panel?.duplicate() }
    @objc private func toggleGuideDistances() { panel?.toggleGuideDistances() }
    @objc private func hideAll() { panel?.hideAll() }
    @objc private func clearRulers() { panel?.clearAllRulers() }
    @objc private func removeGuide() { panel?.remove() }

    // MARK: キーボード

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.isKeyWindow == true else { return false }
        guard event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command else { return false }
        switch event.charactersIgnoringModifiers {
        case "d": panel?.duplicate(); return true
        case "w": panel?.remove(); return true
        default: return false
        }
    }

    override func keyDown(with event: NSEvent) {
        let step: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        // 縦線は ← →、横線は ↑ ↓ で動かす。横線の位置は上端からの距離なので、↓ で値が増える。
        switch (orientation, event.keyCode) {
        case (.vertical, 123): panel?.nudge(by: -step)
        case (.vertical, 124): panel?.nudge(by: step)
        case (.horizontal, 125): panel?.nudge(by: -step)
        case (.horizontal, 126): panel?.nudge(by: step)
        case (_, 53), (_, 51), (_, 117): panel?.remove() // Esc / ⌫ / ⌦
        default: super.keyDown(with: event)
        }
    }
}
