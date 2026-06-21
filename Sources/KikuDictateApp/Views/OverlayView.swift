import SwiftUI

struct OverlayView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 5) {
            if viewModel.isRecording {
                Button {
                    viewModel.cancelRecordingFromOverlay()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 16, height: 16)
                        .padding(4)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 16, height: 16)
            }

            if viewModel.isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else if viewModel.isRecording {
                WaveformView()
                    .frame(width: 44, height: 10)

                Text(formattedDuration(viewModel.recordingDuration))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            Button {
                viewModel.overlayPrimaryAction()
            } label: {
                Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(viewModel.isRecording ? Color.red : Color.green))
                    .foregroundStyle(.black)
                    .padding(4)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing || !viewModel.setupComplete)
        }
        .padding(.horizontal, 6)
        .frame(width: 150, height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.85))
        )
        .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
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
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let minutes = total / 60
        let remaining = total % 60
        return String(format: "%d:%02d", minutes, remaining)
    }
}

private struct WaveformView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 1.3) {
                ForEach(0..<8, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 1.6, height: barHeight(index: index, time: t))
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        let phase = time * 6 + Double(index) * 0.4
        let wave = abs(sin(phase))
        return CGFloat(2 + wave * 4)
    }
}
