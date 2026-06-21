import Carbon
import Foundation

final class HotkeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var eventHandlerUPP: EventHandlerUPP?

    deinit {
        unregister()
    }

    func register(hotkey: Hotkey) throws {
        unregister()

        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        eventHandlerUPP = { _, eventRef, userData in
            guard let eventRef, let userData else { return noErr }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
            let kind = GetEventKind(eventRef)

            switch kind {
            case UInt32(kEventHotKeyPressed):
                monitor.onPress?()
            case UInt32(kEventHotKeyReleased):
                monitor.onRelease?()
            default:
                break
            }

            return noErr
        }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        guard let upp = eventHandlerUPP else {
            throw NSError(domain: "HotkeyMonitor", code: 1)
        }

        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            upp,
            2,
            &eventTypes,
            pointer,
            &eventHandler
        )

        guard installStatus == noErr else {
            throw NSError(domain: "HotkeyMonitor", code: Int(installStatus))
        }

        let hotKeyID = EventHotKeyID(signature: OSType(bitPattern: 0x43524448), id: UInt32(1))
        let registerStatus = RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            UInt32(hotkey.modifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            throw NSError(domain: "HotkeyMonitor", code: Int(registerStatus))
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }

        eventHandlerUPP = nil
    }
}
