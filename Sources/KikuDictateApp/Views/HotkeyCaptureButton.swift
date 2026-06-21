import AppKit
import Carbon
import SwiftUI

struct HotkeyCaptureButton: View {
    let currentHotkey: Hotkey
    let allowSingleKey: Bool
    let onUpdate: (Hotkey) -> Void
    let onCaptureStateChange: (Bool) -> Void
    let onInvalidCapture: () -> Void

    @State private var isCapturing = false

    var body: some View {
        Group {
            if isCapturing {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.orange)
                    Text("Press shortcut...")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 8)
                    Button("Cancel") {
                        stopCapture()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(width: 190)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.55)))
                .background(ShortcutCaptureView(onKeyDown: capture(event:)).frame(width: 0, height: 0))
            } else {
                HStack(spacing: 8) {
                    Text(currentHotkey.displayValue)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer(minLength: 8)
                    Button("Change") {
                        startCapture()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 190)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.12)))
            }
        }
        .onDisappear {
            stopCapture()
        }
    }

    private func startCapture() {
        isCapturing = true
        onCaptureStateChange(true)
    }

    private func capture(event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopCapture()
            return
        }

        if [UInt16(kVK_Command), UInt16(kVK_RightCommand),
            UInt16(kVK_Shift), UInt16(kVK_RightShift),
            UInt16(kVK_Control), UInt16(kVK_RightControl),
            UInt16(kVK_Option), UInt16(kVK_RightOption),
            UInt16(kVK_Function)].contains(event.keyCode) {
            return
        }

        guard let hotkey = Hotkey.from(event: event, allowSingleKey: allowSingleKey) else {
            NSSound.beep()
            onInvalidCapture()
            return
        }

        onUpdate(hotkey)
        stopCapture()
    }

    private func stopCapture() {
        guard isCapturing else { return }
        isCapturing = false
        onCaptureStateChange(false)
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    final class CaptureNSView: NSView {
        var onKeyDown: ((NSEvent) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            onKeyDown?(event)
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard event.type == .keyDown else { return false }
            onKeyDown?(event)
            return true
        }
    }
}
