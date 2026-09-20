import AppKit
import SwiftUI

/// Observe only events inside this canvas in this window. No accessibility permission or global monitor.
struct CanvasInputView: NSViewRepresentable {
    let onScroll: (CGSize) -> Bool
    let onMagnify: (CGFloat) -> Void
    let onDelete: () -> Bool
    /// 矢印キーの微調整。dx/dy は ±1、fast は ⇧ を押しているか。
    let onArrow: (CGFloat, CGFloat, Bool) -> Bool

    func makeNSView(context: Context) -> CanvasEventView { CanvasEventView() }
    func updateNSView(_ view: CanvasEventView, context: Context) {
        view.onScroll = onScroll
        view.onMagnify = onMagnify
        view.onDelete = onDelete
        view.onArrow = onArrow
    }
    static func dismantleNSView(_ view: CanvasEventView, coordinator: ()) { view.stopMonitoring() }
}

final class CanvasEventView: NSView {
    var onScroll: ((CGSize) -> Bool)?
    var onMagnify: ((CGFloat) -> Void)?
    var onDelete: (() -> Bool)?
    var onArrow: ((CGFloat, CGFloat, Bool) -> Bool)?
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify, .keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let window = self.window, event.window === window else { return event }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                // キャンバスを触ったら入力欄の編集を終える。残っていると ⌘Z・⌫・矢印キーが文字の方へ行ってしまう。
                // ただしキャンバス上のテキスト注釈の入力欄そのものをクリックしたときは除く。
                if self.bounds.contains(self.convert(event.locationInWindow, from: nil)), window.firstResponder is NSText {
                    var hit = window.contentView?.hitTest(event.locationInWindow)
                    while let view = hit, !(view is NSTextField || view is NSText) { hit = view.superview }
                    if hit == nil { window.makeFirstResponder(nil) }
                }
                return event
            }
            if event.type == .keyDown {
                // ⇧ は矢印キーの加速に使うので、ここでは弾かない。
                guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                      !(window.firstResponder is NSTextView),
                      !(window.firstResponder is NSTextField) else { return event }
                switch event.keyCode {
                case 51, 117: // delete / forward delete
                    return self.onDelete?() == true ? nil : event
                case 123, 124, 125, 126: // ← → ↓ ↑
                    let delta: (CGFloat, CGFloat) = switch event.keyCode {
                    case 123: (-1, 0)
                    case 124: (1, 0)
                    case 125: (0, 1)
                    default: (0, -1)
                    }
                    let fast = event.modifierFlags.contains(.shift)
                    return self.onArrow?(delta.0, delta.1, fast) == true ? nil : event
                default:
                    return event
                }
            }
            guard self.bounds.contains(self.convert(event.locationInWindow, from: nil)) else { return event }
            if event.type == .magnify {
                self.onMagnify?(event.magnification)
                return nil
            }
            let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 14
            let consumed = self.onScroll?(CGSize(width: event.scrollingDeltaX * multiplier, height: event.scrollingDeltaY * multiplier)) ?? false
            return consumed ? nil : event
        }
    }
    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
