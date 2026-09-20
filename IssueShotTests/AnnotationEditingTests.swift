import AppKit
import SwiftUI
import Testing
@testable import IssueShot

struct AnnotationEditingTests {
    @Test func moveKeepsShapeAndClampsToImageEdges() {
        let rect = Annotation(tool: .rectangle, color: .red, points: [CGPoint(x: 0.2, y: 0.3), CGPoint(x: 0.7, y: 0.8)])
        let moved = AnnotationGeometry.moved(rect, by: CGSize(width: 0.8, height: -1))
        #expect(abs(moved.points[0].x - 0.5) < 0.00001)
        #expect(abs(moved.points[1].x - 1) < 0.00001)
        #expect(abs(moved.points[0].y) < 0.00001)
        #expect(abs(moved.points[1].y - 0.5) < 0.00001)
        #expect(moved.id == rect.id)
    }

    @Test func hitTestingUsesDisplayedCoordinatesAndStrokeProximity() {
        let arrow = Annotation(tool: .arrow, color: .blue, points: [CGPoint(x: 0.1, y: 0.5), CGPoint(x: 0.9, y: 0.5)])
        #expect(AnnotationGeometry.hitTest(arrow, point: CGPoint(x: 100, y: 52), size: CGSize(width: 200, height: 100)))
        #expect(!AnnotationGeometry.hitTest(arrow, point: CGPoint(x: 100, y: 80), size: CGSize(width: 200, height: 100)))
    }

    @Test func rulerMeasuresOriginalPixelsAtAnyZoom() throws {
        let ruler = Annotation(tool: .ruler, color: .blue, points: [CGPoint(x: 0.1, y: 0.2), CGPoint(x: 0.4, y: 0.6)])
        let size = CGSize(width: 1000, height: 500)
        let full = try #require(AnnotationGeometry.rulerLabel(ruler, imageSize: size, displaySize: size))
        let half = try #require(AnnotationGeometry.rulerLabel(ruler, imageSize: size, displaySize: CGSize(width: 500, height: 250)))
        #expect(full.text == "361 px")
        #expect(full.text == half.text)
        #expect(full.center.x == half.center.x * 2)
        #expect(try JSONDecoder().decode(Annotation.self, from: JSONEncoder().encode(ruler)) == ruler)
    }

    @MainActor @Test func moveAndDeleteCanBeUndoneAndRedone() {
        let model = AppModel()
        let shape = Annotation(tool: .rectangle, color: .red, points: [.zero, CGPoint(x: 0.2, y: 0.2)])
        model.commitAnnotations([shape])
        let moved = AnnotationGeometry.moved(shape, by: CGSize(width: 0.2, height: 0.3))
        model.commitAnnotations([moved])
        model.undoAnnotation()
        #expect(model.annotations == [shape])
        model.redoAnnotation()
        #expect(model.annotations == [moved])
        model.selectedAnnotationID = shape.id
        model.deleteSelectedAnnotation()
        #expect(model.annotations.isEmpty)
        model.undoAnnotation()
        #expect(model.annotations == [moved])
        model.commitAnnotations([shape])
        #expect(!model.canRedoAnnotation)
        model.clearScreenshot()
        #expect(!model.canUndoAnnotation)
    }

