import CoreGraphics
import Testing
@testable import IssueShot

struct CanvasViewportTests {
    let image = CGSize(width: 1600, height: 1000)
    let viewport = CGSize(width: 856, height: 556)

    @Test func fitLeavesRoomForCoordinateRulers() {
        #expect(CanvasViewport.scale(image: image, viewport: viewport, requested: nil) == 0.5)
        #expect(CanvasViewport.scale(image: CGSize(width: 100, height: 100), viewport: viewport, requested: nil) == 1)
    }

    @Test func requestedZoomIsClampedAndIndependentOfViewport() {
        #expect(CanvasViewport.scale(image: image, viewport: viewport, requested: 2) == 2)
        #expect(CanvasViewport.scale(image: image, viewport: viewport, requested: 10) == 4)
        #expect(CanvasViewport.scale(image: image, viewport: viewport, requested: 0.01) == 0.1)
    }

    @Test func panKeepsPartOfImageVisible() {
        let result = CanvasViewport.clampedOffset(CGSize(width: 5000, height: -5000), image: image, viewport: viewport, scale: 1)
        #expect(result == CGSize(width: 1164, height: -714))
        #expect(CanvasViewport.clampedOffset(.zero, image: image, viewport: viewport, scale: 0.5) == .zero)
    }

    @Test func portraitCanBeDraggedHorizontallyEvenWhenNarrowerThanViewport() {
        let requested = CGSize(width: 125, height: -150)
        let result = CanvasViewport.clampedOffset(requested, image: CGSize(width: 1170, height: 2532), viewport: CGSize(width: 714, height: 430), scale: 0.31)
        #expect(result == requested)
    }

    @Test func fittingImageCanBeRepositioned() {
        let requested = CGSize(width: 100, height: 80)
        #expect(CanvasViewport.clampedOffset(requested, image: image, viewport: viewport, scale: 0.5) == requested)
    }

    @Test func zoomPreservesImagePointAtViewportCenter() {
        let before = CGSize(width: 100, height: -50)
        let after = CanvasViewport.offsetAfterZoom(before, from: 1, to: 2, image: image, viewport: viewport)
        #expect(after == CGSize(width: 200, height: -100))
        #expect((image.width / 2 - before.width) == (image.width * 2 / 2 - after.width) / 2)
    }

    @Test func zoomAndPanDoNotChangeStoredRulerMeasurement() throws {
        let ruler = Annotation(tool: .ruler, color: .blue, points: [CGPoint(x: 0.2, y: 0.5), CGPoint(x: 0.7, y: 0.5)])
        for zoom: CGFloat in [0.25, 1, 2, 4] {
            let displaySize = CGSize(width: image.width * zoom, height: image.height * zoom)
            let label = try #require(AnnotationGeometry.rulerLabel(ruler, imageSize: image, displaySize: displaySize))
            #expect(label.text == "800 px")
            #expect(AnnotationGeometry.hitTest(ruler, point: CGPoint(x: 0.3 * displaySize.width, y: 0.5 * displaySize.height), size: displaySize))
        }
    }
}
