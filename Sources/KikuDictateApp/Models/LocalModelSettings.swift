import Foundation

struct LocalModelSettings: Codable, Equatable {
    var enginePath: String
    var modelPath: String
    var modelName: String
    var languageCode: String

    static let defaultModelFileName = "ggml-large-v3-turbo.bin"

    static var `default`: LocalModelSettings {
        let bundledEngineURL = Bundle.main.url(
            forResource: "whisper-cli",
            withExtension: nil,
            subdirectory: "Runtime/bin"
        )
        let bundledModelURL = Bundle.main.url(
            forResource: defaultModelFileName,
            withExtension: nil,
            subdirectory: "Models"
        )
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let defaultModelURL = appSupport
            .appendingPathComponent(AppConstants.appSupportFolder, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(defaultModelFileName)
        let legacyModelURL = appSupport
            .appendingPathComponent(AppConstants.legacyAppSupportFolder, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(defaultModelFileName)
        let modelURL = FileManager.default.fileExists(atPath: defaultModelURL.path) ? defaultModelURL : legacyModelURL
        let bundledEnginePath = bundledEngineURL?.path
        let bundledModelPath = bundledModelURL?.path

        return LocalModelSettings(
            enginePath: Self.firstExistingExecutablePath([
                bundledEnginePath,
                "/opt/homebrew/bin/whisper-cli",
                "/usr/local/bin/whisper-cli",
                "/opt/homebrew/bin/whisper-cpp",
                "/usr/local/bin/whisper-cpp"
            ]) ?? "/opt/homebrew/bin/whisper-cli",
            modelPath: Self.firstExistingFilePath([
                bundledModelPath,
                modelURL.path,
                defaultModelURL.path
            ]) ?? defaultModelURL.path,
            modelName: "Whisper large-v3 turbo",
            languageCode: "en"
        )
    }

    var engineExists: Bool {
        FileManager.default.isExecutableFile(atPath: enginePath)
    }

    var modelExists: Bool {
        FileManager.default.fileExists(atPath: modelPath)
    }

    var isReady: Bool {
        engineExists && modelExists
    }

    private static func firstExistingExecutablePath(_ paths: [String?]) -> String? {
        paths.compactMap(\.self).first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func firstExistingFilePath(_ paths: [String?]) -> String? {
        paths.compactMap(\.self).first { FileManager.default.fileExists(atPath: $0) }
    }
}
