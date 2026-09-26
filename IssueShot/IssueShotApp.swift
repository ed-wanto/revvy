import SwiftUI

@main
struct RevvyApp: App {
    @NSApplicationDelegateAdaptor(RevvyAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    private var model: AppModel { appDelegate.model }
    private var controls: CaptureControls { appDelegate.controls }

    var body: some Scene {
        WindowGroup("Revvy", id: "main") {
            ContentView()
                .environment(model)
                .environment(controls)
                .task { await model.bootstrap() }
                .onAppear {
                    let openWindow = openWindow
                    controls.openMainWindow = { openWindow(id: "main") }
                }
        }
        .defaultSize(width: 1180, height: 820)
        // 起動時はフローティングパネルだけを出し、編集画面は撮影したとき（「Revvy を開く」や Dock からも）に開く。
        // パネルを隠していると入口が見えなくなるので、そのときだけ起動時にも開く。
        // 編集画面を開く流れは CaptureControls.presentMainWindow() にまとめてある。
        .defaultLaunchBehavior(appDelegate.showsPanelAtLaunch ? .suppressed : .automatic)
        // 前回終了時に開いていても、起動時に編集画面を戻さない
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(after: .newItem) {
                // ⌘⇧3 / ⌘⇧4 は macOS が先に取るので、設定で登録したグローバルショートカットを表示する。
                // 編集画面を閉じていても使えるので、パネルから撮ったときと同じく撮ったあとは編集画面を出す。
                Button("範囲を選んで撮影") { Task { await controls.capture(.interactive) } }
                    .keyboardShortcut(controls.shortcuts[.captureRegion]?.menuShortcut)
                    .disabled(model.isCapturing)
                Button("画面全体を撮影") { Task { await controls.capture(.fullScreen) } }
                    .keyboardShortcut(controls.shortcuts[.captureFullScreen]?.menuShortcut)
                    .disabled(model.isCapturing)
                Button("クリップボードの画像を使う") { controls.pasteScreenshot() }
                    .keyboardShortcut("v", modifiers: [.command, .shift])
                    .disabled(model.isCapturing)
            }
            // 標準の取り消し／やり直しを置き換える。入力欄を編集中はその文字、それ以外は注釈に効く。
            // 入力欄のフォーカスは SwiftUI から観測できないので、無効化はせず押されたときに振り分ける。
            CommandGroup(replacing: .undoRedo) {
                Button("取り消す") { UndoRouter.undo(model) }
                    .keyboardShortcut("z", modifiers: .command)
                Button("やり直す") { UndoRouter.redo(model) }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            CommandGroup(after: .undoRedo) {
                Button("選択した注釈を複製") { model.duplicateSelectedAnnotation() }
                    .keyboardShortcut("d", modifiers: .command)
                    .disabled(model.selectedAnnotationID == nil)
                // ⌫ 単体はキャンバスが受け取る。入力欄での削除を奪わないよう、ここには割り当てない。
                Button("選択した注釈を削除") { model.deleteSelectedAnnotation() }
                    .disabled(model.selectedAnnotationID == nil)
            }
            CommandGroup(after: .sidebar) {
                Button("拡大") { model.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                    .disabled(model.screenshot == nil)
                Button("縮小") { model.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                    .disabled(model.screenshot == nil)
                Button("実寸表示（100%）") { model.requestedZoom = 1 }
                    .keyboardShortcut("1", modifiers: .command)
                    .disabled(model.screenshot == nil)
                Button("全体表示") { model.zoomToFit() }
                    .keyboardShortcut("0", modifiers: .command)
                    .disabled(model.screenshot == nil)
                Toggle("センターガイド", isOn: Binding(
                    get: { model.showCenterGuides }, set: { model.showCenterGuides = $0 }
                ))
                .keyboardShortcut(";", modifiers: .command)
                .disabled(model.screenshot == nil)
                Toggle("座標ルーラー", isOn: Binding(
                    get: { model.showPixelRulers }, set: { model.showPixelRulers = $0 }
                ))
                .disabled(model.screenshot == nil)
                Divider()
            }
        }

        MenuBarExtra("Revvy", systemImage: "camera.viewfinder") {
            Button("範囲を選んで撮影") { Task { await controls.capture(.interactive) } }
                .keyboardShortcut(controls.shortcuts[.captureRegion]?.menuShortcut)
                .disabled(model.isCapturing)
            Button("画面全体を撮影") { Task { await controls.capture(.fullScreen) } }
                .keyboardShortcut(controls.shortcuts[.captureFullScreen]?.menuShortcut)
                .disabled(model.isCapturing)
            Button("画面にルーラーを追加") { controls.rulers.add() }
                .keyboardShortcut(controls.shortcuts[.newRuler]?.menuShortcut)
            Button("縦のガイド線を追加") { controls.rulers.addGuide(.vertical) }
                .keyboardShortcut(controls.shortcuts[.newVerticalGuide]?.menuShortcut)
            Button("横のガイド線を追加") { controls.rulers.addGuide(.horizontal) }
                .keyboardShortcut(controls.shortcuts[.newHorizontalGuide]?.menuShortcut)
            Toggle("ガイド線同士の距離を表示", isOn: Binding(
                get: { controls.rulers.showGuideDistances }, set: { controls.rulers.showGuideDistances = $0 }
            ))
            Button("ルーラーとガイド線をすべて消す") { controls.rulers.closeAll() }
                .keyboardShortcut(controls.shortcuts[.clearRulers]?.menuShortcut)
                .disabled(controls.rulers.isEmpty)
            Toggle("フローティングパネルを表示", isOn: Binding(
                get: { controls.isPanelVisible }, set: { controls.isPanelVisible = $0 }
            ))
            .keyboardShortcut(controls.shortcuts[.toggleCapturePanel]?.menuShortcut)
            Button("Revvy を開く") { controls.presentMainWindow() }
            Divider()
            SettingsLink { Text("設定…") }
            Divider()
            Button("終了") { NSApplication.shared.terminate(nil) }
        }

        Settings {
            SettingsView()
                .environment(model)
                .environment(controls)
        }
    }
}

@MainActor
enum UndoRouter {
    /// 入力欄の編集中は、キーウィンドウのファーストレスポンダがフィールドエディタ（NSTextView）になる
    static var isEditingText: Bool { NSApp.keyWindow?.firstResponder is NSText }

    static func undo(_ model: AppModel) {
        if isEditingText {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
        } else {
            model.undoAnnotation()
        }
    }

    static func redo(_ model: AppModel) {
        if isEditingText {
            NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
        } else {
            model.redoAnnotation()
        }
    }
}

/// Set the running app icon from a bundled image instead of relying on cached asset lookup.
/// ウィンドウが無くてもショートカットとパネルが効くよう、モデルはここで持つ。
@MainActor
final class RevvyAppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel
    let controls: CaptureControls
    /// 起動時にパネルを出すか。起動後に切り替えるたびにシーンを作り直さないよう、起動時の値だけを持つ。
    let showsPanelAtLaunch: Bool

    override init() {
        model = AppModel()
        controls = CaptureControls(model: model)
        showsPanelAtLaunch = controls.isPanelVisible
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // テストのホストとして起動したときは、ホットキーやパネルを出さない。
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            controls.start()
            // 起動時は編集画面を開かないので、撮る前に履歴と GitHub の連携を読み込んでおく
            Task { await model.bootstrap() }
            // Dock のアイコンを押したとき（起動中にもう一度開いたときも）は編集画面を出す。
            // 起動時に出さない画面は SwiftUI が Dock からも開かず、applicationShouldHandleReopen もこのデリゲートには
            // 届かないことがあるので、「再度開く」Apple イベントを直接受ける。SwiftUI の起動処理のあとで登録して上書きされないようにする。
            Task { installReopenHandler() }
        }
        guard let url = Bundle.main.url(forResource: "RevvyDockIcon", withExtension: "png"),
              let icon = NSImage(contentsOf: url) else { return }
        NSApplication.shared.applicationIconImage = icon
    }

    private func installReopenHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleReopen(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEReopenApplication)
        )
    }

    @objc private func handleReopen(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        controls.presentMainWindow()
    }
}
