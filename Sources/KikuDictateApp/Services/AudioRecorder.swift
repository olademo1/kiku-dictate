import AVFoundation
import Foundation

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case notRecording
    case recorderUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required."
        case .notRecording:
            return "No recording is currently in progress."
        case .recorderUnavailable:
            return "Could not start the recorder. Check that an input device is available."
        }
    }
}

final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var startedAt: Date?
    private var outputURL: URL?

    func requestPermission() async -> Bool {
        let state = MicrophonePermissionState.current()
        if state.isGranted {
            return true
        }

        if #available(macOS 14.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    func startRecording() throws {
        guard MicrophonePermissionState.current().isGranted else {
            throw AudioRecorderError.permissionDenied
        }

        let tempDir = FileManager.default.temporaryDirectory
        let output = tempDir.appendingPathComponent("kiku-dictate-\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let recorder = try AVAudioRecorder(url: output, settings: settings)
        recorder.isMeteringEnabled = false
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw AudioRecorderError.recorderUnavailable
        }

        self.recorder = recorder
        startedAt = Date()
        outputURL = output
    }

    func stopRecording() throws -> (url: URL, duration: TimeInterval) {
        guard let outputURL, let startedAt else {
            throw AudioRecorderError.notRecording
        }

        recorder?.stop()
        recorder = nil

        let duration = Date().timeIntervalSince(startedAt)

        self.outputURL = nil
        self.startedAt = nil

        return (outputURL, duration)
    }

    func cancelRecording() {
        recorder?.stop()
        recorder = nil

        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }

        outputURL = nil
        startedAt = nil
    }
}
