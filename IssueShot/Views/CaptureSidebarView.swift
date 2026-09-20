import SwiftUI

/// 撮影履歴。モーダルではなく常設のサイドバーに置き、参照しながら編集できるようにする。
struct CaptureSidebarView: View {
    @Environment(AppModel.self) private var model
    @Binding var showConnect: Bool
    @State private var pendingDelete: SavedCapture?

    var body: some View {
        @Bindable var model = model
        List(selection: selection) {
            if model.filteredCaptures.isEmpty {
                Text(model.captureQuery.isEmpty ? "撮影した画像はここに並びます。" : "見つかりませんでした。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
            ForEach(groups) { group in
                Section(group.title) {
                    ForEach(group.captures) { capture in
                        CaptureRow(capture: capture)
                            .tag(capture.id)
                            .contextMenu {
                                Button("開く") { model.openCapture(capture) }
                                Button("削除…", role: .destructive) { pendingDelete = capture }
                            }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $model.captureQuery, placement: .sidebar, prompt: "メモや画像の中の文字")
        .safeAreaInset(edge: .bottom, spacing: 0) { accountFooter }
        .confirmationDialog("このMacの履歴から画像を削除しますか？", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("削除", role: .destructive) {
                if let capture = pendingDelete { model.deleteCapture(capture) }
                pendingDelete = nil
            }
            Button("キャンセル", role: .cancel) { pendingDelete = nil }
        }
    }

    /// 選択＝その場で開く。同じ行の再選択では読み込み直さない。
    private var selection: Binding<UUID?> {
        Binding(
            get: { model.selectedCaptureID },
            set: { id in
                guard let id, id != model.selectedCaptureID,
                      let capture = model.captures.first(where: { $0.id == id }) else { return }
                model.openCapture(capture)
            }
        )
    }

    private var accountFooter: some View {
        VStack(spacing: 0) {
            Divider()
            Group {
                if let user = model.user {
                    Menu {
                        Button("リポジトリ一覧を更新") { Task { await model.loadRepos() } }
                        SettingsLink { Text("設定…") }
                        Divider()
                        Button("GitHub 連携を解除", role: .destructive) { model.signOut() }
                    } label: {
                        // Menu のラベルに独自のビューを渡すと落ちるので、文字と SF Symbol だけにする。
                        Label("@\(user.login)", systemImage: "person.crop.circle")
                    }
                    .controlSize(.small)
                } else {
                    Button { showConnect = true } label: {
                        Label("GitHub と連携", systemImage: "link").frame(maxWidth: .infinity)
                    }
                    .controlSize(.small)
                    .disabled(model.auth == .checking)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private struct CaptureGroup: Identifiable {
        let id: TimeInterval
        let title: String
        let captures: [SavedCapture]
    }

    /// 日ごとにまとめる。並びは model 側の新しい順をそのまま保つ。
    private var groups: [CaptureGroup] {
        let calendar = Calendar.current
        var order: [Date] = []
        var buckets: [Date: [SavedCapture]] = [:]
        for capture in model.filteredCaptures {
            let day = calendar.startOfDay(for: capture.createdAt)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(capture)
        }
        return order.map { day in
            let title: String
            if calendar.isDateInToday(day) { title = String(localized: "今日") }
            else if calendar.isDateInYesterday(day) { title = String(localized: "昨日") }
            else { title = day.formatted(date: .abbreviated, time: .omitted) }
            return CaptureGroup(id: day.timeIntervalSince1970, title: title, captures: buckets[day] ?? [])
        }
    }
}

private struct CaptureRow: View {
    let capture: SavedCapture

    var body: some View {
        HStack(spacing: 9) {
            CaptureThumbnail(capture: capture, maxWidth: 160)
                .frame(width: 34, height: 24)
                .background(RevvyStyle.canvas, in: RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(RevvyStyle.hairline))
            VStack(alignment: .leading, spacing: 1) {
                Text(capture.note.isEmpty ? String(localized: "無題のキャプチャ") : capture.note)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                Text(capture.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

/// 注釈込みのサムネイル。サイドバーでは小さく作って読み込みを軽くする。
struct CaptureThumbnail: View {
    let capture: SavedCapture
    var maxWidth: Int = 600
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .task(id: capture.id) {
            guard let original = ImageCodec.load(CaptureLibrary().imageURL(capture.id)) else { return }
            let rendered = AnnotationRenderer.render(capture.annotations ?? [], onto: original)
            thumbnail = NSImage(cgImage: ImageCodec.downscale(rendered, maxWidth: maxWidth), size: .zero)
        }
    }
}
