import SwiftUI

struct SettingsView: View {
    @Environment(CaptureControls.self) private var controls
    @AppStorage(SettingsKeys.clientID) private var clientID = ""
    @AppStorage(SettingsKeys.issueLabel) private var issueLabel = SettingsKeys.defaultLabel
    @AppStorage(SettingsKeys.assetsBranch) private var assetsBranch = SettingsKeys.defaultAssetsBranch
    @AppStorage(SettingsKeys.rulerUnit) private var rulerUnit = RulerUnit.pixels.rawValue
    @AppStorage(SettingsKeys.rootFontSize) private var rootFontSize = SettingsKeys.defaultRootFontSize

    var body: some View {
        Form {
            Section {
                TextField("Client ID（上書き）", text: $clientID, prompt: Text(OAuthConfig.bundledClientID.isEmpty ? "未設定" : "同梱: \(OAuthConfig.bundledClientID)"))
                    .font(.body.monospaced())
                Text("""
                    通常は空のままで構いません（アプリ同梱の OAuth App を使います）。\
                    別の OAuth App を使う場合は、「Enable Device Flow」を有効にした App の Client ID を入力してください。
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link("OAuth App を作成する", destination: URL(string: "https://github.com/settings/applications/new")!)
                    .font(.caption)
            } header: {
                Text("GitHub 連携（ブラウザ承認）")
            }

            Section {
                Toggle("フローティングパネルを表示", isOn: Binding(
                    get: { controls.isPanelVisible }, set: { controls.isPanelVisible = $0 }
                ))
                Picker("サイズ", selection: Binding(get: { controls.panelSize }, set: { controls.panelSize = $0 })) {
                    ForEach(CapturePanelSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                LabeledContent("色") {
                    CapturePanelColorPicker(selection: Binding(get: { controls.panelColor }, set: { controls.panelColor = $0 }))
                }
                Text("起動時に出るのはこのパネルだけです（隠しているときは編集画面を開きます）。大きさと色はパネルの右クリックでも変えられます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("フローティングパネル")
            }

            Section {
                ForEach(ShortcutAction.allCases) { action in
                    LabeledContent(action.title) {
                        ShortcutRecorder(action: action)
                    }
                    if controls.unavailableShortcuts.contains(action) {
                        Label("他のアプリが同じ組み合わせを使っているため登録できませんでした。", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                HStack {
                    Text("どのアプリを使っていても使えます。ルーラーはスクリーンショットを撮らずに画面の上で測れます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("既定に戻す") { controls.resetShortcuts() }
                        .controlSize(.small)
                }
            } header: {
                Text("ショートカット")
            }

            Section("ルーラー") {
                Picker("表示する単位", selection: $rulerUnit) {
                    ForEach(RulerUnit.allCases) { unit in
                        Text(unit.title).tag(unit.rawValue)
                    }
                }
                if rulerUnit != RulerUnit.pixels.rawValue {
                    LabeledContent("ルートの font-size") {
                        HStack(spacing: 6) {
                            TextField("16", value: $rootFontSize, format: .number.precision(.fractionLength(0...2)))
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                            Text("px").foregroundStyle(.secondary)
                        }
                    }
                }
                Text("計測は常に元画像のピクセルです。em はこの font-size で割った値を併記します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Issue") {
                TextField("自動で付けるラベル", text: $issueLabel)
                TextField("スクリーンショット置き場ブランチ", text: $assetsBranch)
                    .font(.body.monospaced())
                Text("画像は Issue 本文に埋め込まず、このブランチに `screenshots/` としてコミットします。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        // 項目が増えて小さい画面に収まらなくなるので、高さに上限を付けて中身をスクロールさせる
        .frame(maxHeight: 680)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// クリックしてから押したキーの組み合わせを登録する。Esc でやめる、⌫ で外す。
private struct ShortcutRecorder: View {
    @Environment(CaptureControls.self) private var controls
    let action: ShortcutAction
    @State private var recorder = KeyRecorder()
    @State private var problem: GlobalShortcut.Problem?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    recorder.isRecording ? stop() : start()
                } label: {
                    Text(label)
                        .font(.body.monospaced())
                        .foregroundStyle(recorder.isRecording || controls.shortcuts[action] == nil ? .secondary : .primary)
                        .frame(minWidth: 130)
                }
                // 未設定の行でも幅を揃えるため、ボタンは隠すだけにする。
                let canClear = controls.shortcuts[action] != nil && !recorder.isRecording
                Button {
                    controls.setShortcut(nil, for: action)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("ショートカットを外す")
                .opacity(canClear ? 1 : 0)
                .disabled(!canClear)
            }
            if let problem {
                Text(problem.message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onDisappear { stop() }
    }

    private var label: String {
        if recorder.isRecording { return String(localized: "キーを押してください…") }
        return controls.shortcuts[action]?.displayString ?? String(localized: "未設定")
    }

    private func start() {
        problem = nil
        controls.isRecordingShortcut = true
        recorder.start { event in
            let plain = event.modifierFlags.isDisjoint(with: GlobalShortcut.relevantModifiers)
            if plain && event.keyCode == 53 { // Esc
                stop()
            } else if plain && (event.keyCode == 51 || event.keyCode == 117) { // ⌫ / ⌦
                controls.setShortcut(nil, for: action)
                stop()
            } else {
                let shortcut = GlobalShortcut(event: event)
                if let issue = shortcut.problem {
                    problem = issue
                } else {
                    controls.setShortcut(shortcut, for: action)
                    stop()
                }
            }
        }
    }

    private func stop() {
        guard recorder.isRecording else { return }
        problem = nil
        recorder.stop()
        controls.isRecordingShortcut = false
    }
}

@MainActor
@Observable
private final class KeyRecorder {
    private(set) var isRecording = false
    @ObservationIgnored private var monitor: Any?

    func start(_ handle: @escaping @MainActor (NSEvent) -> Void) {
        stop()
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { handle(event) }
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
