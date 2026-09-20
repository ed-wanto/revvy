import CoreGraphics
import Testing
@testable import IssueShot

struct AnnotationTests {
    private func solidImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        let data = image.dataProvider!.data!
        let bytes = CFDataGetBytePtr(data)!
        let offset = y * image.bytesPerRow + x * 4
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2])
    }

    @Test func arrowProducesStrokeAndHead() {
        let arrow = Annotation(tool: .arrow, color: .red, points: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.9, y: 0.9)])
        let drawable = AnnotationGeometry.drawable(arrow, in: CGSize(width: 1000, height: 1000))
        #expect(drawable != nil)
        #expect(drawable?.fill != nil)
        #expect(drawable?.stroke.isEmpty == false)
    }

    @Test func degenerateAnnotationIsNotMeaningful() {
        let dot = Annotation(tool: .rectangle, color: .red, points: [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.5)])
        #expect(!dot.isMeaningful)
        let rect = Annotation(tool: .rectangle, color: .red, points: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.5, y: 0.5)])
        #expect(rect.isMeaningful)
    }

    @Test func renderPaintsRectangleOntoImageInTopLeftCoordinates() {
        let image = solidImage(width: 200, height: 100)
        // 上端付近に水平線を引く（正規化 y=0.1 → ピクセル y=10、左上原点）
        let line = Annotation(tool: .pen, color: .red, points: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.9, y: 0.1)])
        let rendered = AnnotationRenderer.render([line], onto: image)

        let top = pixel(rendered, x: 100, y: 10)
        let bottom = pixel(rendered, x: 100, y: 90)
        #expect(top.r > 200 && top.g < 100, "上端に赤い線が描かれている")
        #expect(bottom.r > 240 && bottom.g > 240, "下端は白のまま（Y軸が反転していない）")
    }

    @Test func renderWithoutAnnotationsReturnsSameImage() {
        let image = solidImage(width: 10, height: 10)
        #expect(AnnotationRenderer.render([], onto: image) === image)
    }

    @Test func jpegEncodingDownscalesWideImages() {
        let image = solidImage(width: 4000, height: 1000)
        let data = ImageCodec.jpegData(image, maxWidth: 2000)
        #expect(data != nil)
        let decoded = ImageCodec.load(data!)
        #expect(decoded?.width == 2000)
        #expect(decoded?.height == 500)
    }
}
