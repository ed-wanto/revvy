import Foundation
import Testing
@testable import IssueShot

struct CapturePanelAppearanceTests {
    @Test func mediumKeepsTheOriginalLook() {
        #expect(CapturePanelSize.medium.buttonSize == 30)
        #expect(CapturePanelSize.medium.iconSize == 14)
        #expect(CapturePanelSize.medium.scale == 1)
    }

    @Test func sizesGrowInOrder() {
        let sizes = CapturePanelSize.allCases.map(\.buttonSize)
        #expect(sizes == sizes.sorted())
        #expect(Set(sizes).count == sizes.count)
    }

    /// 余白や区切り線は整数の pt に丸める（1pt の線がにじまないように）。中は以前の寸法のまま。
    @Test func scaledLengthsStayOnWholePoints() {
        let lengths: [CGFloat] = [2, 3, 4, 5, 11, 14, 18]
        for size in CapturePanelSize.allCases {
            for length in lengths {
                let value = size.scaled(length)
                #expect(value == value.rounded(), "\(size.rawValue) \(length)")
            }
        }
        #expect(lengths.map { CapturePanelSize.medium.scaled($0) } == lengths)
    }

    @Test func onlyStandardUsesTheSystemMaterial() {
        #expect(CapturePanelColor.allCases.filter { $0.fillRGB == nil } == [.standard])
    }

    /// 塗りの上の記号は、WCAG のテキスト以外の要素の基準（3:1）以上のコントラストで見えること
    @Test func iconsAreReadableOnEveryFill() {
        for color in CapturePanelColor.allCases {
            guard let fill = color.fillRGB else { continue }
            #expect(contrast(fill, color.inkRGB) >= 3, "\(color.rawValue)")
        }
    }

    @Test func readsHexColors() {
        let rgb = CapturePanelRGB(hex: 0xFF8000)
        #expect(rgb.red == 1)
        #expect(abs(rgb.green - 128.0 / 255) < 0.0001)
        #expect(rgb.blue == 0)
    }

    private func contrast(_ a: CapturePanelRGB, _ b: CapturePanelRGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func luminance(_ rgb: CapturePanelRGB) -> Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }
}
