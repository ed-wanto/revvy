import SwiftUI

struct AnnotatorView: View {
    let image: CGImage
    let annotations: [Annotation]
    @Binding var selectedID: UUID?
    let tool: AnnotationTool
    let color: AnnotationColor
    let showPixelRulers: Bool
    let showCenterGuides: Bool
    let onCommit: ([Annotation]) -> Void
    /// 矢印キーの微調整はモデル側で履歴をまとめるので、呼び出し側に委ねる。
    let onNudge: (CGFloat, CGFloat, Bool) -> Void

    /// 倍率はツールバーから操作するので外に出す。nil は「全体表示」。
    @Binding var requestedZoom: CGFloat?
    /// 実際に描いている倍率を呼び出し側へ返す。
    @Binding var displayScale: CGFloat
    @State private var panOffset: CGSize = .zero
    @State private var panStart: CGSize?
    @Binding var handMode: Bool

    @State private var draft: Annotation?
    @State private var original: Annotation?
    @State private var endpoint: Int?
    @State private var isDragging = false
    /// カーソルの下にある注釈。描画ツール中でも「掴める」ことを見せる。
    @State private var hoveredID: UUID?
    @State private var hoveredEndpoint = false
    /// ⌫ を受け取るためにキャンバス自身がフォーカスを持つ。
    @FocusState private var canvasFocused: Bool
    /// 入力中のテキスト注釈。新規のものは確定するまで annotations に入れない。
    @State private var textEdit: TextEdit?
    @FocusState private var textFieldFocused: Bool
    /// ダブルクリックでテキストを編集するための、直前のクリック
    @State private var lastClick: (id: UUID, time: Date)?

    private struct TextEdit {
        var annotation: Annotation
        let isNew: Bool
    }

    private var imageSize: CGSize { CGSize(width: image.width, height: image.height) }
    private var preview: [Annotation] {
        var list = annotations
        if let draft {
            list = original != nil ? list.map { $0.id == draft.id ? draft : $0 } : list + [draft]
        }
        // 入力中のテキストは入力欄そのものが見た目を兼ねる
        if let textEdit { list.removeAll { $0.id == textEdit.annotation.id } }
        return list
    }

