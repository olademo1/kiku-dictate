import AppKit
import ApplicationServices
import Foundation

enum PasteInjectorError: LocalizedError {
    case accessibilityPermissionRequired
    case eventSourceUnavailable
    case pasteShortcutUnavailable

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            return "Enable Accessibility for Kiku Dictate to paste automatically."
        case .eventSourceUnavailable:
            return "Could not create an input event source for auto-paste."
        case .pasteShortcutUnavailable:
            return "Could not generate the Cmd+V paste shortcut event."
        }
    }
}

final class PasteInjector {
    func ensureAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted() || ensureAccessibilityPermission(prompt: false)
    }

    @discardableResult
    func requestAccessibilityPermissionIfNeeded() -> Bool {
        if hasAccessibilityPermission() {
            return true
        }
        return ensureAccessibilityPermission(prompt: true)
    }

    @discardableResult
    func paste(_ text: String) throws -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard hasAccessibilityPermission() else {
            throw PasteInjectorError.accessibilityPermissionRequired
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw PasteInjectorError.eventSourceUnavailable
        }

        // virtualKey 9 is "V" on US keyboards (kVK_ANSI_V). Using the key code keeps this
        // working even when the clipboard contains non-ASCII.
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            throw PasteInjectorError.pasteShortcutUnavailable
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        // Posting to the session tap is generally sufficient and can be more reliable than HID.
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        return true
    }
}
