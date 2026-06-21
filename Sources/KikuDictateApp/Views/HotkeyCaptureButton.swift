import SwiftUI
import Carbon

struct HotkeyCaptureButton: View {
    let currentHotkey: Hotkey
    let onUpdate: (Hotkey) -> Void
    let onCaptureStateChange: (Bool) -> Void
    let onInvalidCapture: () -> Void

    @State private var isCapturing = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    var body: some View {
        Button(action: toggleCapture) {
            Text(isCapturing ? "Press new shortcut..." : currentHotkey.displayValue)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .frame(minWidth: 180)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(isCapturing ? .orange : .accentColor)
        .onDisappear {
            stopCapture()
        }
    }

    private func toggleCapture() {
        if isCapturing {
            stopCapture()
        } else {
            startCapture()
        }
    }

    private func startCapture() {
        isCapturing = true
        onCaptureStateChange(true)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            capture(event: event)
            return nil
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            capture(event: event)
        }
    }

    private func capture(event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopCapture()
            return
        }

        // Ignore modifier-only key presses while capturing.
        if [UInt16(kVK_Command), UInt16(kVK_RightCommand),
            UInt16(kVK_Shift), UInt16(kVK_RightShift),
            UInt16(kVK_Control), UInt16(kVK_RightControl),
            UInt16(kVK_Option), UInt16(kVK_RightOption),
            UInt16(kVK_Function)].contains(event.keyCode) {
            return
        }

        guard let hotkey = Hotkey.from(event: event) else {
            NSSound.beep()
            onInvalidCapture()
            return
        }

        onUpdate(hotkey)
        stopCapture()
    }

    private func stopCapture() {
        isCapturing = false
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        onCaptureStateChange(false)
    }
}