    var body: some View {
        GeometryReader { geometry in
            let scale = CanvasViewport.scale(image: imageSize, viewport: geometry.size, requested: requestedZoom)
            let fitted = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            ZStack {
                imageCanvas(size: fitted)
                    .position(x: geometry.size.width / 2 + panOffset.width, y: geometry.size.height / 2 + panOffset.height)
                if handMode {
                    Color.clear.contentShape(Rectangle())
                        .onContinuousHover { phase in
                            if case .active = phase { (panStart == nil ? NSCursor.openHand : NSCursor.closedHand).set() }
                        }
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            if panStart == nil { panStart = panOffset }
                            panOffset = CanvasViewport.clampedOffset(CGSize(width: panStart!.width + value.translation.width, height: panStart!.height + value.translation.height), image: imageSize, viewport: geometry.size, scale: scale)
                        }.onEnded { _ in panStart = nil })
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .background(CanvasInputView(onScroll: { delta in
                guard !isDragging, requestedZoom != nil else { return false }
                panOffset = CanvasViewport.clampedOffset(CGSize(width: panOffset.width + delta.width, height: panOffset.height + delta.height), image: imageSize, viewport: geometry.size, scale: scale)
                return true
            }, onMagnify: { amount in
                guard !isDragging else { return }
                requestedZoom = min(max(scale * (1 + amount), CanvasViewport.minScale), CanvasViewport.maxScale)
            }, onDelete: {
                guard canvasFocused else { return false }
                return deleteSelected() == .handled
            }, onArrow: { dx, dy, fast in
                guard canvasFocused, selectedID != nil else { return false }
                onNudge(dx, dy, fast)
                return true
            }))
            .onAppear { displayScale = scale }
            .onChange(of: scale) { old, new in
                cancelDrag()
                displayScale = new
                panOffset = CanvasViewport.offsetAfterZoom(panOffset, from: old, to: new, image: imageSize, viewport: geometry.size)
            }
            .onChange(of: geometry.size) { _, size in
                panOffset = CanvasViewport.clampedOffset(panOffset, image: imageSize, viewport: size, scale: scale)
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($canvasFocused)
        .onChange(of: handMode) { _, _ in cancelDrag(); commitTextEdit() }
        .onChange(of: tool) { _, _ in cancelDrag(); commitTextEdit() }
        .onChange(of: textFieldFocused) { _, focused in if !focused { commitTextEdit() } }
        .onChange(of: image) { _, _ in
            // 別の画像に切り替わったら、入力途中の文字はその画像のものではないので捨てる
            textEdit = nil
            selectedID = nil; hoveredID = nil; hoveredEndpoint = false
            cancelDrag(); requestedZoom = nil; panOffset = .zero; handMode = false
        }
    }

    private func imageCanvas(size fitted: CGSize) -> some View {
            ZStack {
                Image(decorative: image, scale: 1).resizable().interpolation(.high)
                Canvas { context, size in
                    if showCenterGuides { drawCenterGuides(size: size, context: &context) }
                    for annotation in preview {
                        draw(annotation, in: size, context: &context)
                    }
                    if let hovered = preview.first(where: { $0.id == hoveredID }), hoveredID != selectedID {
                        drawHoverHalo(hovered, size: size, context: &context)
                    }
                    if let selected = preview.first(where: { $0.id == selectedID }) {
                        drawSelection(selected, size: size, context: &context)
                    }
                }
            }
            .frame(width: fitted.width, height: fitted.height)
            .contentShape(Rectangle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                guard !handMode else { return }
                switch phase {
                case .active(let point):
                    if !isDragging {
                        let picked = pick(at: point, in: fitted)
                        hoveredID = picked?.annotation.id
                        hoveredEndpoint = picked?.endpoint != nil
                    }
                    cursor.set()
                case .ended:
                    hoveredID = nil
                    hoveredEndpoint = false
                    NSCursor.arrow.set()
                }
            }
            .gesture(dragGesture(in: fitted), including: handMode ? .none : .all)
            .clipped()
            .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
            .overlay(alignment: .topLeading) {
                if textEdit != nil { textEditor(in: fitted) }
            }
            .overlay(alignment: .topLeading) {
                if showPixelRulers {
                    PixelAxes(imageSize: imageSize, displaySize: fitted)
                        .frame(width: fitted.width + 22, height: fitted.height + 22)
                        .offset(x: -22, y: -22).allowsHitTesting(false)
                }
            }
    }

    @ViewBuilder
    private func textEditor(in size: CGSize) -> some View {
        if let edit = textEdit, let layout = AnnotationGeometry.textLayout(edit.annotation, in: size) {
            let padX = layout.fontSize * 0.4, padY = layout.fontSize * 0.2
            let radius = layout.fontSize * 0.25
            TextField("テキスト", text: Binding(
                get: { textEdit?.annotation.text ?? "" },
                set: { textEdit?.annotation.text = $0 }
            ), axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: layout.fontSize, weight: .bold))
            .foregroundStyle(edit.annotation.color.textOnColor)
            .focused($textFieldFocused)
            .onSubmit { commitTextEdit() }
            .onExitCommand { commitTextEdit() }
            // 打った分だけ横に伸ばす。キャレットのぶん少し余裕を持たせる
            .frame(width: max(layout.box.width - padX * 2, layout.fontSize * 4) + layout.fontSize * 0.6, alignment: .leading)
            .padding(.horizontal, padX)
            .padding(.vertical, padY)
            .background(edit.annotation.color.color, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(.cyan, style: StrokeStyle(lineWidth: 1, dash: [4, 3])).padding(-4))
            .fixedSize()
            .offset(x: layout.box.minX, y: layout.box.minY)
        }
    }

    private func beginTextEdit(_ annotation: Annotation, isNew: Bool) {
        commitTextEdit()
        selectedID = isNew ? nil : annotation.id
        textEdit = TextEdit(annotation: annotation, isNew: isNew)
        Task { @MainActor in textFieldFocused = true }
    }

    /// 空のまま確定したら、新規なら置かず、既存なら消す。
    private func commitTextEdit() {
        guard let edit = textEdit else { return }
        textEdit = nil
        var result = edit.annotation
        let trimmed = (result.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if !edit.isNew {
                onCommit(annotations.filter { $0.id != result.id })
                selectedID = nil
            }
            return
        }
        result.text = trimmed
        if edit.isNew {
            onCommit(annotations + [result])
        } else if annotations.first(where: { $0.id == result.id }) != result {
            onCommit(annotations.map { $0.id == result.id ? result : $0 })
        }
        selectedID = result.id
    }

    private func isDoubleClick(on id: UUID) -> Bool {
        guard let lastClick, lastClick.id == id else { return false }
        return Date().timeIntervalSince(lastClick.time) < NSEvent.doubleClickInterval
    }

    private func draw(_ annotation: Annotation, in size: CGSize, context: inout GraphicsContext) {
        if let layout = AnnotationGeometry.textLayout(annotation, in: size) {
            context.fill(Path(roundedRect: layout.box, cornerRadius: layout.fontSize * 0.25), with: .color(annotation.color.color))
            context.draw(Text(layout.string).font(.system(size: layout.fontSize, weight: .bold)).foregroundStyle(annotation.color.textOnColor),
                         at: layout.textOrigin, anchor: .topLeading)
            return
        }
        guard let drawable = AnnotationGeometry.drawable(annotation, in: size) else { return }
        context.stroke(drawable.stroke, with: .color(annotation.color.color), style: StrokeStyle(lineWidth: drawable.lineWidth, lineCap: .round, lineJoin: .round))
        if let fill = drawable.fill { context.fill(fill, with: .color(annotation.color.color)) }
        if let label = AnnotationGeometry.rulerLabel(annotation, imageSize: imageSize, displaySize: size) {
            let text = Text(label.text).font(.system(size: label.fontSize, weight: .bold)).foregroundStyle(.white)
            let resolved = context.resolve(text)
            let measured = resolved.measure(in: CGSize(width: size.width, height: 100))
            let rect = CGRect(x: label.center.x - measured.width / 2 - 6, y: label.center.y - measured.height / 2 - 4, width: measured.width + 12, height: measured.height + 8)
            context.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(.black.opacity(0.88)))
            context.draw(resolved, at: label.center)
        }
    }

