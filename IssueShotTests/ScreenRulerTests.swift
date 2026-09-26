import CoreGraphics
import Testing
@testable import IssueShot

struct ScreenRulerTests {
    private let bounds = CGRect(x: 0, y: 0, width: 320, height: 200)

    @Test func detectsEdgesAndCorners() {
        #expect(ScreenRulerGeometry.edges(at: CGPoint(x: 160, y: 100), in: bounds) == [])
        #expect(ScreenRulerGeometry.edges(at: CGPoint(x: 2, y: 100), in: bounds) == .left)
        #expect(ScreenRulerGeometry.edges(at: CGPoint(x: 318, y: 198), in: bounds) == [.right, .top])
    }

    @Test func resizingMovesOnlyGrabbedEdges() {
        let frame = CGRect(x: 100, y: 100, width: 320, height: 200)
        let wider = ScreenRulerGeometry.resized(frame, edges: .left, by: CGSize(width: -30, height: 50))
        #expect(wider == CGRect(x: 70, y: 100, width: 350, height: 200))
        let taller = ScreenRulerGeometry.resized(frame, edges: [.right, .top], by: CGSize(width: 10, height: 20))
        #expect(taller == CGRect(x: 100, y: 100, width: 330, height: 220))
    }

    @Test func resizingKeepsMinimumSize() {
        let frame = CGRect(x: 100, y: 100, width: 320, height: 200)
        let squashed = ScreenRulerGeometry.resized(frame, edges: [.left, .bottom], by: CGSize(width: 1000, height: 1000))
        #expect(squashed.size == ScreenRulerGeometry.minSize)
        #expect(squashed.maxX == frame.maxX)
        #expect(squashed.maxY == frame.maxY)
        #expect(squashed.size == CGSize(width: 1, height: 1))
    }

    @Test func tinyRulerSelectsOnlyNearestEdgesAndCanGrowAgain() {
        for size: CGFloat in [1, 2, 8, 16, 23] {
            let frame = CGRect(x: 100, y: 100, width: size, height: size)
            let bounds = CGRect(origin: .zero, size: frame.size)
            let nearBottomLeft = ScreenRulerGeometry.edges(at: CGPoint(x: size * 0.25, y: size * 0.25), in: bounds)
            let nearTopRight = ScreenRulerGeometry.edges(at: CGPoint(x: size * 0.75, y: size * 0.75), in: bounds)
            #expect(nearBottomLeft == [.left, .bottom])
            #expect(nearTopRight == [.right, .top])
            let grown = ScreenRulerGeometry.resized(frame, edges: nearTopRight, by: CGSize(width: 10, height: 10))
            #expect(grown.origin == frame.origin)
            #expect(grown.size == CGSize(width: size + 10, height: size + 10))
        }
    }

    @Test func resizingBelow24PreservesOppositeEdges() {
        let frame = CGRect(x: 100, y: 100, width: 24, height: 24)
        let small = ScreenRulerGeometry.resized(frame, edges: [.right, .bottom], by: CGSize(width: -16, height: 20))
        #expect(small == CGRect(x: 100, y: 120, width: 8, height: 4))
        let minimum = ScreenRulerGeometry.resized(small, edges: [.right, .bottom], by: CGSize(width: -100, height: 100))
        #expect(minimum == CGRect(x: 100, y: 123, width: 1, height: 1))
    }

    @Test func keepsNewRulerOnScreen() {
        let visible = CGRect(x: 1512, y: 0, width: 1920, height: 1055)
        let placed = ScreenRulerGeometry.constrained(CGRect(x: 3350, y: -60, width: 320, height: 200), to: visible)
        #expect(placed == CGRect(x: 3112, y: 0, width: 320, height: 200))
    }

    @Test func labelUsesRulerUnitSetting() {
        let size = CGSize(width: 320, height: 200)
        #expect(ScreenRulerGeometry.sizeLabel(size, display: RulerDisplay(unit: .pixels)) == "320 px × 200 px")
        #expect(ScreenRulerGeometry.sizeLabel(size, display: RulerDisplay(unit: .em, rootFontSize: 16)) == "20 em × 12.5 em")
    }

    @Test func tickLengthsMarkTensFiftiesAndHundreds() {
        #expect(ScreenRulerGeometry.tickLength(at: 10) < ScreenRulerGeometry.tickLength(at: 50))
        #expect(ScreenRulerGeometry.tickLength(at: 50) < ScreenRulerGeometry.tickLength(at: 100))
    }
}

struct ScreenGuideTests {
    // 外部ディスプレイ（Cocoa 座標、左下原点）
    private let screen = CGRect(x: 1512, y: -200, width: 1920, height: 1080)

    @Test func measuresFromLeftAndTopEdges() {
        #expect(ScreenGuideGeometry.distanceFromEdge(1512 + 640, orientation: .vertical, screen: screen) == 640)
        // 上端は y = 880。上から 300 の横線は y = 580
        #expect(ScreenGuideGeometry.distanceFromEdge(580, orientation: .horizontal, screen: screen) == 300)
    }

    @Test func windowFrameKeepsLineAtPosition() {
        let vertical = ScreenGuideGeometry.frame(for: 2000, orientation: .vertical, screen: screen)
        #expect(vertical.minX + ScreenGuideGeometry.lineOffset == 2000)
        #expect(vertical.height == screen.height)
        let horizontal = ScreenGuideGeometry.frame(for: 580, orientation: .horizontal, screen: screen)
        #expect(horizontal.maxY - ScreenGuideGeometry.lineOffset == 580)
        #expect(horizontal.width == screen.width)
    }

    @Test func staysOnItsDisplay() {
        #expect(ScreenGuideGeometry.clamped(100, orientation: .vertical, screen: screen) == screen.minX)
        #expect(ScreenGuideGeometry.clamped(9999, orientation: .vertical, screen: screen) == screen.maxX - 1)
        #expect(ScreenGuideGeometry.clamped(9999, orientation: .horizontal, screen: screen) == screen.maxY)
    }

    @Test func nearestGapIgnoresItselfAndFarGuides() {
        #expect(ScreenGuideGeometry.nearestGap(to: 500, among: [380, 700, 500]) == 120)
        #expect(ScreenGuideGeometry.nearestGap(to: 500, among: []) == nil)
    }

    @Test func labelFlipsToStayOnScreen() {
        let size = CGSize(width: 120, height: 20)
        let nearLeft = ScreenGuideGeometry.labelOrigin(for: 1600, orientation: .vertical, labelSize: size, screen: screen)
        #expect(nearLeft.x == 1606)
        let nearRight = ScreenGuideGeometry.labelOrigin(for: screen.maxX - 10, orientation: .vertical, labelSize: size, screen: screen)
        #expect(nearRight.x + size.width <= screen.maxX - 10)
        let nearTop = ScreenGuideGeometry.labelOrigin(for: screen.maxY - 5, orientation: .horizontal, labelSize: size, screen: screen)
        #expect(nearTop.y + size.height <= screen.maxY - 5)
    }

    @Test func labelShowsPositionAndGap() {
        let px = RulerDisplay(unit: .pixels)
        #expect(ScreenGuideGeometry.label(orientation: .vertical, distance: 640, gap: nil, display: px) == "X 640 px")
        #expect(ScreenGuideGeometry.label(orientation: .horizontal, distance: 300, gap: 24, display: px) == "Y 300 px  ↕ 24 px")
    }
}
