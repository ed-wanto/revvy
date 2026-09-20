import AppKit
import CoreGraphics
import CoreText
import Foundation
import SwiftUI

enum AnnotationTool: String, CaseIterable, Identifiable, Codable {
    case select
    case ruler
    case rectangle
    case arrow
    case pen
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: String(localized: "選択・移動")
        case .ruler: String(localized: "ルーラー（距離を測る）")
        case .rectangle: String(localized: "枠")
        case .arrow: String(localized: "矢印")
        case .pen: String(localized: "ペン")
        case .text: String(localized: "テキスト")
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .ruler: "ruler"
        case .rectangle: "rectangle"
        case .arrow: "arrow.up.right"
        case .pen: "pencil.tip"
        case .text: "textformat"
        }
    }
}

enum AnnotationColor: String, CaseIterable, Identifiable, Codable {
    case red, yellow, blue, green

    var id: String { rawValue }

    var title: String {
        switch self {
        case .red: String(localized: "赤")
        case .yellow: String(localized: "黄")
        case .blue: String(localized: "青")
        case .green: String(localized: "緑")
        }
    }

    var color: Color {
        switch self {
        case .red: Color(red: 0.93, green: 0.17, blue: 0.17)
        case .yellow: Color(red: 0.98, green: 0.75, blue: 0.10)
        case .blue: Color(red: 0.15, green: 0.47, blue: 0.96)
        case .green: Color(red: 0.16, green: 0.70, blue: 0.36)
        }
    }

    /// テキスト注釈の背景にこの色を敷いたときの文字色。黄色だけは白だと読めない。
    var textOnColor: Color { self == .yellow ? .black : .white }
    var textOnCGColor: CGColor { self == .yellow ? CGColor(gray: 0, alpha: 1) : CGColor(gray: 1, alpha: 1) }

    var cgColor: CGColor {
        switch self {
        case .red: CGColor(srgbRed: 0.93, green: 0.17, blue: 0.17, alpha: 1)
        case .yellow: CGColor(srgbRed: 0.98, green: 0.75, blue: 0.10, alpha: 1)
        case .blue: CGColor(srgbRed: 0.15, green: 0.47, blue: 0.96, alpha: 1)
        case .green: CGColor(srgbRed: 0.16, green: 0.70, blue: 0.36, alpha: 1)
        }
    }
}

/// 座標は 0...1 に正規化して持つ。表示用 Canvas と書き出し用 CGContext で同じ形を描くため。
struct Annotation: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let tool: AnnotationTool
    let color: AnnotationColor
    var points: [CGPoint]
    /// テキスト注釈の本文。保存済みの古い注釈には無いので Optional にしておく。
    var text: String?
    /// テキストの大きさ（画像の幅に対する割合）。表示と書き出しで同じ見た目にするため画像基準で持つ。
    var fontSize: CGFloat?

    init(id: UUID = UUID(), tool: AnnotationTool, color: AnnotationColor, points: [CGPoint] = [],
         text: String? = nil, fontSize: CGFloat? = nil) {
        self.id = id
        self.tool = tool
        self.color = color
        self.points = points
        self.text = text
        self.fontSize = fontSize
    }

    var isMeaningful: Bool {
        guard let first = points.first, let last = points.last else { return false }
        if tool == .pen { return points.count > 1 }
        if tool == .text { return !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return abs(first.x - last.x) > 0.002 || abs(first.y - last.y) > 0.002
    }
}

/// 正規化座標の注釈を、指定ピクセルサイズの Path に変換する
enum AnnotationGeometry {
    struct Drawable {
        let stroke: Path
        let fill: Path?
        let lineWidth: CGFloat
    }

    static func lineWidth(for size: CGSize) -> CGFloat {
        max(3, size.width * 0.004)
    }

    static func drawable(_ annotation: Annotation, in size: CGSize) -> Drawable? {
        let pts = annotation.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        guard let first = pts.first, let last = pts.last else { return nil }
        let width = lineWidth(for: size)

        switch annotation.tool {
        case .select: return nil
        case .ruler:
            var path = Path()
            path.move(to: first); path.addLine(to: last)
            let angle = atan2(last.y - first.y, last.x - first.x)
            let tick = max(width * 2.5, 8)
            let offset = CGPoint(x: -sin(angle) * tick, y: cos(angle) * tick)
            for point in [first, last] {
                path.move(to: CGPoint(x: point.x - offset.x, y: point.y - offset.y))
                path.addLine(to: CGPoint(x: point.x + offset.x, y: point.y + offset.y))
            }
            return Drawable(stroke: path, fill: nil, lineWidth: max(2, width * 0.6))
        case .rectangle:
            let rect = CGRect(x: min(first.x, last.x), y: min(first.y, last.y),
                              width: abs(last.x - first.x), height: abs(last.y - first.y))
            return Drawable(stroke: Path(roundedRect: rect, cornerRadius: width), fill: nil, lineWidth: width)

        case .arrow:
            var line = Path()
            line.move(to: first)
            line.addLine(to: last)

            let angle = atan2(last.y - first.y, last.x - first.x)
            let headLength = max(width * 4, 14)
            let spread: CGFloat = .pi / 7
            var head = Path()
            head.move(to: last)
            head.addLine(to: CGPoint(x: last.x - headLength * cos(angle - spread),
                                     y: last.y - headLength * sin(angle - spread)))
            head.addLine(to: CGPoint(x: last.x - headLength * cos(angle + spread),
                                     y: last.y - headLength * sin(angle + spread)))
            head.closeSubpath()
            return Drawable(stroke: line, fill: head, lineWidth: width)

        case .pen:
            var path = Path()
            path.move(to: first)
            for point in pts.dropFirst() { path.addLine(to: point) }
            return Drawable(stroke: path, fill: nil, lineWidth: width)

        case .text:
            // 文字は別に描く。ここでは選択枠と当たり判定のために外形だけ返す。
            guard let layout = textLayout(annotation, in: size) else { return nil }
            return Drawable(stroke: Path(layout.box), fill: nil, lineWidth: 0)
        }
    }