    /// 掴める図形にうっすら縁を出す。選択中のものとは区別がつくよう実線の細枠にする。
    private func drawHoverHalo(_ annotation: Annotation, size: CGSize, context: inout GraphicsContext) {
        guard let drawable = AnnotationGeometry.drawable(annotation, in: size) else { return }
        context.stroke(Path(roundedRect: drawable.stroke.boundingRect.insetBy(dx: -5, dy: -5), cornerRadius: 3),
                       with: .color(.cyan.opacity(0.45)), lineWidth: 1)
    }

    /// カーソルの近くにある既存の注釈を返す。選択中の線分は端点を優先して掴む。
    private func pick(at location: CGPoint, in size: CGSize) -> (annotation: Annotation, endpoint: Int?)? {
        if let selected = annotations.first(where: { $0.id == selectedID }),
           selected.tool == .ruler || selected.tool == .arrow {
            let index = [0, selected.points.count - 1].first { index in
                guard selected.points.indices.contains(index) else { return false }
                let point = selected.points[index]
                return hypot(point.x * size.width - location.x, point.y * size.height - location.y) <= 12
            }
            if let index { return (selected, index) }
        }
        if let hit = annotations.reversed().first(where: {
            AnnotationGeometry.hitTest($0, point: location, size: size, tolerance: 10)
        }) {
            return (hit, nil)
        }
        return nil
    }

    private var cursor: NSCursor {
        if isDragging && original != nil { return .closedHand }
        if hoveredEndpoint { return .crosshair }
        if hoveredID != nil { return .openHand }
        switch tool {
        case .select: return .arrow
        case .text: return .iBeam
        default: return .crosshair
        }
    }

