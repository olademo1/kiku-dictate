import Foundation

struct LocalTranscriptionResult: Equatable {
    let text: String
    let wordCount: Int
}

enum LocalWhisperTranscriberError: LocalizedError {
    case engineMissing(String)
    case modelMissing(String)
    case audioMissing(String)
    case commandFailed(String)
    case transcriptMissing

    var errorDescription: String? {
        switch self {
        case .engineMissing(let path):
            return "Local Whisper engine not found at \(path)."
        case .modelMissing(let path):
            return "Local Whisper model not found at \(path)."
        case .audioMissing(let path):
            return "Recorded audio not found at \(path)."
        case .commandFailed(let message):
            return "Local transcription failed. \(message)"
        case .transcriptMissing:
            return "Local transcription finished without producing text."
        }
    }
}

final class LocalWhisperTranscriber {
    func transcribe(audioURL: URL, settings: LocalModelSettings) async throws -> LocalTranscriptionResult {
        try await Task.detached(priority: .userInitiated) {
            try Self.transcribeSynchronously(audioURL: audioURL, settings: settings)
        }.value
    }

    private static func transcribeSynchronously(
        audioURL: URL,
        settings: LocalModelSettings
    ) throws -> LocalTranscriptionResult {
        let fileManager = FileManager.default

        guard fileManager.isExecutableFile(atPath: settings.enginePath) else {
            throw LocalWhisperTranscriberError.engineMissing(settings.enginePath)
        }
        guard fileManager.fileExists(atPath: settings.modelPath) else {
            throw LocalWhisperTranscriberError.modelMissing(settings.modelPath)
        }
        guard fileManager.fileExists(atPath: audioURL.path) else {
            throw LocalWhisperTranscriberError.audioMissing(audioURL.path)
        }

        let outputBase = fileManager.temporaryDirectory
            .appendingPathComponent("dataiku-chirp-\(UUID().uuidString)")
        let outputText = outputBase.appendingPathExtension("txt")

        defer {
            try? fileManager.removeItem(at: outputText)
        }

        let result = runProcess(
            executablePath: settings.enginePath,
            arguments: [
                "-m", settings.modelPath,
                "-f", audioURL.path,
                "-l", settings.languageCode,
                "-otxt",
                "-of", outputBase.path,
                "-nt",
                "-np"
            ]
        )

        guard result.exitCode == 0 else {
            throw LocalWhisperTranscriberError.commandFailed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let text: String
        if let fileText = try? String(contentsOf: outputText, encoding: .utf8),
           !fileText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = fileText
        } else if !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = result.stdout
        } else {
            throw LocalWhisperTranscriberError.transcriptMissing
        }

        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw LocalWhisperTranscriberError.transcriptMissing
        }

        let words = cleaned.split { $0.isWhitespace || $0.isNewline }.count
        return LocalTranscriptionResult(text: cleaned, wordCount: words)
    }

    private static func runProcess(executablePath: String, arguments: [String]) -> (exitCode: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (1, "", error.localizedDescription)
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, stdout, stderr)
    }
}