    struct TextLayout {
        /// 背景の角丸矩形
        let box: CGRect
        /// 文字を置く左上
        let textOrigin: CGPoint
        let fontSize: CGFloat
        let string: String
    }

    /// 既定の文字の大きさ。小さい画像でも読めるよう下限を設け、画像幅に対する割合で返す。
    static func defaultTextSize(imageWidth: CGFloat) -> CGFloat {
        guard imageWidth > 0 else { return 0.02 }
        return max(22, imageWidth * 0.016) / imageWidth
    }

    static func textFont(size: CGFloat) -> NSFont {
        .systemFont(ofSize: size, weight: .bold)
    }

    /// size は描く先の大きさ（表示ならキャンバス、書き出しなら画像のピクセル）
    static func textLayout(_ annotation: Annotation, in size: CGSize) -> TextLayout? {
        guard annotation.tool == .text, let origin = annotation.points.first else { return nil }
        let fontSize = (annotation.fontSize ?? defaultTextSize(imageWidth: size.width)) * size.width
        let string = annotation.text ?? ""
        // 空のときも 1 文字分の箱を出して、置いた場所が分かるようにする
        let measured = NSAttributedString(string: string.isEmpty ? " " : string, attributes: [.font: textFont(size: fontSize)])
            .boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
                          options: [.usesLineFragmentOrigin, .usesFontLeading])
        let padX = fontSize * 0.4, padY = fontSize * 0.2
        let topLeft = CGPoint(x: origin.x * size.width, y: origin.y * size.height)
        let box = CGRect(x: topLeft.x, y: topLeft.y,
                         width: ceil(measured.width) + padX * 2, height: ceil(measured.height) + padY * 2)
        return TextLayout(box: box, textOrigin: CGPoint(x: topLeft.x + padX, y: topLeft.y + padY),
                          fontSize: fontSize, string: string)
    }
}

/// 注釈を画像に焼き込む
enum AnnotationRenderer {
    static func render(_ annotations: [Annotation], onto image: CGImage) -> CGImage {
        guard !annotations.isEmpty else { return image }
        let size = CGSize(width: image.width, height: image.height)
        guard let context = CGContext(
            data: nil, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.draw(image, in: CGRect(origin: .zero, size: size))
        // Path は左上原点で作っているので、ビットマップ座標（左下原点）に合わせて反転する
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for annotation in annotations {
            if let layout = AnnotationGeometry.textLayout(annotation, in: size) {
                drawText(layout, color: annotation.color, in: context)
                continue
            }
            guard let drawable = AnnotationGeometry.drawable(annotation, in: size) else { continue }
            context.setStrokeColor(annotation.color.cgColor)
            context.setFillColor(annotation.color.cgColor)
            context.setLineWidth(drawable.lineWidth)
            context.addPath(drawable.stroke.cgPath)
            context.strokePath()
            if let fill = drawable.fill {
                context.addPath(fill.cgPath)
                context.fillPath()
            }
            if let label = AnnotationGeometry.rulerLabel(annotation, imageSize: size, displaySize: size) {
                let font = CTFontCreateWithName("Helvetica-Bold" as CFString, label.fontSize, nil)
                let text = NSAttributedString(string: label.text, attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)
                ])
                let line = CTLineCreateWithAttributedString(text)
                let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
                let rect = CGRect(x: label.center.x - bounds.width / 2 - 8, y: label.center.y - label.fontSize / 2 - 5, width: bounds.width + 16, height: label.fontSize + 10)
                context.setFillColor(CGColor(gray: 0.12, alpha: 0.95))
                context.addPath(CGPath(roundedRect: rect, cornerWidth: 5, cornerHeight: 5, transform: nil)); context.fillPath()
                context.saveGState()
                context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
                context.textPosition = CGPoint(x: label.center.x - bounds.width / 2, y: label.center.y + bounds.height / 2)
                CTLineDraw(line, context)
                context.restoreGState()
            }
        }
        return context.makeImage() ?? image
    }

    private static func drawText(_ layout: AnnotationGeometry.TextLayout, color: AnnotationColor, in context: CGContext) {
        context.setFillColor(color.cgColor)
        context.addPath(CGPath(roundedRect: layout.box, cornerWidth: layout.fontSize * 0.25, cornerHeight: layout.fontSize * 0.25, transform: nil))
        context.fillPath()
        // コンテキストは左上原点に反転済みなので、flipped の NSGraphicsContext で文字を正立させる
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        let string = NSAttributedString(string: layout.string, attributes: [
            .font: AnnotationGeometry.textFont(size: layout.fontSize),
            .foregroundColor: NSColor(cgColor: color.textOnCGColor) ?? .white,
        ])
        string.draw(with: CGRect(origin: layout.textOrigin, size: CGSize(width: layout.box.width, height: layout.box.height)),
                    options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
    }
}


