import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import IssueShot

struct GlobalShortcutTests {
    @Test func displayStringUsesMacModifierOrder() {
        let shortcut = GlobalShortcut(keyCode: UInt32(kVK_ANSI_4), modifiers: [.command, .shift, .control, .option], key: "4")
        #expect(shortcut.displayString == "⌃⌥⇧⌘4")
    }

    @Test func ignoresNonShortcutModifiers() {
        let shortcut = GlobalShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: [.control, .capsLock, .function], key: "A")
        #expect(shortcut.modifiers == .control)
    }

    @Test func rejectsSystemScreenshotShortcuts() {
        #expect(GlobalShortcut(keyCode: UInt32(kVK_ANSI_4), modifiers: [.command, .shift], key: "4").problem == .reservedBySystem)
        #expect(GlobalShortcut(keyCode: UInt32(kVK_ANSI_3), modifiers: [.command, .shift, .control], key: "3").problem == .reservedBySystem)
        #expect(GlobalShortcut(keyCode: UInt32(kVK_ANSI_5), modifiers: [.command, .shift], key: "5").problem == .reservedBySystem)
        #expect(GlobalShortcut(keyCode: UInt32(kVK_Space), modifiers: .command, key: "Space").problem == .reservedBySystem)
    }

    @Test func requiresModifierExceptForFunctionKeys() {
        #expect(GlobalShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: [], key: "A").problem == .needsModifier)
        #expect(GlobalShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: .shift, key: "A").problem == .needsModifier)
        #expect(GlobalShortcut(keyCode: UInt32(kVK_F5), modifiers: [], key: "F5").problem == nil)
    }

    @Test func defaultsAvoidSystemShortcuts() {
        for action in ShortcutAction.allCases {
            #expect(action.defaultShortcut?.problem == nil)
        }
    }

    @Test func carbonModifiersMatchFlags() {
        let shortcut = GlobalShortcut(keyCode: UInt32(kVK_ANSI_4), modifiers: [.control, .shift], key: "4")
        #expect(shortcut.carbonModifiers == UInt32(controlKey | shiftKey))
    }
}

@MainActor
struct CaptureControlsTests {
    private func makeDefaults() -> UserDefaults {
        let name = "CaptureControlsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func usesDefaultsUntilChanged() {
        let controls = CaptureControls(model: AppModel(), defaults: makeDefaults())
        #expect(controls.shortcuts[.captureRegion] == ShortcutAction.captureRegion.defaultShortcut)
        #expect(controls.shortcuts[.toggleCapturePanel] == nil)
        #expect(controls.isPanelVisible)
    }

    @Test func persistsAssignedAndClearedShortcuts() {
        let defaults = makeDefaults()
        let custom = GlobalShortcut(keyCode: UInt32(kVK_ANSI_P), modifiers: [.option, .command], key: "P")
        let controls = CaptureControls(model: AppModel(), defaults: defaults)
        controls.setShortcut(custom, for: .toggleCapturePanel)
        controls.setShortcut(nil, for: .captureFullScreen)
        controls.isPanelVisible = false

        let reloaded = CaptureControls(model: AppModel(), defaults: defaults)
        #expect(reloaded.shortcuts[.toggleCapturePanel] == custom)
        // 外したものは既定値に戻らない
        #expect(reloaded.shortcuts[.captureFullScreen] == nil)
        #expect(reloaded.isPanelVisible == false)
    }

    @Test func remembersCollapsedPanel() {
        let defaults = makeDefaults()
        let controls = CaptureControls(model: AppModel(), defaults: defaults)
        #expect(!controls.isPanelCollapsed)
        controls.isPanelCollapsed = true
        #expect(CaptureControls(model: AppModel(), defaults: defaults).isPanelCollapsed)
    }

    @Test func panelHiddenByOldCloseButtonComesBackCollapsed() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: CaptureControls.panelVisibleKey)
        let controls = CaptureControls(model: AppModel(), defaults: defaults)
        #expect(controls.isPanelVisible)
        #expect(controls.isPanelCollapsed)
        // 一度戻したあとで隠したものは、隠したままにする
        controls.isPanelVisible = false
        #expect(!CaptureControls(model: AppModel(), defaults: defaults).isPanelVisible)
    }

    @Test func capturingClearsRulersAndGuides() {
        let model = AppModel()
        let controls = CaptureControls(model: model, defaults: makeDefaults())
        controls.rulers.add(frame: CGRect(x: 100, y: 100, width: 320, height: 200))
        controls.rulers.addGuide(.vertical)
        #expect(!controls.rulers.isEmpty)
        model.didCapture?()
        #expect(controls.rulers.isEmpty)
    }

    @Test func assigningDuplicateMovesShortcut() {
        let controls = CaptureControls(model: AppModel(), defaults: makeDefaults())
        let regionDefault = ShortcutAction.captureRegion.defaultShortcut
        controls.setShortcut(regionDefault, for: .captureFullScreen)
        #expect(controls.shortcuts[.captureFullScreen] == regionDefault)
        #expect(controls.shortcuts[.captureRegion] == nil)
    }

    @Test func resetRestoresDefaults() {
        let controls = CaptureControls(model: AppModel(), defaults: makeDefaults())
        controls.setShortcut(nil, for: .captureRegion)
        controls.resetShortcuts()
        #expect(controls.shortcuts[.captureRegion] == ShortcutAction.captureRegion.defaultShortcut)
    }
}

struct DisplayLocatorTests {
    // メイン 1512×982 の右に 2560×1440 の外部ディスプレイ（Cocoa 座標、左下原点）
    private let frames = [
        CGRect(x: 0, y: 0, width: 1512, height: 982),
        CGRect(x: 1512, y: -200, width: 2560, height: 1440),
    ]

    @Test func picksScreenUnderCursor() {
        #expect(DisplayLocator.index(of: CGPoint(x: 500, y: 500), in: frames) == 0)
        #expect(DisplayLocator.index(of: CGPoint(x: 3000, y: 1000), in: frames) == 1)
    }

    @Test func includesTopAndRightEdges() {
        // 外部ディスプレイのメニューバーの一番上
        #expect(DisplayLocator.index(of: CGPoint(x: 3000, y: 1240), in: frames) == 1)
        #expect(DisplayLocator.index(of: CGPoint(x: 4072, y: 600), in: frames) == 1)
    }

    @Test func fallsBackToNearestScreen() {
        #expect(DisplayLocator.index(of: CGPoint(x: 700, y: 1100), in: frames) == 0)
        #expect(DisplayLocator.index(of: CGPoint(x: 4200, y: 1300), in: frames) == 1)
        #expect(DisplayLocator.index(of: .zero, in: []) == nil)
    }
}
