import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController: NSWindowController {
    private let panel: NSPanel

    init(viewModel: AppViewModel) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 184, height: 48),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let hosting = NSHostingView(rootView: OverlayView(viewModel: viewModel))
        hosting.wantsLayer = true
        panel.contentView = hosting

        super.init(window: panel)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reposition),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    @objc private func reposition() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame

        let width: CGFloat = 184
        let height: CGFloat = 48
        let x = frame.midX - (width / 2)
        let y = frame.minY + 24

        let targetFrame = NSRect(x: x, y: y, width: width, height: height)
        if panel.frame != targetFrame {
            panel.setFrame(targetFrame, display: true)
        }
    }
}
