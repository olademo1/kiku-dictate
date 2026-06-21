import AppKit
import Foundation

struct ApplicationInstallSuggestion {
    let sourceURL: URL
    let destinationURL: URL
    let skippedFingerprint: String

    var destinationLabel: String {
        destinationURL.deletingLastPathComponent().path
    }
}

enum ApplicationInstallService {
    private static let skippedMoveKey = "dataiku_chirp_skipped_move_to_applications"
    private static let appBundleName = "Dataiku Chirp.app"

    static func suggestion() -> ApplicationInstallSuggestion? {
        let sourceURL = Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath()
        guard sourceURL.pathExtension == "app" else { return nil }
        guard !isRunningFromApplications(sourceURL) else { return nil }

        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let fingerprint = "\(sourceURL.path)|\(build)"
        guard UserDefaults.standard.string(forKey: skippedMoveKey) != fingerprint else { return nil }

        let destinationRoot = preferredApplicationsRoot()
        let destinationURL = destinationRoot.appendingPathComponent(appBundleName, isDirectory: true)

        if destinationURL.resolvingSymlinksInPath().path == sourceURL.path {
            return nil
        }

        return ApplicationInstallSuggestion(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            skippedFingerprint: fingerprint
        )
    }

    static func markSkipped(_ suggestion: ApplicationInstallSuggestion) {
        UserDefaults.standard.set(suggestion.skippedFingerprint, forKey: skippedMoveKey)
    }

    static func install(_ suggestion: ApplicationInstallSuggestion) async throws -> URL {
        try await Task.detached(priority: .utility) {
            try copyBundle(from: suggestion.sourceURL, to: suggestion.destinationURL)
            return suggestion.destinationURL
        }.value
    }

    private static func isRunningFromApplications(_ sourceURL: URL) -> Bool {
        let sourcePath = sourceURL.path
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true)
            .resolvingSymlinksInPath()
            .path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .resolvingSymlinksInPath()
            .path

        return sourcePath.hasPrefix(systemApplications + "/") || sourcePath.hasPrefix(userApplications + "/")
    }

    private static func preferredApplicationsRoot() -> URL {
        let fileManager = FileManager.default
        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true)

        if fileManager.isWritableFile(atPath: systemApplications.path) {
            return systemApplications
        }

        let userApplications = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
        try? fileManager.createDirectory(at: userApplications, withIntermediateDirectories: true)
        return userApplications
    }

    private static func copyBundle(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let destinationParent = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationParent, withIntermediateDirectories: true)

        let temporaryURL = destinationParent.appendingPathComponent(
            ".\(appBundleName).installing-\(UUID().uuidString)",
            isDirectory: true
        )

        try? fileManager.removeItem(at: temporaryURL)
        defer { try? fileManager.removeItem(at: temporaryURL) }

        try runDitto(from: sourceURL, to: temporaryURL)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: temporaryURL, to: destinationURL)
    }

    private static func runDitto(from sourceURL: URL, to destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["--norsrc", sourceURL.path, destinationURL.path]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8) ?? "ditto failed"
            throw NSError(
                domain: "ApplicationInstallService",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: errorText.trimmingCharacters(in: .whitespacesAndNewlines)]
            )
        }
    }
}
