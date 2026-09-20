import AppKit
import ScreenCaptureKit

enum CaptureMode: String, CaseIterable, Identifiable {
    case interactive
    case fullScreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .interactive: String(localized: "範囲を選んで撮影")
        case .fullScreen: String(localized: "画面全体を撮影")
        }
    }

    var systemImage: String {
        switch self {
        case .interactive: "rectangle.dashed"
        case .fullScreen: "macwindow"
        }
    }
}

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            String(localized: "画面収録が許可されていません。「システム設定 > プライバシーとセキュリティ > 画面収録」で Revvy をオンにして、アプリを起動し直してください。")
        case .noDisplay:
            String(localized: "撮影対象のディスプレイが見つかりません。")
        }
    }

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
}

/// ScreenCaptureKit で画面を撮る。自分のウィンドウは除外するので隠す必要がない。
/// ただし画面ルーラーとガイド線（MeasureOverlay）は、測った状態を残せるよう写す。
@MainActor
enum ScreenCaptureService {
    /// キャンセル（Esc）された場合は nil
    static func capture(_ mode: CaptureMode) async throws -> CGImage? {
        guard hasPermission() else { throw ScreenCaptureError.permissionDenied }
        // 呼び出した瞬間のカーソル位置で決める（ショートカットでもメニューバーからでも同じ）
        let cursorScreen = DisplayLocator.screen(containing: NSEvent.mouseLocation)
        switch mode {
        case .fullScreen:
            guard let shot = try await captureDisplays([cursorScreen]).first else { throw ScreenCaptureError.noDisplay }
            return shot.image
        case .interactive:
            // ⌘⇧4 と同じく全ディスプレイに重ね、ドラッグを始めた画面で切り出す。
            // ウィンドウ内のボタンから呼んでも、別のディスプレイを選べるようにするため。
            let shots = try await captureDisplays(NSScreen.screens)
            return await RegionSelector.select(from: shots, keyScreen: cursorScreen)
        }
    }

    /// 未許可ならシステムのダイアログを出す。許可直後でもアプリ再起動まで false のことがある
    static func hasPermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return CGRequestScreenCaptureAccess()
    }

    private static func captureDisplays(_ screens: [NSScreen]) async throws -> [DisplayShot] {
        // ホバー中だけ出るボタンなどを消してから撮る
        MeasureOverlay.beginCapture()
        defer { MeasureOverlay.endCapture() }
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw ScreenCaptureError.permissionDenied
        }
        let ownApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let overlayIDs = MeasureOverlay.visibleWindowNumbers
        let overlays = content.windows.filter { overlayIDs.contains($0.windowID) }
        var shots: [DisplayShot] = []
        for screen in screens {
            let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else { continue }
            let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: overlays)

            let config = SCStreamConfiguration()
            let scale = screen.backingScaleFactor
            config.width = Int(CGFloat(display.width) * scale)
            config.height = Int(CGFloat(display.height) * scale)
            config.captureResolution = .best
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            shots.append(DisplayShot(screen: screen, image: image))
        }
        guard !shots.isEmpty else { throw ScreenCaptureError.noDisplay }
        return shots
    }
}

struct DisplayShot {
    let screen: NSScreen
    let image: CGImage
}

// MARK: - ディスプレイの特定

/// マルチディスプレイで、カーソルがある画面を選ぶ。
enum DisplayLocator {
    @MainActor
    static func screen(containing point: CGPoint) -> NSScreen {
        let screens = NSScreen.screens
        guard let index = index(of: point, in: screens.map(\.frame)) else { return NSScreen.main ?? screens[0] }
        return screens[index]
    }

    /// `CGRect.contains` は右端・上端を含まないので、画面の一番上（メニューバーの縁）にカーソルがあると
    /// どの画面にも入らずメイン画面に落ちてしまう。端を含めて判定し、それでも外れたら一番近い画面にする。
    static func index(of point: CGPoint, in frames: [CGRect]) -> Int? {
        if let inside = frames.firstIndex(where: {
            point.x >= $0.minX && point.x <= $0.maxX && point.y >= $0.minY && point.y <= $0.maxY
        }) {
            return inside
        }
        return frames.indices.min { distance(point, frames[$0]) < distance(point, frames[$1]) }
    }

    private static func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }
}

// MARK: - 範囲選択オーバーレイ

/// 撮った画像を各ディスプレイいっぱいに表示し、その上でドラッグした範囲を切り出す
@MainActor
enum RegionSelector {
    private static var activeWindows: [SelectionWindow] = []
    private static var escapeMonitor: Any?

    static func select(from shots: [DisplayShot], keyScreen: NSScreen) async -> CGImage? {
        await withCheckedContinuation { continuation in
            var finished = false
            @MainActor func finish(_ image: CGImage?) {
                guard !finished else { return }
                finished = true
                activeWindows.forEach { $0.orderOut(nil) }
                activeWindows = []
                if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
                escapeMonitor = nil
                continuation.resume(returning: image)
            }
            for shot in shots {
                let window = SelectionWindow(
                    screen: shot.screen, image: shot.image,
                    onBegin: { view in
                        // 別の画面でドラッグし直したら、前の画面の選択は消す
                        for other in activeWindows where other.selectionView !== view {
                            other.selectionView.clearSelection()
                        }
                    },
                    onFinish: { rect in
                        finish(rect.flatMap { crop(shot.image, to: $0, screen: shot.screen) })
                    }
                )
                activeWindows.append(window)
            }
            for window in activeWindows where window.screenFrame != keyScreen.frame {
                window.orderFrontRegardless()
            }
            let keyWindow = activeWindows.first { $0.screenFrame == keyScreen.frame } ?? activeWindows.first
            keyWindow?.makeKeyAndOrderFront(nil)
            // どのビューがキーを受けていても Esc で必ず抜けられるようにする
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard event.keyCode == 53 else { return event }
                MainActor.assumeIsolated { finish(nil) }
                return nil
            }
        }
    }

    /// rect はスクリーン座標系のポイント（左上原点）
    private static func crop(_ image: CGImage, to rect: CGRect, screen: NSScreen) -> CGImage? {
        let scale = CGFloat(image.width) / screen.frame.width
        let pixelRect = CGRect(
            x: rect.minX * scale, y: rect.minY * scale,
            width: rect.width * scale, height: rect.height * scale
        ).integral
        return image.cropping(to: pixelRect)
    }
}

