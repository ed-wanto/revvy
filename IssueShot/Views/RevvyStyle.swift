import SwiftUI

/// 色は面ではなく操作対象にだけ使う。角丸はコントロール 6 / フィールド 8 / 浮くもの 12 の三段階に絞る。
enum RevvyStyle {
    enum Radius {
        static let control: CGFloat = 6
        static let field: CGFloat = 8
        static let floating: CGFloat = 12
    }

    /// ブランドの緑。ライトは #0C7A5A、ダークは背景から浮くよう彩度を上げた #2FBE93。
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.184, green: 0.745, blue: 0.576, alpha: 1)
            : NSColor(srgbRed: 0.047, green: 0.478, blue: 0.353, alpha: 1)
    })

    /// アクセント上に載せる文字色。ダークの明るい緑に白を置くとコントラストが足りない。
    static let onAccent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.024, green: 0.141, blue: 0.106, alpha: 1)
            : .white
    })

    /// 画像を置く地。ドットグリッドを敷くので彩度は落としておく。
    static let canvas = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.063, green: 0.082, blue: 0.078, alpha: 1)
            : NSColor(srgbRed: 0.894, green: 0.910, blue: 0.898, alpha: 1)
    })

    static let hairline = Color.primary.opacity(0.10)
}

/// キャンバスの上に浮くパレットの 28pt ボタン。
struct ToolButton: View {
    let symbol: String
    let title: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 28)
                .foregroundStyle(selected ? RevvyStyle.onAccent : Color.primary.opacity(0.75))
                .background(selected ? RevvyStyle.accent : .clear,
                            in: RoundedRectangle(cornerRadius: RevvyStyle.Radius.control))
                .contentShape(RoundedRectangle(cornerRadius: RevvyStyle.Radius.control))
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

/// パレット内の区切り。
struct ToolDivider: View {
    var body: some View {
        Rectangle()
            .fill(RevvyStyle.hairline)
            .frame(width: 1, height: 17)
            .padding(.horizontal, 4)
    }
}

/// キャンバスの上に浮かせる面。macOS 26 ではガラス、それ以前は素材にフォールバックする。
private struct FloatingPanel: ViewModifier {
    let radius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(RevvyStyle.hairline))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        }
    }
}

extension View {
    func floatingPanel(radius: CGFloat = RevvyStyle.Radius.floating) -> some View {
        modifier(FloatingPanel(radius: radius))
    }
}

/// 選んだものをその場で見せて外せるチップ。プルダウンの中身を開かずに確認・解除できる。
struct SelectionChip: View {
    let label: String
    var dot: Color?
    let remove: () -> Void

    var body: some View {
        Button(action: remove) {
            HStack(spacing: 4) {
                if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
                Text(label).font(.system(size: 11)).lineLimit(1)
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary)
            }
            .padding(.leading, 7)
            .padding(.trailing, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.08), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("\(label) を外す")
        .accessibilityLabel("\(label) を外す")
    }
}

/// チップは幅がまちまちなので、Grid ではなく折り返しの専用レイアウトに並べる。
struct FlowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > limit { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: limit == .infinity ? x : limit, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension Color {
    /// GitHub のラベル色（"d73a4a"）を読む。
    init?(gitHubHex hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var value: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
