import AppKit
import Observation

/// メインウィンドウの外から撮影するための入口（グローバルショートカットとフローティングパネル）。
@MainActor
@Observable
final class CaptureControls {
    static let panelVisibleKey = "capturePanel.visible"
    static let panelCollapsedKey = "capturePanel.collapsed"
    static let panelSizeKey = "capturePanel.size"
    static let panelColorKey = "capturePanel.color"

    private(set) var shortcuts: [ShortcutAction: GlobalShortcut] = [:]
    /// 他のアプリが先に登録していて使えなかった操作
    private(set) var unavailableShortcuts: Set<ShortcutAction> = []
    /// 設定画面でキーを記録している間は、いまの組み合わせを押しても撮影が始まらないよう登録を外す。
    var isRecordingShortcut = false {
        didSet { if isRecordingShortcut != oldValue { applyShortcuts() } }
    }
    var isPanelVisible: Bool {
        didSet {
            defaults.set(isPanelVisible, forKey: Self.panelVisibleKey)
            if isStarted { updatePanel() }
        }
    }
    /// » で小さく畳んだ状態。畳むと、広げるボタン（«）だけが画面に残る。
    var isPanelCollapsed: Bool {
        didSet {
            defaults.set(isPanelCollapsed, forKey: Self.panelCollapsedKey)
            panel?.refresh()
        }
    }
    /// パネルのボタンの大きさ。設定とパネルの右クリックから変える。
    var panelSize: CapturePanelSize {
        didSet {
            defaults.set(panelSize.rawValue, forKey: Self.panelSizeKey)
            panel?.refresh()
        }
    }
    /// パネルの色。標準はシステムの素材（ライト／ダークに合わせる）。
    var panelColor: CapturePanelColor {
        didSet {
            defaults.set(panelColor.rawValue, forKey: Self.panelColorKey)
            panel?.refresh()
        }
    }
    /// SwiftUI の openWindow。編集画面を開き直すとき、「新規ウインドウ」のメニューが使えなければこちらを使う。
    @ObservationIgnored var openMainWindow: (() -> Void)?

    @ObservationIgnored private let model: AppModel
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var panel: CapturePanelController?
    @ObservationIgnored let rulers = ScreenRulers()
    @ObservationIgnored private var isStarted = false

    init(model: AppModel, defaults: UserDefaults = .standard) {
        self.model = model
        self.defaults = defaults
        // 初回はパネルを出しておく（設定を探さなくても撮影ボタンが見つかるように）
        isPanelVisible = defaults.object(forKey: Self.panelVisibleKey) as? Bool ?? true
        isPanelCollapsed = defaults.bool(forKey: Self.panelCollapsedKey)
        panelSize = defaults.string(forKey: Self.panelSizeKey).flatMap(CapturePanelSize.init(rawValue:)) ?? .medium
        panelColor = defaults.string(forKey: Self.panelColorKey).flatMap(CapturePanelColor.init(rawValue:)) ?? .standard
        // 以前は × でパネルを消していた。× が「畳む」になったので、それで消していた人には畳んだ形で戻す（初回だけ）。
        if defaults.object(forKey: Self.panelCollapsedKey) == nil, defaults.object(forKey: Self.panelVisibleKey) as? Bool == false {
            isPanelVisible = true
            isPanelCollapsed = true
            defaults.set(true, forKey: Self.panelVisibleKey)
        }
        // 書いておくことで、この移行は一度しか起きない
        defaults.set(isPanelCollapsed, forKey: Self.panelCollapsedKey)
        for action in ShortcutAction.allCases {
            // 空の Data は「ユーザーが外した」印。キー自体が無ければ既定値を使う。
            if let data = defaults.data(forKey: action.defaultsKey) {
                shortcuts[action] = data.isEmpty ? nil : (try? JSONDecoder().decode(GlobalShortcut.self, from: data))
            } else {
                shortcuts[action] = action.defaultShortcut
            }
        }
        // 測った状態はスクショに残したので、撮り終えたらルーラーとガイド線は片付ける（Esc でやめたときは残す）
        let rulers = rulers
        model.didCapture = { rulers.closeAll() }
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        GlobalHotKeyCenter.shared.onTrigger = { [weak self] action in self?.perform(action) }
        applyShortcuts()
        updatePanel()
    }

