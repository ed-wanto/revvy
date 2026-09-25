import AppKit
import Carbon.HIToolbox
import SwiftUI

/// どのアプリが前面でも呼び出せる操作。
enum ShortcutAction: String, CaseIterable, Identifiable, Sendable {
    case captureRegion
    case captureFullScreen
    case toggleCapturePanel
    case newRuler
    case toggleRulers
    case newVerticalGuide
    case newHorizontalGuide
    case clearRulers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .captureRegion: String(localized: "範囲を選んで撮影")
        case .captureFullScreen: String(localized: "画面全体を撮影")
        case .toggleCapturePanel: String(localized: "フローティングパネルの表示切替")
        case .newRuler: String(localized: "画面にルーラーを追加")
        case .toggleRulers: String(localized: "ルーラーの表示切替")
        case .newVerticalGuide: String(localized: "縦のガイド線を追加")
        case .newHorizontalGuide: String(localized: "横のガイド線を追加")
        case .clearRulers: String(localized: "ルーラーとガイド線をすべて消す")
        }
    }

    /// macOS 標準の ⌘⇧3 / ⌘⇧4 と重ならない組み合わせにする。ルーラーは Linear と同じキー。
    var defaultShortcut: GlobalShortcut? {
        switch self {
        case .captureRegion: GlobalShortcut(keyCode: UInt32(kVK_ANSI_4), modifiers: [.control, .shift], key: "4")
        case .captureFullScreen: GlobalShortcut(keyCode: UInt32(kVK_ANSI_3), modifiers: [.control, .shift], key: "3")
        case .toggleCapturePanel: nil
        case .newRuler: GlobalShortcut(keyCode: UInt32(kVK_ANSI_R), modifiers: [.control, .command], key: "R")
        case .toggleRulers: GlobalShortcut(keyCode: UInt32(kVK_ANSI_T), modifiers: [.control, .command], key: "T")
        case .newVerticalGuide: nil
        case .newHorizontalGuide: nil
        case .clearRulers: nil
        }
    }

    var defaultsKey: String { "shortcut.\(rawValue)" }

    fileprivate var hotKeyID: UInt32 { UInt32(Self.allCases.firstIndex(of: self)! + 1) }
}

struct GlobalShortcut: Codable, Hashable, Sendable {
    enum Problem: Equatable {
        /// ⌘⌃⌥ のどれも含まない（ファンクションキーを除く）
        case needsModifier
        /// macOS が先に受け取るので Revvy には届かない
        case reservedBySystem

        var message: String {
            switch self {
            case .needsModifier: String(localized: "⌘・⌃・⌥ のいずれかと組み合わせてください。")
            case .reservedBySystem: String(localized: "macOS 標準のショートカットと重なるため使えません。")
            }
        }
    }

    static let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    var keyCode: UInt32
    var modifierFlags: UInt
    /// 表示用のキー名（"4"、"F5"、"↩" など）
    var key: String

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, key: String) {
        self.keyCode = keyCode
        self.modifierFlags = modifiers.intersection(Self.relevantModifiers).rawValue
        self.key = key
    }

    init(event: NSEvent) {
        let keyCode = UInt32(event.keyCode)
        let name = Self.specialKeyNames[Int(keyCode)]
            ?? event.characters(byApplyingModifiers: [])?.uppercased()
            ?? "?"
        self.init(keyCode: keyCode, modifiers: event.modifierFlags, key: name)
    }

    var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifierFlags) }

    var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + key
    }

    var problem: Problem? {
        let code = Int(keyCode)
        let screenshotKeys = [kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6]
        if screenshotKeys.contains(code), modifiers.isSuperset(of: [.command, .shift]), !modifiers.contains(.option) {
            return .reservedBySystem
        }
        if modifiers == .command, code == kVK_Tab || code == kVK_Space { return .reservedBySystem }
        if modifiers.isDisjoint(with: [.command, .option, .control]), !Self.functionKeys.contains(code) {
            return .needsModifier
        }
        return nil
    }

    var carbonModifiers: UInt32 {
        var result = 0
        if modifiers.contains(.command) { result |= cmdKey }
        if modifiers.contains(.option) { result |= optionKey }
        if modifiers.contains(.control) { result |= controlKey }
        if modifiers.contains(.shift) { result |= shiftKey }
        return UInt32(result)
    }

    /// メニュー項目に表示する用。ファンクションキーなど SwiftUI で表せないものは nil。
    var menuShortcut: KeyboardShortcut? {
        let equivalent: KeyEquivalent? = switch Int(keyCode) {
        case kVK_Return: .return
        case kVK_Tab: .tab
        case kVK_Space: .space
        case kVK_Delete: .delete
        case kVK_Escape: .escape
        case kVK_LeftArrow: .leftArrow
        case kVK_RightArrow: .rightArrow
        case kVK_UpArrow: .upArrow
        case kVK_DownArrow: .downArrow
        default: key.count == 1 ? KeyEquivalent(Character(key.lowercased())) : nil
        }
        guard let equivalent else { return nil }
        var eventModifiers: SwiftUI.EventModifiers = []
        if modifiers.contains(.command) { eventModifiers.insert(.command) }
        if modifiers.contains(.option) { eventModifiers.insert(.option) }
        if modifiers.contains(.control) { eventModifiers.insert(.control) }
        if modifiers.contains(.shift) { eventModifiers.insert(.shift) }
        return KeyboardShortcut(equivalent, modifiers: eventModifiers)
    }

    private static let functionKeys: Set<Int> = [
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ]

    private static let specialKeyNames: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
        kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
    ]
}

// MARK: - 登録

/// Carbon のホットキーで登録する。アクセシビリティ権限が要らず、押したキーを他のアプリに漏らさない。
@MainActor
final class GlobalHotKeyCenter {
    static let shared = GlobalHotKeyCenter()

    var onTrigger: ((ShortcutAction) -> Void)?

    private static let signature: OSType = 0x5256_5659 // "RVVY"
    private var registered: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?

    /// 登録し直し、登録できなかった操作（他のアプリが使っているなど）を返す。
    func register(_ bindings: [ShortcutAction: GlobalShortcut]) -> Set<ShortcutAction> {
        unregisterAll()
        installHandlerIfNeeded()
        var failed = Set<ShortcutAction>()
        for action in ShortcutAction.allCases {
            guard let shortcut = bindings[action] else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: action.hotKeyID)
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                registered.append(ref)
            } else {
                failed.insert(action)
            }
        }
        return failed
    }

    func unregisterAll() {
        registered.forEach { UnregisterEventHotKey($0) }
        registered = []
    }

    fileprivate func fire(hotKeyID: UInt32) {
        guard let action = ShortcutAction.allCases.first(where: { $0.hotKeyID == hotKeyID }) else { return }
        onTrigger?(action)
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &spec, nil, &handler)
    }
}

private func hotKeyEventHandler(_: EventHandlerCallRef?, _ event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &id
    )
    guard status == noErr else { return status }
    let hotKeyID = id.id
    Task { @MainActor in GlobalHotKeyCenter.shared.fire(hotKeyID: hotKeyID) }
    return noErr
}
