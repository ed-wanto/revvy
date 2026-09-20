import AppKit
import Observation

/// メインウィンドウの外から撮影するための入口（グローバルショートカットとフローティングパネル）。
@MainActor
@Observable
final class CaptureControls {
    static let panelVisibleKey = "capturePanel.visible"
    static let panelCollapsedKey = "capturePanel.collapsed"

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
    /// × で小さく畳んだ状態。畳んでも撮影ボタンひとつは画面に残る。
    var isPanelCollapsed: Bool {
        didSet {
            defaults.set(isPanelCollapsed, forKey: Self.panelCollapsedKey)
            panel?.setCollapsed(isPanelCollapsed)
        }
    }
    /// SwiftUI の openWindow。メインウィンドウが閉じられているときに開き直すのに使う。
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
        }
    }

    /// 撮れたらメインウィンドウを出す。範囲選択を Esc でやめたら、直前に使っていたアプリへ戻す。
    func capture(_ mode: CaptureMode) async {
        guard !model.isCapturing else { return }
        let previousApp = NSWorkspace.shared.frontmostApplication
        if await model.capture(mode) {
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

    func presentMainWindow() {
        NSApp.activate()
        let window = NSApp.windows.first {
            $0.identifier?.rawValue.hasPrefix("main") == true && ($0.isVisible || $0.isMiniaturized)
        }
        if let window {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else if let openMainWindow {
            openMainWindow()
        } else {
            model.showWindow()
        }
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