    // MARK: ショートカット

    /// 同じ組み合わせが別の操作に付いていたら、そちらから外す。
    func setShortcut(_ shortcut: GlobalShortcut?, for action: ShortcutAction) {
        if let shortcut {
            for other in ShortcutAction.allCases where other != action && shortcuts[other] == shortcut {
                store(nil, for: other)
            }
        }
        store(shortcut, for: action)
        applyShortcuts()
    }

    func resetShortcuts() {
        for action in ShortcutAction.allCases {
            defaults.removeObject(forKey: action.defaultsKey)
            shortcuts[action] = action.defaultShortcut
        }
        applyShortcuts()
    }

    private func store(_ shortcut: GlobalShortcut?, for action: ShortcutAction) {
        shortcuts[action] = shortcut
        let data = shortcut.flatMap { try? JSONEncoder().encode($0) } ?? Data()
        defaults.set(data, forKey: action.defaultsKey)
    }

    private func applyShortcuts() {
        guard isStarted else { return }
        if isRecordingShortcut {
            GlobalHotKeyCenter.shared.unregisterAll()
        } else {
            unavailableShortcuts = GlobalHotKeyCenter.shared.register(shortcuts)
        }
    }

    // MARK: 操作

    func perform(_ action: ShortcutAction) {
        switch action {
        case .captureRegion: Task { await capture(.interactive) }
        case .captureFullScreen: Task { await capture(.fullScreen) }
        case .toggleCapturePanel: isPanelVisible.toggle()
        case .newRuler: rulers.add()
        case .toggleRulers: rulers.toggleVisibility()
        case .newVerticalGuide: rulers.addGuide(.vertical)
        case .newHorizontalGuide: rulers.addGuide(.horizontal)
        case .clearRulers: rulers.closeAll()
        }
    }

    /// 撮れたら編集画面（メインウィンドウ）を出す。起動時は開いていないので、ここで初めて開くことが多い。
    /// 撮れなかったときも、理由のアラートを見せるために出す。範囲選択を Esc でやめたら、直前に使っていたアプリへ戻す。
    func capture(_ mode: CaptureMode) async {
        guard !model.isCapturing else { return }
        let previousApp = NSWorkspace.shared.frontmostApplication
        let captured = await model.capture(mode)
        if captured || model.errorMessage != nil {
            presentMainWindow()
        } else if let previousApp, previousApp != NSRunningApplication.current {
            previousApp.activate()
        }
    }

    /// パネルに画像をドロップしたとき。読めなかった場合もエラーのアラートを見せるためにウィンドウを出す。
    func importDroppedImage(_ providers: [NSItemProvider]) async {
        await model.importDroppedImage(providers)
        presentMainWindow()
    }

    /// クリップボードの画像を使う。編集画面を閉じていても使えるよう、ドロップと同じくウィンドウを出す。
    func pasteScreenshot() {
        model.pasteScreenshot()
        presentMainWindow()
    }

    func presentMainWindow() {
        NSApp.activate()
        let window = NSApp.windows.first {
            $0.identifier?.rawValue.hasPrefix("main") == true && ($0.isVisible || $0.isMiniaturized)
        }
        if let window {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else if !Self.chooseNewWindowCommand() {
            // メニューの項目が見つからないとき（「新規ウインドウ」のキーを変えたなど）だけ
            if let openMainWindow { openMainWindow() } else { model.showWindow() }
        }
    }

    /// 編集画面がひとつも無いときは、SwiftUI が「ファイル」メニューに置く「新規ウインドウ」（⌘N）を選んだことにして開く。
    /// 起動時は編集画面を開かないので、openWindow を受け取れるビューがまだ無い（App やパネルから読んだものは効く保証が無い）。
    private static func chooseNewWindowCommand() -> Bool {
        let item = NSApp.mainMenu?.items
            .compactMap(\.submenu)
            .flatMap(\.items)
            .first { $0.keyEquivalent == "n" && $0.keyEquivalentModifierMask == .command }
        guard let item, let action = item.action else { return false }
        return NSApp.sendAction(action, to: item.target, from: item)
    }

    private func updatePanel() {
        if isPanelVisible {
            if panel == nil { panel = CapturePanelController(controls: self) }
            panel?.show()
        } else {
            panel?.hide()
        }
    }
}
