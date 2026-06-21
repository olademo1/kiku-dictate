import AppKit
import Carbon

struct Hotkey: Codable, Equatable {
    private static let fnModifierMask: UInt32 = UInt32(kEventKeyModifierFnMask)
    private static let functionKeyCodes: Set<UInt32> = [
        UInt32(kVK_F1), UInt32(kVK_F2), UInt32(kVK_F3), UInt32(kVK_F4),
        UInt32(kVK_F5), UInt32(kVK_F6), UInt32(kVK_F7), UInt32(kVK_F8),
        UInt32(kVK_F9), UInt32(kVK_F10), UInt32(kVK_F11), UInt32(kVK_F12),
        UInt32(kVK_F13), UInt32(kVK_F14), UInt32(kVK_F15), UInt32(kVK_F16),
        UInt32(kVK_F17), UInt32(kVK_F18), UInt32(kVK_F19), UInt32(kVK_F20)
    ]

    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = Hotkey(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey)
    )

    var isValidGlobalShortcut: Bool {
        let commandLikeModifiers = modifiers & UInt32(cmdKey | optionKey | controlKey)
        let isFunctionKey = Self.functionKeyCodes.contains(keyCode)

        if isFunctionKey {
            return true
        }

        return commandLikeModifiers != 0
    }

    var displayValue: String {
        let parts = modifierNames + [keyDisplay]
        return parts.joined(separator: " ")
    }

    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if modifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if modifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & Hotkey.fnModifierMask != 0 { flags.insert(.function) }
        return flags
    }

    private var modifierNames: [String] {
        var names: [String] = []
        if modifiers & UInt32(controlKey) != 0 { names.append("Control") }
        if modifiers & UInt32(optionKey) != 0 { names.append("Option") }
        if modifiers & UInt32(shiftKey) != 0 { names.append("Shift") }
        if modifiers & UInt32(cmdKey) != 0 { names.append("Command") }
        if modifiers & Hotkey.fnModifierMask != 0 { names.append("Fn") }
        return names
    }

    private var keyDisplay: String {
        switch keyCode {
        case UInt32(kVK_Home): return "Home"
        case UInt32(kVK_End): return "End"
        case UInt32(kVK_PageUp): return "PgUp"
        case UInt32(kVK_PageDown): return "PgDn"
        case UInt32(kVK_Help): return "Help"
        case UInt32(kVK_ForwardDelete): return "Del"
        case UInt32(kVK_LeftArrow): return "Left"
        case UInt32(kVK_RightArrow): return "Right"
        case UInt32(kVK_UpArrow): return "Up"
        case UInt32(kVK_DownArrow): return "Down"
        case UInt32(kVK_F1): return "F1"
        case UInt32(kVK_F2): return "F2"
        case UInt32(kVK_F3): return "F3"
        case UInt32(kVK_F4): return "F4"
        case UInt32(kVK_F5): return "F5"
        case UInt32(kVK_F6): return "F6"
        case UInt32(kVK_F7): return "F7"
        case UInt32(kVK_F8): return "F8"
        case UInt32(kVK_F9): return "F9"
        case UInt32(kVK_F10): return "F10"
        case UInt32(kVK_F11): return "F11"
        case UInt32(kVK_F12): return "F12"
        case UInt32(kVK_F13): return "F13"
        case UInt32(kVK_F14): return "F14"
        case UInt32(kVK_F15): return "F15"
        case UInt32(kVK_F16): return "F16"
        case UInt32(kVK_F17): return "F17"
        case UInt32(kVK_F18): return "F18"
        case UInt32(kVK_F19): return "F19"
        case UInt32(kVK_F20): return "F20"
        case UInt32(kVK_Space): return "Space"
        case UInt32(kVK_Return): return "Return"
        case UInt32(kVK_Tab): return "Tab"
        case UInt32(kVK_Delete): return "Delete"
        case UInt32(kVK_Escape): return "Esc"
        default:
            guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
                  let rawData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
            else {
                return "Key\(keyCode)"
            }

            let data = unsafeBitCast(rawData, to: CFData.self) as Data
            return data.withUnsafeBytes { bytes -> String in
                guard let layoutData = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                    return "Key\(keyCode)"
                }

                var deadKeyState: UInt32 = 0
                var chars: [UniChar] = [0, 0, 0, 0]
                var length: Int = 0
                let status = UCKeyTranslate(
                    layoutData,
                    UInt16(keyCode),
                    UInt16(kUCKeyActionDisplay),
                    0,
                    UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit),
                    &deadKeyState,
                    chars.count,
                    &length,
                    &chars
                )

                guard status == noErr, length > 0 else { return "Key\(keyCode)" }
                return String(utf16CodeUnits: chars, count: length).uppercased()
            }
        }
    }

    static func from(event: NSEvent) -> Hotkey? {
        let keyCode = UInt32(event.keyCode)
        let relevantFlags = event.modifierFlags.intersection([.command, .option, .shift, .control, .function])

        var modifiers: UInt32 = 0
        if relevantFlags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if relevantFlags.contains(.option) { modifiers |= UInt32(optionKey) }
        if relevantFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if relevantFlags.contains(.control) { modifiers |= UInt32(controlKey) }
        if relevantFlags.contains(.function) { modifiers |= Hotkey.fnModifierMask }

        let hotkey = Hotkey(keyCode: keyCode, modifiers: modifiers)
        return hotkey.isValidGlobalShortcut ? hotkey : nil
    }
}