extension AnnotationGeometry {
    struct RulerLabel {
        let text: String
        let center: CGPoint
        let fontSize: CGFloat
    }

    static func rulerLabel(_ annotation: Annotation, imageSize: CGSize, displaySize: CGSize,
                           display: RulerDisplay = .current()) -> RulerLabel? {
        guard annotation.tool == .ruler, let first = annotation.points.first, let last = annotation.points.last else { return nil }
        let distance = hypot((last.x - first.x) * imageSize.width, (last.y - first.y) * imageSize.height)
        let fontSize = max(18, imageSize.width * 0.014) * displaySize.width / imageSize.width
        return RulerLabel(
            text: display.label(pixels: distance),
            center: CGPoint(x: (first.x + last.x) / 2 * displaySize.width, y: (first.y + last.y) / 2 * displaySize.height),
            fontSize: fontSize
        )
    }

    static func hitTest(_ annotation: Annotation, point: CGPoint, size: CGSize, tolerance: CGFloat = 8) -> Bool {
        guard let drawable = drawable(annotation, in: size) else { return false }
        let stroke = drawable.stroke.cgPath.copy(strokingWithWidth: max(tolerance * 2, drawable.lineWidth), lineCap: .round, lineJoin: .round, miterLimit: 10)
        if stroke.contains(point) || drawable.fill?.contains(point) == true { return true }
        if annotation.tool == .rectangle || annotation.tool == .text { return drawable.stroke.boundingRect.insetBy(dx: -tolerance / 2, dy: -tolerance / 2).contains(point) }
        if annotation.tool == .ruler, let first = annotation.points.first, let last = annotation.points.last {
            let center = CGPoint(x: (first.x + last.x) / 2 * size.width, y: (first.y + last.y) / 2 * size.height)
            return CGRect(x: center.x - 40, y: center.y - 15, width: 80, height: 30).contains(point)
        }
        return false
    }

    static func moved(_ annotation: Annotation, by delta: CGSize) -> Annotation {
        guard !annotation.points.isEmpty else { return annotation }
        let minX = annotation.points.map(\.x).min()!, maxX = annotation.points.map(\.x).max()!
        let minY = annotation.points.map(\.y).min()!, maxY = annotation.points.map(\.y).max()!
        let dx = min(max(delta.width, -minX), 1 - maxX)
        let dy = min(max(delta.height, -minY), 1 - maxY)
        var result = annotation
        result.points = annotation.points.map { CGPoint(x: $0.x + dx, y: $0.y + dy) }
        return result
    }
}

/// ルーラーの表示単位。Web 開発では px と em を行き来するので、両方出せるようにする。
enum RulerUnit: String, CaseIterable, Identifiable, Sendable {
    case pixels
    case em
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pixels: String(localized: "px のみ")
        case .em: String(localized: "em のみ")
        case .both: String(localized: "px と em")
        }
    }
}

/// ルーラーのラベルをどう書くか。設定画面の値を読むが、テストでは直接渡せるようにしておく。
struct RulerDisplay: Equatable, Sendable {
    var unit: RulerUnit = .pixels
    var rootFontSize: CGFloat = 16

    /// 既定は px のみ。これまでの表示を変えない。
    static func current(_ defaults: UserDefaults = .standard) -> RulerDisplay {
        let unit = RulerUnit(rawValue: defaults.string(forKey: SettingsKeys.rulerUnit) ?? "") ?? .pixels
        let size = defaults.double(forKey: SettingsKeys.rootFontSize)
        return RulerDisplay(unit: unit, rootFontSize: size > 0 ? size : 16)
    }

    /// 元画像のピクセル数をラベルの文字列にする。
    func label(pixels: CGFloat) -> String {
        let px = "\(Int(pixels.rounded())) px"
        guard rootFontSize > 0 else { return px }
        let em = Double((pixels / rootFontSize * 100).rounded() / 100)
        let emText = em.formatted(.number.precision(.fractionLength(0...2))) + " em"
        switch unit {
        case .pixels: return px
        case .em: return emText
        case .both: return "\(px) · \(emText)"
        }
    }
}
