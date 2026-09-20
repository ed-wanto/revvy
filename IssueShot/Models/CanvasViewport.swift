import CoreGraphics

/// Viewport coordinates are points; stored annotations remain normalized image coordinates.
enum CanvasViewport {
    static let minScale: CGFloat = 0.1
    static let maxScale: CGFloat = 4

    static func scale(image: CGSize, viewport: CGSize, requested: CGFloat?) -> CGFloat {
        guard image.width > 0, image.height > 0 else { return 1 }
        if let requested { return min(max(requested, minScale), maxScale) }
        return max(0.001, min(max(1, viewport.width - 56) / image.width, max(1, viewport.height - 56) / image.height, 1))
    }

    static func clampedOffset(_ offset: CGSize, image: CGSize, viewport: CGSize, scale: CGFloat) -> CGSize {
        // Allow movement even when the image fits, keeping a visible part within reach.
        func limit(_ imageLength: CGFloat, _ viewportLength: CGFloat) -> CGFloat {
            let displayed = max(0, imageLength * scale)
            let visible = min(64, displayed, max(0, viewportLength))
            return max(0, (displayed + viewportLength) / 2 - visible)
        }
        let x = limit(image.width, viewport.width)
        let y = limit(image.height, viewport.height)
        return CGSize(width: min(max(offset.width, -x), x), height: min(max(offset.height, -y), y))
    }

    static func offsetAfterZoom(_ offset: CGSize, from oldScale: CGFloat, to newScale: CGFloat, image: CGSize, viewport: CGSize) -> CGSize {
        guard oldScale > 0 else { return .zero }
        return clampedOffset(CGSize(width: offset.width * newScale / oldScale, height: offset.height * newScale / oldScale), image: image, viewport: viewport, scale: newScale)
    }
}