/// 他のアプリを使っている最中にショートカットで呼んでも、Revvy を前面にせずキー入力（Esc）を受けられるよう
/// アクティブにしないパネルにする。macOS 14 以降は他のアプリから強制的に前面へ出られないため。
private final class SelectionWindow: NSPanel {
    let screenFrame: CGRect
    let selectionView: SelectionView

    init(screen: NSScreen, image: CGImage, onBegin: @escaping (SelectionView) -> Void, onFinish: @escaping (CGRect?) -> Void) {
        screenFrame = screen.frame
        selectionView = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), image: image, onBegin: onBegin, onFinish: onFinish)
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = .screenSaver
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = true
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = selectionView
        initialFirstResponder = selectionView
        makeFirstResponder(selectionView)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        selectionView.cancel()
    }
}

private final class SelectionView: NSView {
    private let image: NSImage
    private let onBegin: (SelectionView) -> Void
    private let onFinish: (CGRect?) -> Void
    private var dragStart: CGPoint?
    private var selection: CGRect?

    init(frame: NSRect, image: CGImage, onBegin: @escaping (SelectionView) -> Void, onFinish: @escaping (CGRect?) -> Void) {
        self.image = NSImage(cgImage: image, size: frame.size)
        self.onBegin = onBegin
        self.onFinish = onFinish
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    /// キーになっていない画面でも、最初のクリックからドラッグを始められるようにする
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func clearSelection() {
        dragStart = nil
        selection = nil
        needsDisplay = true
    }

    override func mouseEntered(with event: NSEvent) {
        window?.makeKey()
        window?.makeFirstResponder(self)
        NSCursor.crosshair.set()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        // カーソルが入った画面をキーにして、Esc と十字カーソルがどの画面でも効くようにする
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .cursorUpdate], owner: self))
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSColor.black.withAlphaComponent(0.4).setFill()
        bounds.fill()

        if let selection {
            NSGraphicsContext.saveGraphicsState()
            selection.clip()
            image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()

            NSColor.white.setStroke()
            let outline = NSBezierPath(rect: selection.insetBy(dx: -0.5, dy: -0.5))
            outline.lineWidth = 1
            outline.stroke()

            let label = "\(Int(selection.width)) × \(Int(selection.height))" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white,
            ]
            let size = label.size(withAttributes: attributes)
            let origin = CGPoint(x: selection.minX, y: max(selection.minY - size.height - 8, 4))
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: CGRect(origin: origin, size: size).insetBy(dx: -6, dy: -3), xRadius: 4, yRadius: 4).fill()
            label.draw(at: origin, withAttributes: attributes)
        } else {
            let hint = String(localized: "ドラッグで範囲を選択　　Esc でキャンセル") as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15, weight: .medium),
                .foregroundColor: NSColor.white,
            ]
            let size = hint.size(withAttributes: attributes)
            let origin = CGPoint(x: (bounds.width - size.width) / 2, y: 60)
            NSColor.black.withAlphaComponent(0.7).setFill()
            NSBezierPath(roundedRect: CGRect(origin: origin, size: size).insetBy(dx: -14, dy: -8), xRadius: 8, yRadius: 8).fill()
            hint.draw(at: origin, withAttributes: attributes)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        onBegin(self)
        dragStart = convert(event.locationInWindow, from: nil)
        selection = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let current = convert(event.locationInWindow, from: nil)
        selection = CGRect(
            x: min(dragStart.x, current.x), y: min(dragStart.y, current.y),
            width: abs(current.x - dragStart.x), height: abs(current.y - dragStart.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragStart = nil }
        if let selection, selection.width >= 4, selection.height >= 4 {
            onFinish(selection)
        } else {
            // クリックだけ → 何も選ばずにやり直し
            self.selection = nil
            needsDisplay = true
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            cancel()
        }
    }

    func cancel() {
        onFinish(nil)
    }
}

// MARK: - 画像の読み書き

enum ImageCodec {
    static func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func load(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func fromPasteboard() -> CGImage? {
        let pasteboard = NSPasteboard.general
        if let data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            return load(data)
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], let url = urls.first {
            return load(url)
        }
        return nil
    }

    /// 最大幅 2000px・JPEG 0.8 に落としてアップロードサイズを抑える
    static func jpegData(_ image: CGImage, maxWidth: Int = 2000, quality: CGFloat = 0.8) -> Data? {
        let scaled = downscale(image, maxWidth: maxWidth)
        let rep = NSBitmapImageRep(cgImage: scaled)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    static func downscale(_ image: CGImage, maxWidth: Int) -> CGImage {
        guard image.width > maxWidth else { return image }
        let scale = CGFloat(maxWidth) / CGFloat(image.width)
        let size = CGSize(width: maxWidth, height: Int(CGFloat(image.height) * scale))
        guard let context = CGContext(
            data: nil, width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage() ?? image
    }
}
