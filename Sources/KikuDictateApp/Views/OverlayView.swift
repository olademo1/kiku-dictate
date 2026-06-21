import SwiftUI

struct OverlayView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 9) {
            leadingStatus

            VStack(alignment: .leading, spacing: 1) {
                Text(statusTitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(OverlayPalette.ink)
                    .lineLimit(1)

                if viewModel.isRecording {
                    Text(formattedDuration(viewModel.recordingDuration))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(OverlayPalette.green)
                } else {
                    Text(statusSubtitle)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(OverlayPalette.muted)
                        .lineLimit(1)
                }
            }
            .frame(width: 58, alignment: .leading)

            Spacer(minLength: 0)

            primaryButton
        }
        .padding(.leading, 8)
        .padding(.trailing, 7)
        .frame(width: 184, height: 42)
        .background(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(OverlayPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(OverlayPalette.green.opacity(0.26), lineWidth: 1)
        )
        .shadow(color: OverlayPalette.green.opacity(0.18), radius: 16, x: 0, y: 8)
        .shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .onTapGesture {
            handlePillTap()
        }
    }

    private var leadingStatus: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(viewModel.isRecording ? OverlayPalette.green.opacity(0.14) : OverlayPalette.mint)
                .frame(width: 43, height: 28)

            if viewModel.isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .tint(OverlayPalette.green)
            } else {
                WaveformView(isActive: viewModel.isRecording)
                    .frame(width: 28, height: 16)
            }
        }
    }

    private var primaryButton: some View {
        HStack(spacing: 4) {
            if viewModel.isRecording {
                Button {
                    viewModel.cancelRecordingFromOverlay()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .frame(width: 22, height: 22)
                        .foregroundStyle(OverlayPalette.muted)
                        .background(Circle().fill(OverlayPalette.surfaceInset))
                }
                .buttonStyle(.plain)
            }

            Button {
                viewModel.overlayPrimaryAction()
            } label: {
                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.white)
                    .background(Circle().fill(actionColor))
                    .shadow(color: actionColor.opacity(0.28), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing || !viewModel.setupComplete)
            .opacity(viewModel.isProcessing || !viewModel.setupComplete ? 0.45 : 1)
        }
    }

    private var statusTitle: String {
        if viewModel.isProcessing { return "Local" }
        if viewModel.isRecording { return "Listening" }
        if !viewModel.setupComplete { return "Setup" }
        return "Ready"
    }

    private var statusSubtitle: String {
        if viewModel.isProcessing { return "transcribing" }
        if !viewModel.setupComplete { return "open app" }
        return "dictate"
    }

    private var actionColor: Color {
        if viewModel.isRecording { return OverlayPalette.red }
        return OverlayPalette.green
    }

    private func handlePillTap() {
        guard !viewModel.isProcessing else { return }

        guard viewModel.setupComplete else {
            viewModel.refreshSetupStatus(showReadyMessage: false)
            if !viewModel.engineReady {
                viewModel.statusMessage = "Setup needed: install the local Whisper engine."
            } else if !viewModel.modelReady {
                viewModel.statusMessage = "Setup needed: add the local model file."
            } else if !viewModel.hasMicrophonePermission {
                viewModel.statusMessage = "Setup needed: enable microphone permission."
            } else {
                viewModel.statusMessage = "Setup needed: finish setup in the main window."
            }
            viewModel.bringMainWindowToFront()
            return
        }

        viewModel.overlayPrimaryAction()
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let minutes = total / 60
        let remaining = total % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}

private enum OverlayPalette {
    static let surface = Color(red: 0.985, green: 0.992, blue: 0.965)
    static let surfaceInset = Color(red: 0.930, green: 0.955, blue: 0.920)
    static let mint = Color(red: 0.870, green: 0.960, blue: 0.920)
    static let ink = Color(red: 0.060, green: 0.090, blue: 0.130)
    static let muted = Color(red: 0.380, green: 0.440, blue: 0.460)
    static let green = Color(red: 0.000, green: 0.560, blue: 0.430)
    static let red = Color(red: 0.820, green: 0.240, blue: 0.210)
}

private struct WaveformView: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !isActive)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.2) {
                ForEach(0..<7, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(index: index))
                        .frame(width: 2.4, height: barHeight(index: index, time: t))
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func barColor(index: Int) -> Color {
        if isActive {
            return OverlayPalette.green
        }
        return index == 1 || index == 5
            ? OverlayPalette.green.opacity(0.80)
            : OverlayPalette.ink.opacity(0.72)
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isActive else {
            return CGFloat([5, 10, 7, 14, 8, 11, 6][index])
        }

        let phase = time * 6 + Double(index) * 0.55
        let wave = abs(sin(phase))
        return CGFloat(5 + wave * 11)
    }
}
