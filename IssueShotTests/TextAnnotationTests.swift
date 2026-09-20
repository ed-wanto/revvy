import CoreGraphics
import Foundation
import Testing
@testable import IssueShot

struct TextAnnotationTests {
    private func text(_ string: String?) -> Annotation {
        Annotation(tool: .text, color: .red, points: [CGPoint(x: 0.1, y: 0.2)], text: string, fontSize: 0.02)
    }

    @Test func emptyTextIsNotMeaningful() {
        #expect(!text(nil).isMeaningful)
        #expect(!text("  \n").isMeaningful)
        #expect(text("ここが崩れる").isMeaningful)
    }

    @Test func decodesAnnotationsSavedBeforeTextExisted() throws {
        let legacy = #"{"id":"6E1A4F43-6E0A-4B5B-9A0B-1B7A3C9E2F10","tool":"rectangle","color":"red","points":[[0.1,0.1],[0.5,0.5]]}"#
        let decoded = try JSONDecoder().decode(Annotation.self, from: Data(legacy.utf8))
        #expect(decoded.tool == .rectangle)
        #expect(decoded.text == nil)
        #expect(decoded.fontSize == nil)
    }

    @Test func roundTripsTextAndSize() throws {
        let original = text("A\nB")
        let decoded = try JSONDecoder().decode(Annotation.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func layoutScalesWithDrawingSize() throws {
        let annotation = text("Hello")
        let small = try #require(AnnotationGeometry.textLayout(annotation, in: CGSize(width: 1000, height: 500)))
        let large = try #require(AnnotationGeometry.textLayout(annotation, in: CGSize(width: 2000, height: 1000)))
        #expect(small.box.origin == CGPoint(x: 100, y: 100))
        #expect(large.fontSize == small.fontSize * 2)
        #expect(abs(large.box.width - small.box.width * 2) < 4)
    }

    @Test func hitTestCoversTheWholeBox() throws {
        let annotation = text("Hello")
        let size = CGSize(width: 1000, height: 500)
        let box = try #require(AnnotationGeometry.textLayout(annotation, in: size)).box
        #expect(AnnotationGeometry.hitTest(annotation, point: CGPoint(x: box.midX, y: box.midY), size: size))
        #expect(!AnnotationGeometry.hitTest(annotation, point: CGPoint(x: 900, y: 450), size: size))
    }

    @Test func rendererBurnsTextIntoImage() throws {
        let context = try #require(CGContext(data: nil, width: 400, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
        let blank = try #require(context.makeImage())
        let rendered = AnnotationRenderer.render([text("Bug")], onto: blank)
        // 文字の左の余白（背景色だけの所）。box は (40, 40) から始まる
        #expect(pixel(rendered, x: 41, y: 48) != pixel(blank, x: 41, y: 48))
        #expect(pixel(rendered, x: 300, y: 150) == pixel(blank, x: 300, y: 150))
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        let data = CFDataGetBytePtr(image.dataProvider!.data)!
        let offset = (y * image.bytesPerRow) + x * (image.bitsPerPixel / 8)
        return (0..<4).map { data[offset + $0] }
    }
}