    /// 図形の「近く」を掴めること。描画ツール中でも、この余白に入ったら新規作成ではなく移動にする。
    @Test func proximityGrabReachesFurtherThanATightHitTest() {
        let rect = Annotation(tool: .rectangle, color: .red, points: [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.5, y: 0.5)])
        let size = CGSize(width: 400, height: 400)
        let justOutside = CGPoint(x: 120, y: 71) // 上辺 y=80 の 9pt 外
        #expect(AnnotationGeometry.hitTest(rect, point: justOutside, size: size, tolerance: 10))
        #expect(!AnnotationGeometry.hitTest(rect, point: justOutside, size: size, tolerance: 4))
        #expect(!AnnotationGeometry.hitTest(rect, point: CGPoint(x: 120, y: 30), size: size, tolerance: 10))
    }

    @Test func gitHubLabelColorsAreParsedForChips() {
        #expect(Color(gitHubHex: "d73a4a") != nil)
        #expect(Color(gitHubHex: "#0e8a16") != nil)
        #expect(Color(gitHubHex: "fff") == nil)
        #expect(Color(gitHubHex: "not-hex") == nil)
    }

    @Test func rulerLabelSwitchesBetweenPixelsAndEm() {
        let ruler = Annotation(tool: .ruler, color: .blue, points: [CGPoint(x: 0, y: 0), CGPoint(x: 0.36, y: 0)])
        let size = CGSize(width: 1000, height: 500)
        func text(_ display: RulerDisplay) -> String? {
            AnnotationGeometry.rulerLabel(ruler, imageSize: size, displaySize: size, display: display)?.text
        }
        #expect(text(RulerDisplay(unit: .pixels, rootFontSize: 16)) == "360 px")
        #expect(text(RulerDisplay(unit: .em, rootFontSize: 16)) == "22.5 em")
        #expect(text(RulerDisplay(unit: .both, rootFontSize: 16)) == "360 px · 22.5 em")
        // font-size を変えれば em だけが変わる
        #expect(text(RulerDisplay(unit: .em, rootFontSize: 10)) == "36 em")
    }

    @MainActor @Test func arrowNudgeMovesOneImagePixelAndCoalescesIntoOneUndoStep() throws {
        let context = try #require(CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let model = AppModel()
        model.screenshot = try #require(context.makeImage()) // setScreenshot は履歴に保存してしまうので直接入れる
        let shape = Annotation(tool: .rectangle, color: .red, points: [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.4, y: 0.4)])
        model.commitAnnotations([shape])
        model.selectedAnnotationID = shape.id

        let start = Date()
        model.nudgeSelectedAnnotation(dx: 1, dy: 0, fast: false, now: start)
        #expect(abs(model.annotations[0].points[0].x - (0.2 + 1.0 / 200)) < 0.000001)
        // 続けて押した分は履歴を増やさない
        model.nudgeSelectedAnnotation(dx: 1, dy: 0, fast: true, now: start.addingTimeInterval(0.2))
        #expect(abs(model.annotations[0].points[0].x - (0.2 + 11.0 / 200)) < 0.000001)
        model.undoAnnotation()
        #expect(model.annotations == [shape])

        // 間が空いたら別の取り消し単位になる
        model.selectedAnnotationID = shape.id
        model.nudgeSelectedAnnotation(dx: 0, dy: 1, fast: false, now: start.addingTimeInterval(10))
        model.nudgeSelectedAnnotation(dx: 0, dy: 1, fast: false, now: start.addingTimeInterval(30))
        model.undoAnnotation()
        #expect(abs(model.annotations[0].points[0].y - (0.2 + 1.0 / 100)) < 0.000001)
    }

    @MainActor @Test func duplicateKeepsDimensionsAndSelectsTheCopy() throws {
        let context = try #require(CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let model = AppModel()
        model.screenshot = try #require(context.makeImage()) // 同上
        let shape = Annotation(tool: .rectangle, color: .red, points: [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.5, y: 0.6)])
        model.commitAnnotations([shape])
        model.selectedAnnotationID = shape.id
        model.duplicateSelectedAnnotation()

        #expect(model.annotations.count == 2)
        let copy = try #require(model.annotations.last)
        #expect(copy.id != shape.id)
        #expect(model.selectedAnnotationID == copy.id)
        // 寸法はそのまま、位置だけずれる
        let originalSize = CGSize(width: shape.points[1].x - shape.points[0].x, height: shape.points[1].y - shape.points[0].y)
        let copySize = CGSize(width: copy.points[1].x - copy.points[0].x, height: copy.points[1].y - copy.points[0].y)
        #expect(abs(originalSize.width - copySize.width) < 0.000001)
        #expect(abs(originalSize.height - copySize.height) < 0.000001)
        #expect(copy.points[0].x > shape.points[0].x)
        model.undoAnnotation()
        #expect(model.annotations == [shape])
    }

    @Test func exportedRulerContainsMeasurementLabel() throws {
        let context = try #require(CGContext(data: nil, width: 1000, height: 500, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 1000, height: 500))
        let original = try #require(context.makeImage())
        let ruler = Annotation(tool: .ruler, color: .red, points: [CGPoint(x: 0.2, y: 0.5), CGPoint(x: 0.8, y: 0.5)])
        let rendered = AnnotationRenderer.render([ruler], onto: original)
        let png = try #require(NSBitmapImageRep(cgImage: rendered).representation(using: .png, properties: [:]))
        #expect(rendered.width == 1000 && rendered.height == 500)
        let rep = NSBitmapImageRep(cgImage: rendered)
        let labelBackground = try #require(rep.colorAt(x: 480, y: 237))
        #expect(labelBackground.redComponent < 0.5)
        try png.write(to: URL(fileURLWithPath: "/tmp/revvy-ruler-export-test.png"), options: .atomic)
    }
}