    /// 画像の中心を示す十字。書き出しには含めない。
    private func drawCenterGuides(size: CGSize, context: inout GraphicsContext) {
        var path = Path()
        path.move(to: CGPoint(x: size.width / 2, y: 0))
        path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        path.move(to: CGPoint(x: 0, y: size.height / 2))
        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(path, with: .color(Color(red: 1, green: 0.16, blue: 0.78).opacity(0.75)),
                       style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
    }

    private func deleteSelected() -> KeyPress.Result {
        guard let selectedID, annotations.contains(where: { $0.id == selectedID }) else { return .ignored }
        cancelDrag()
        hoveredID = nil
        hoveredEndpoint = false
        onCommit(annotations.filter { $0.id != selectedID })
        self.selectedID = nil
        return .handled
    }

    private func drawSelection(_ annotation: Annotation, size: CGSize, context: inout GraphicsContext) {
        guard let drawable = AnnotationGeometry.drawable(annotation, in: size) else { return }
        context.stroke(Path(drawable.stroke.boundingRect.insetBy(dx: -5, dy: -5)), with: .color(.cyan), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        if annotation.tool == .ruler || annotation.tool == .arrow {
            for point in [annotation.points.first, annotation.points.last].compactMap({ $0 }) {
                let rect = CGRect(x: point.x * size.width - 5, y: point.y * size.height - 5, width: 10, height: 10)
                context.fill(Path(ellipseIn: rect), with: .color(.white))
                context.stroke(Path(ellipseIn: rect), with: .color(.cyan), lineWidth: 2)
            }
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard size.width > 0, size.height > 0 else { return }
                if !isDragging {
                    isDragging = true
                    canvasFocused = true
                    // ⌥ を押している間だけ、既存の図形に重ねて新規に描ける。
                    let forceNew = tool != .select && NSEvent.modifierFlags.contains(.option)
                    if !forceNew, let picked = pick(at: value.startLocation, in: size) {
                        original = picked.annotation
                        endpoint = picked.endpoint
                        selectedID = picked.annotation.id
                    } else {
                        selectedID = nil
                        // テキストは離したときに置く（ドラッグで箱を作らない）
                        if tool != .select && tool != .text {
                            draft = Annotation(tool: tool, color: color, points: [normalize(value.startLocation, in: size)])
                        }
                    }
                }
                let point = normalize(value.location, in: size)
                if let original {
                    if let endpoint {
                        var resized = original
                        resized.points[endpoint] = point
                        draft = resized
                    } else {
                        draft = AnnotationGeometry.moved(original, by: CGSize(width: value.translation.width / size.width, height: value.translation.height / size.height))
                    }
                } else if var current = draft {
                    if tool == .pen { current.points.append(point) }
                    else {
                        let first = normalize(value.startLocation, in: size)
                        var end = point
                        if tool == .ruler && NSEvent.modifierFlags.contains(.shift) {
                            if abs(value.translation.width) >= abs(value.translation.height) { end.y = first.y }
                            else { end.x = first.x }
                        }
                        current.points = [first, end]
                    }
                    draft = current
                }
            }
            .onEnded { value in
                let isClick = hypot(value.translation.width, value.translation.height) < 3
                // テキストは、テキストツールでクリック、または他のツールでダブルクリックすると編集する
                if let original, isClick, original.tool == .text, tool == .text || isDoubleClick(on: original.id) {
                    cancelDrag()
                    lastClick = nil
                    beginTextEdit(original, isNew: false)
                    return
                }
                if original == nil, tool == .text {
                    cancelDrag()
                    beginTextEdit(Annotation(
                        tool: .text, color: color, points: [normalize(value.startLocation, in: size)], text: "",
                        fontSize: AnnotationGeometry.defaultTextSize(imageWidth: imageSize.width)
                    ), isNew: true)
                    return
                }
                if let original, isClick { lastClick = (original.id, Date()) }
                if let draft, draft.isMeaningful {
                    onCommit(original == nil ? annotations + [draft] : annotations.map { $0.id == draft.id ? draft : $0 })
                    selectedID = draft.id
                }
                cancelDrag()
            }
    }

    private func cancelDrag() { draft = nil; original = nil; endpoint = nil; isDragging = false; panStart = nil }

    private func normalize(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x / size.width, 0), 1), y: min(max(point.y / size.height, 0), 1))
    }
}

private struct PixelAxes: View {
    let imageSize: CGSize
    let displaySize: CGSize
    var body: some View {
        Canvas { context, _ in
            context.fill(Path(CGRect(x: 0, y: 0, width: displaySize.width + 22, height: 22)), with: .color(Color(nsColor: .controlBackgroundColor)))
            context.fill(Path(CGRect(x: 0, y: 0, width: 22, height: displaySize.height + 22)), with: .color(Color(nsColor: .controlBackgroundColor)))
            let scale = displaySize.width / imageSize.width
            // Keep labels readable regardless of zoom or Retina image resolution.
            let step = max(50, ceil(60 / scale / 50) * 50)
            for value in stride(from: 0.0, through: imageSize.width, by: step) {
                let x = 22 + value * scale
                var tick = Path(); tick.move(to: CGPoint(x: x, y: 17)); tick.addLine(to: CGPoint(x: x, y: 22))
                context.stroke(tick, with: .color(.secondary), lineWidth: 1)
                context.draw(Text("\(Int(value))").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary), at: CGPoint(x: x + 3, y: 8), anchor: .leading)
            }
            for value in stride(from: 0.0, through: imageSize.height, by: step) {
                let y = 22 + value * scale
                var tick = Path(); tick.move(to: CGPoint(x: 17, y: y)); tick.addLine(to: CGPoint(x: 22, y: y))
                context.stroke(tick, with: .color(.secondary), lineWidth: 1)
                var rotated = context
                rotated.translateBy(x: 8, y: y + 3); rotated.rotate(by: .degrees(-90))
                rotated.draw(Text("\(Int(value))").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary), at: .zero, anchor: .trailing)
            }
        }
    }
}
