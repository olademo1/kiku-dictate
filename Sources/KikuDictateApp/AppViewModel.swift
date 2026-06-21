import AppKit
import AVFoundation
import Foundation

enum RecordingMode {
    case none
    case persistent
    case pushToTalk
}

enum PersistentStartMode: String, CaseIterable, Identifiable {
    case singlePress
    case doublePress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singlePress: return "Single Press"
        case .doublePress: return "Double Press"
        }
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var hotkey: Hotkey
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var statusMessage = "Ready"
    @Published var hasMicrophonePermission = false
    @Published var microphonePermissionState: MicrophonePermissionState = .unknown
    @Published var hasAccessibilityPermission = false
    @Published var setupComplete = false
    @Published var autoPasteReady = false
    @Published var currentAppPath = ""
    @Published var runningFromApplications = false
    @Published var launchAtLoginEnabled = false
    @Published var overlayPillVisible = true
    @Published var allowSingleKeyShortcuts = false
    @Published var isCapturingHotkey = false
    @Published var usageStoragePath = ""
    @Published var usageSummary = UsageSummary.empty
    @Published var usagePricingNote = UsagePricing.note
    @Published var persistentStartMode: PersistentStartMode
    @Published var localModelSettings: LocalModelSettings
    @Published var globalUsageSettings: GlobalUsageSettings
    @Published var globalUsageSnapshot = GlobalUsageSnapshot.empty
    @Published var globalUsageStatus = "Team stats sharing is off."
    @Published var isSyncingGlobalUsage = false

    private let hotkeyStore = HotkeyStore()
    private let hotkeyMonitor = HotkeyMonitor()
    private let modelSettingsStore = LocalModelSettingsStore()
    private let usageStore = UsageStore()
    private let globalUsageSettingsStore = GlobalUsageSettingsStore()
    private let globalUsageClient = GlobalUsageClient()
    private let recorder = AudioRecorder()
    private let transcriber = LocalWhisperTranscriber()
    private let pasteInjector = PasteInjector()
    private let launchService: LaunchAtLoginService? = {
        if #available(macOS 13.0, *) {
            return LaunchAtLoginService()
        }
        return nil
    }()

    private let doubleTapWindow: TimeInterval = 0.36
    private let holdThreshold: UInt64 = 220_000_000
    private let minDuration: TimeInterval = 0.7
    private let persistentStartModeKey = "kiku_dictate_persistent_start_mode"
    private let overlayPillVisibleKey = "kiku_dictate_overlay_pill_visible"
    private let allowSingleKeyShortcutsKey = "kiku_dictate_allow_single_key_shortcuts"
    private let userApplicationsRoot: String = {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }()

    private var recordingMode: RecordingMode = .none
    private var recordingStartedAt: Date?
    private var overlayController: OverlayWindowController?
    private var usageRecords: [UsageRecord] = []

    private var isHotkeyDown = false
    private var firstTapDate: Date?
    private var clearTapTask: Task<Void, Never>?
    private var holdTask: Task<Void, Never>?
    private var durationTask: Task<Void, Never>?
    private var globalUsageSyncTask: Task<Void, Never>?
    private var appActivatedObserver: Any?
    private var accessibilityRefreshTask: Task<Void, Never>?

    init() {
        let storedMode = UserDefaults.standard.string(forKey: persistentStartModeKey)
        persistentStartMode = PersistentStartMode(rawValue: storedMode ?? "") ?? .singlePress
        if UserDefaults.standard.object(forKey: overlayPillVisibleKey) as? Bool == false {
            overlayPillVisible = false
        }
        let storedAllowSingleKeyShortcuts = UserDefaults.standard.bool(forKey: allowSingleKeyShortcutsKey)
        allowSingleKeyShortcuts = storedAllowSingleKeyShortcuts
        hotkey = hotkeyStore.load(allowSingleKey: storedAllowSingleKeyShortcuts)
        localModelSettings = modelSettingsStore.load()
        globalUsageSettings = globalUsageSettingsStore.load()
        usageRecords = usageStore.load()
        usageStoragePath = usageStore.location.path
        usageSummary = UsageSummary.from(records: usageRecords)
        currentAppPath = Bundle.main.bundlePath
        launchAtLoginEnabled = launchService?.isEnabled() ?? false
        refreshSetupStatus(showReadyMessage: false)

        wireHotkeyCallbacks()

        registerInitialHotkey()

        applyOverlayPillVisibility()
        refreshGlobalUsageStatus()

        if globalUsageSettings.isConfigured {
            refreshGlobalUsage()
        }

        appActivatedObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshSetupStatus(showReadyMessage: true)
            }
        }
    }

    deinit {
        clearTapTask?.cancel()
        holdTask?.cancel()
        durationTask?.cancel()
        globalUsageSyncTask?.cancel()
        accessibilityRefreshTask?.cancel()
        if let appActivatedObserver {
            NotificationCenter.default.removeObserver(appActivatedObserver)
            self.appActivatedObserver = nil
        }
        hotkeyMonitor.unregister()
    }

    var engineReady: Bool {
        localModelSettings.engineExists
    }

    var modelReady: Bool {
        localModelSettings.modelExists
    }

    var modelFolderPath: String {
        URL(fileURLWithPath: localModelSettings.modelPath).deletingLastPathComponent().path
    }

    var modelFileName: String {
        URL(fileURLWithPath: localModelSettings.modelPath).lastPathComponent
    }

    var modelSizeDescription: String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: localModelSettings.modelPath),
              let size = attributes[.size] as? NSNumber
        else {
            return modelReady ? "Local file" : "Missing"
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB]
        return formatter.string(fromByteCount: size.int64Value)
    }

    var modelSummary: String {
        "\(localModelSettings.modelName) - \(modelSizeDescription)"
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "local"
        return "\(version) (\(build))"
    }

    func updateEnginePath(_ path: String) {
        var next = localModelSettings
        next.enginePath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        saveModelSettings(next)
    }

    func updateModelPath(_ path: String) {
        var next = localModelSettings
        next.modelPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        saveModelSettings(next)
    }

    func updateModelName(_ name: String) {
        var next = localModelSettings
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        next.modelName = cleaned.isEmpty ? URL(fileURLWithPath: next.modelPath).lastPathComponent : cleaned
        saveModelSettings(next)
    }

    func resetModelSettings() {
        saveModelSettings(.default)
        statusMessage = "Local model settings reset."
    }

    func openModelFolder() {
        let url = URL(fileURLWithPath: modelFolderPath)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    func copyInstallCommands() {
        let command = """
        brew install whisper-cpp
        mkdir -p "\(modelFolderPath)"
        curl -L "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin" -o "\(localModelSettings.modelPath)"
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        statusMessage = "Local model install commands copied."
    }

    func updateGlobalUsageEndpoint(_ value: String) {
        var next = globalUsageSettings
        next.endpointURLString = value.trimmingCharacters(in: .whitespacesAndNewlines)
        saveGlobalUsageSettings(next)
    }

    func updateGlobalUsageTeamKey(_ value: String) {
        var next = globalUsageSettings
        next.teamKey = value.trimmingCharacters(in: .whitespacesAndNewlines)
        saveGlobalUsageSettings(next)
    }

    func setGlobalUsageSharing(_ enabled: Bool) {
        var next = globalUsageSettings
        next.enabled = enabled
        saveGlobalUsageSettings(next)

        if enabled {
            syncGlobalUsageNow()
        } else {
            globalUsageStatus = "Team stats sharing is off."
        }
    }

    func refreshGlobalUsage() {
        globalUsageSyncTask?.cancel()
        globalUsageSyncTask = Task { [weak self] in
            guard let self else { return }
            await self.fetchGlobalUsageSnapshot()
        }
    }

    func syncGlobalUsageNow() {
        globalUsageSyncTask?.cancel()
        globalUsageSyncTask = Task { [weak self] in
            guard let self else { return }
            await self.syncGlobalUsage(force: true)
        }
    }

    func updateHotkey(_ newHotkey: Hotkey) {
        guard newHotkey.isValidGlobalShortcut(allowSingleKey: allowSingleKeyShortcuts) else {
            hotkeyCaptureInvalid()
            return
        }

        let previousHotkey = hotkey

        do {
            try hotkeyMonitor.register(hotkey: newHotkey)
            hotkey = newHotkey
            hotkeyStore.save(newHotkey)
            statusMessage = "Hotkey updated to \(newHotkey.displayValue)."
        } catch {
            try? hotkeyMonitor.register(hotkey: previousHotkey)
            statusMessage = "That shortcut is already used by macOS or another app. Pick a different shortcut."
        }
    }

    func setHotkeyCapture(active: Bool) {
        isCapturingHotkey = active
        if active {
            hotkeyMonitor.unregister()
            statusMessage = "Press any key or combo. Esc cancels."
        } else {
            do {
                try hotkeyMonitor.register(hotkey: hotkey)
                statusMessage = "Hotkey ready: \(hotkey.displayValue)."
            } catch {
                statusMessage = "Could not register hotkey."
            }
        }
    }

    func hotkeyCaptureInvalid() {
        statusMessage = allowSingleKeyShortcuts
            ? "That key cannot be used as a shortcut."
            : "Use Control, Option, or Command, or turn on 1-key."
    }

    func setPersistentStartMode(_ mode: PersistentStartMode) {
        persistentStartMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: persistentStartModeKey)
        let description = mode == .singlePress ? "single press" : "double press"
        statusMessage = "Persistent recording trigger set to \(description)."
    }

    func requestMicrophonePermission() async {
        refreshSetupStatus(showReadyMessage: false)

        switch microphonePermissionState {
        case .denied:
            statusMessage = "Microphone permission is denied. Enable Dataiku Chirp in System Settings > Privacy & Security > Microphone."
            return
        case .restricted:
            statusMessage = "Microphone access is restricted by system policy."
            return
        default:
            break
        }

        statusMessage = "Requesting microphone permission..."
        let granted = await recorder.requestPermission()
        refreshSetupStatus(showReadyMessage: false)

        if granted {
            statusMessage = "Microphone enabled."
            return
        }

        switch microphonePermissionState {
        case .denied:
            statusMessage = "Microphone permission is denied. Enable Dataiku Chirp in System Settings > Privacy & Security > Microphone."
        case .restricted:
            statusMessage = "Microphone access is restricted by system policy."
        case .undetermined:
            statusMessage = "Microphone permission is still not granted. Try again, then check System Settings > Privacy & Security > Microphone."
        case .granted:
            statusMessage = "Microphone enabled."
        case .unknown:
            statusMessage = "Microphone permission is required to record."
        }
    }

    func requestAccessibilityPermission() {
        let granted = pasteInjector.requestAccessibilityPermissionIfNeeded()
        refreshSetupStatus(showReadyMessage: granted)
        if granted {
            statusMessage = "Accessibility is enabled."
        } else if !hasAccessibilityPermission {
            statusMessage = "Enable Accessibility for Dataiku Chirp in System Settings, then relaunch Dataiku Chirp."
            startAccessibilityRefreshWindow()
        }
    }

    func openAccessibilitySettings() {
        let opened = openSystemSettings(urlStrings: [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        ])
        if !opened {
            statusMessage = "Could not open System Settings. Open Privacy & Security > Accessibility manually."
        }
        startAccessibilityRefreshWindow()
    }

    func openMicrophoneSettings() {
        let opened = openSystemSettings(urlStrings: [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Microphone",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        ])
        if !opened {
            statusMessage = "Could not open System Settings. Open Privacy & Security > Microphone manually."
        }
    }

    func relaunchApp() {
        let appURL = Bundle.main.bundleURL
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            NSApp.terminate(nil)
        }
    }

    func bringMainWindowToFront() {
        NSApp.activate(ignoringOtherApps: true)
        let candidates = NSApp.windows.filter { !($0 is NSPanel) }
        if let window = candidates.first(where: { $0.title.contains("Dataiku Chirp") }) ?? candidates.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func copyDiagnostics() {
        refreshSetupStatus(showReadyMessage: false)

        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let diagnostics = """
        Dataiku Chirp Diagnostics
        Bundle ID: \(bundleId)
        Version: \(version)
        Build: \(build)
        App path: \(currentAppPath)
        Running from Applications: \(runningFromApplications)
        Microphone permission: \(microphonePermissionState.label)
        Accessibility permission: \(hasAccessibilityPermission)
        Engine path: \(localModelSettings.enginePath)
        Engine ready: \(engineReady)
        Model path: \(localModelSettings.modelPath)
        Model ready: \(modelReady)
        """

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
        statusMessage = "Diagnostics copied to clipboard."
    }

    func refreshSetupStatus(showReadyMessage: Bool) {
        let resolvedPath = normalizedPath(Bundle.main.bundlePath)
        let inApplications = resolvedPath.hasPrefix("/Applications/")
        let inUserApplications = resolvedPath.hasPrefix(userApplicationsRoot + "/")
        let isTranslocated = resolvedPath.contains("/AppTranslocation/")
        let newMicrophonePermissionState = MicrophonePermissionState.current()
        let newHasMicrophonePermission = newMicrophonePermissionState.isGranted
        let newHasAccessibilityPermission = pasteInjector.hasAccessibilityPermission()

        publishIfChanged(\.currentAppPath, resolvedPath)
        publishIfChanged(\.runningFromApplications, (inApplications || inUserApplications) && !isTranslocated)
        publishIfChanged(\.microphonePermissionState, newMicrophonePermissionState)
        publishIfChanged(\.hasMicrophonePermission, newHasMicrophonePermission)
        publishIfChanged(\.hasAccessibilityPermission, newHasAccessibilityPermission)
        publishIfChanged(\.autoPasteReady, newHasAccessibilityPermission)
        publishIfChanged(\.setupComplete, localModelSettings.isReady && newHasMicrophonePermission)

        if showReadyMessage && setupComplete {
            if autoPasteReady {
                publishIfChanged(\.statusMessage, "Setup complete. Local dictation is ready.")
            } else {
                publishIfChanged(\.statusMessage, "Setup complete. Auto-paste is off until Accessibility is enabled.")
            }
        }
    }

    func refreshSetupFromUI() {
        refreshSetupStatus(showReadyMessage: false)

        var warnings: [String] = []
        if !runningFromApplications {
            if currentAppPath.contains("/AppTranslocation/") {
                warnings.append("This copy is running from a translocated path. Move it to /Applications or ~/Applications and reopen.")
            } else {
                warnings.append("Not running from /Applications or ~/Applications, so permissions may not stick.")
            }
        }

        if !engineReady {
            statusMessage = (["Setup incomplete: install whisper.cpp or set the engine path."] + warnings).joined(separator: " ")
            return
        }

        if !modelReady {
            statusMessage = (["Setup incomplete: add the local model file."] + warnings).joined(separator: " ")
            return
        }

        if !hasMicrophonePermission {
            let base: String
            switch microphonePermissionState {
            case .undetermined:
                base = "Setup incomplete: click Enable Microphone."
            case .denied:
                base = "Setup incomplete: microphone permission is denied."
            case .restricted:
                base = "Setup incomplete: microphone access is restricted by system policy."
            case .unknown:
                base = "Setup incomplete: microphone permission is required."
            case .granted:
                base = "Setup incomplete: microphone permission is required."
            }
            statusMessage = ([base] + warnings).joined(separator: " ")
            return
        }

        if hasAccessibilityPermission {
            statusMessage = (["Local transcription is ready. Auto-paste is enabled."] + warnings).joined(separator: " ")
            return
        }

        _ = pasteInjector.requestAccessibilityPermissionIfNeeded()
        startAccessibilityRefreshWindow()
        statusMessage = (["Local transcription is ready. Enable Accessibility for auto-paste."] + warnings).joined(separator: " ")
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard let launchService else {
            launchAtLoginEnabled = false
            statusMessage = "Launch at login is unavailable on this macOS version."
            return
        }

        do {
            try launchService.setEnabled(enabled)
            launchAtLoginEnabled = enabled
            statusMessage = enabled ? "Launch at login enabled." : "Launch at login disabled."
        } catch {
            launchAtLoginEnabled = launchService.isEnabled()
            statusMessage = "Could not change launch at login setting."
        }
    }

    func setOverlayPillVisible(_ visible: Bool) {
        overlayPillVisible = visible
        UserDefaults.standard.set(visible, forKey: overlayPillVisibleKey)
        applyOverlayPillVisibility()
        statusMessage = visible ? "Floating pill shown." : "Floating pill hidden."
    }

    func setAllowSingleKeyShortcuts(_ enabled: Bool) {
        allowSingleKeyShortcuts = enabled
        UserDefaults.standard.set(enabled, forKey: allowSingleKeyShortcutsKey)

        if !enabled && !hotkey.isValidGlobalShortcut(allowSingleKey: false) {
            updateHotkey(.default)
            statusMessage = "1-key disabled. Shortcut reset to \(Hotkey.default.displayValue)."
            return
        }

        statusMessage = enabled
            ? "1-key shortcuts enabled. Pick a key you do not type often."
            : "1-key shortcuts disabled."
    }

    func overlayPrimaryAction() {
        if isRecording {
            Task { await stopAndProcessCurrentRecording() }
        } else if !isProcessing {
            Task { await startRecording(mode: .persistent) }
        }
    }

    func cancelRecordingFromOverlay() {
        guard isRecording else { return }
        recorder.cancelRecording()
        resetRecordingState()
        statusMessage = "Recording cancelled."
    }

    private func saveModelSettings(_ settings: LocalModelSettings) {
        localModelSettings = settings
        modelSettingsStore.save(settings)
        refreshSetupStatus(showReadyMessage: false)
    }

    private func saveGlobalUsageSettings(_ settings: GlobalUsageSettings) {
        globalUsageSettings = settings
        globalUsageSettingsStore.save(settings)
        refreshGlobalUsageStatus()
    }

    private func refreshGlobalUsageStatus() {
        if !globalUsageSettings.enabled {
            globalUsageStatus = "Team stats sharing is off."
        } else if !globalUsageSettings.isConfigured {
            globalUsageStatus = "Add a web app URL and team key to sync team stats."
        } else if let lastSyncedAt = globalUsageSettings.lastSyncedAt {
            globalUsageStatus = "Team stats synced \(lastSyncedAt.formatted(date: .omitted, time: .shortened))."
        } else {
            globalUsageStatus = "Team stats ready to sync."
        }
    }

    private func fetchGlobalUsageSnapshot() async {
        guard globalUsageSettings.isConfigured else {
            globalUsageStatus = "Add a web app URL and team key to view team stats."
            return
        }

        isSyncingGlobalUsage = true
        globalUsageStatus = "Refreshing team stats..."
        defer { isSyncingGlobalUsage = false }

        do {
            globalUsageSnapshot = try await globalUsageClient.fetch(settings: globalUsageSettings)
            globalUsageStatus = "Team stats refreshed."
        } catch {
            globalUsageStatus = error.localizedDescription
        }
    }

    private func syncGlobalUsageIfNeeded(force: Bool) {
        globalUsageSyncTask?.cancel()
        globalUsageSyncTask = Task { [weak self] in
            guard let self else { return }
            await self.syncGlobalUsage(force: force)
        }
    }

    private func syncGlobalUsage(force: Bool) async {
        guard globalUsageSettings.enabled else { return }
        guard globalUsageSettings.isConfigured else {
            globalUsageStatus = "Add a web app URL and team key to sync team stats."
            return
        }

        if !force,
           let lastSyncedAt = globalUsageSettings.lastSyncedAt,
           Date().timeIntervalSince(lastSyncedAt) < 15 * 60 {
            return
        }

        isSyncingGlobalUsage = true
        globalUsageStatus = "Syncing aggregate team stats..."
        defer { isSyncingGlobalUsage = false }

        do {
            let snapshot = try await globalUsageClient.sync(
                settings: globalUsageSettings,
                summary: usageSummary,
                modelName: localModelSettings.modelName,
                appVersion: appVersion
            )
            globalUsageSnapshot = snapshot
            var next = globalUsageSettings
            next.lastSyncedAt = Date()
            saveGlobalUsageSettings(next)
        } catch {
            globalUsageStatus = error.localizedDescription
        }
    }

    private func wireHotkeyCallbacks() {
        hotkeyMonitor.onPress = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleHotkeyPress()
            }
        }

        hotkeyMonitor.onRelease = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.handleHotkeyRelease()
            }
        }
    }

    private func registerInitialHotkey() {
        do {
            try hotkeyMonitor.register(hotkey: hotkey)
            return
        } catch {
            let fallback = Hotkey.default
            guard hotkey != fallback else {
                statusMessage = "Could not register the default shortcut. Pick another shortcut."
                return
            }

            hotkey = fallback
            hotkeyStore.save(fallback)

            do {
                try hotkeyMonitor.register(hotkey: fallback)
                statusMessage = "Shortcut reset to \(fallback.displayValue)."
            } catch {
                statusMessage = "Could not register a global shortcut. Pick another shortcut."
            }
        }
    }

    private func handleHotkeyPress() async {
        guard !isProcessing else { return }

        if isRecording && recordingMode == .persistent {
            await stopAndProcessCurrentRecording()
            return
        }

        guard !isRecording else { return }

        if persistentStartMode == .singlePress {
            await startRecording(mode: .persistent)
            return
        }

        isHotkeyDown = true

        let now = Date()
        if let firstTapDate, now.timeIntervalSince(firstTapDate) <= doubleTapWindow {
            self.firstTapDate = nil
            clearTapTask?.cancel()
            holdTask?.cancel()
            await startRecording(mode: .persistent)
            return
        }

        firstTapDate = now
        scheduleFirstTapExpiry(expected: now)
        scheduleHoldDetection()
    }

    private func handleHotkeyRelease() async {
        isHotkeyDown = false

        if recordingMode == .pushToTalk {
            await stopAndProcessCurrentRecording()
        }
    }

    private func scheduleFirstTapExpiry(expected: Date) {
        clearTapTask?.cancel()
        let timeoutNanos = UInt64(self.doubleTapWindow * 1_000_000_000)
        clearTapTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: timeoutNanos)
            await MainActor.run {
                guard let self, self.firstTapDate == expected else { return }
                self.firstTapDate = nil
            }
        }
    }

    private func scheduleHoldDetection() {
        holdTask?.cancel()
        let holdThreshold = self.holdThreshold
        holdTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: holdThreshold)
            await MainActor.run {
                guard let self else { return }
                guard self.isHotkeyDown, self.recordingMode == .none, self.firstTapDate != nil else { return }
                self.firstTapDate = nil
                Task { await self.startRecording(mode: .pushToTalk) }
            }
        }
    }

    private func startRecording(mode: RecordingMode) async {
        refreshSetupStatus(showReadyMessage: false)

        guard engineReady else {
            statusMessage = "Setup incomplete: local Whisper engine is missing."
            return
        }

        guard modelReady else {
            statusMessage = "Setup incomplete: local model file is missing."
            return
        }

        if !hasMicrophonePermission {
            let granted = await recorder.requestPermission()
            refreshSetupStatus(showReadyMessage: granted)
            guard granted else {
                statusMessage = "Setup incomplete: microphone permission is required."
                return
            }
        }

        do {
            try recorder.startRecording()
            recordingMode = mode
            isRecording = true
            recordingStartedAt = Date()
            recordingDuration = 0
            statusMessage = "Recording..."
            startDurationTimer()
        } catch {
            refreshSetupStatus(showReadyMessage: false)
            if let recorderError = error as? AudioRecorderError, recorderError == .permissionDenied {
                statusMessage = "Microphone permission is required."
            } else {
                statusMessage = "Could not start recording: \(error.localizedDescription)"
            }
        }
    }

    private func startDurationTimer() {
        durationTask?.cancel()
        durationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await MainActor.run {
                    guard let self, let startedAt = self.recordingStartedAt else { return }
                    self.recordingDuration = Date().timeIntervalSince(startedAt)
                }
            }
        }
    }

    private func applyOverlayPillVisibility() {
        if overlayPillVisible {
            if overlayController == nil {
                overlayController = OverlayWindowController(viewModel: self)
            }
            overlayController?.show()
        } else {
            overlayController?.hide()
            overlayController = nil
        }
    }

    private func stopAndProcessCurrentRecording() async {
        durationTask?.cancel()

        let outcome: (url: URL, duration: TimeInterval)
        do {
            outcome = try recorder.stopRecording()
        } catch {
            resetRecordingState()
            statusMessage = "Could not stop recording."
            return
        }

        resetRecordingState()

        guard outcome.duration >= minDuration else {
            try? FileManager.default.removeItem(at: outcome.url)
            statusMessage = "Recording too short."
            return
        }

        isProcessing = true
        statusMessage = "Transcribing locally..."

        do {
            let transcription = try await transcriber.transcribe(audioURL: outcome.url, settings: localModelSettings)
            try? FileManager.default.removeItem(at: outcome.url)
            handleCompletedTranscript(transcription, duration: outcome.duration)
        } catch {
            try? FileManager.default.removeItem(at: outcome.url)
            isProcessing = false
            statusMessage = "Transcription failed: \(error.localizedDescription)"
        }
    }

    private func handleCompletedTranscript(_ transcription: LocalTranscriptionResult, duration: TimeInterval) {
        let pasteText = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pasteText.isEmpty else {
            isProcessing = false
            statusMessage = "No speech detected."
            return
        }

        recordUsage(transcriptionDuration: duration, wordCount: transcription.wordCount)

        do {
            _ = try pasteInjector.paste(pasteText)
            isProcessing = false
            statusMessage = "Pasted local transcript. No transcript was saved."
        } catch {
            if case PasteInjectorError.accessibilityPermissionRequired = error {
                _ = pasteInjector.requestAccessibilityPermissionIfNeeded()
                refreshSetupStatus(showReadyMessage: false)
                statusMessage = "Enable Accessibility for Dataiku Chirp, then try again. Copied to clipboard."
            } else if let pasteError = error as? PasteInjectorError {
                statusMessage = "\(pasteError.localizedDescription) Copied to clipboard."
            } else {
                statusMessage = "Paste failed, copied to clipboard."
            }

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(pasteText, forType: .string)
            isProcessing = false
        }
    }

    private func resetRecordingState() {
        recordingMode = .none
        isRecording = false
        recordingStartedAt = nil
        recordingDuration = 0
        isHotkeyDown = false
    }

    private func recordUsage(transcriptionDuration: TimeInterval, wordCount: Int) {
        let saved = UsagePricing.estimatedTypingSecondsSaved(
            wordCount: wordCount,
            dictationSeconds: transcriptionDuration
        )
        let avoided = UsagePricing.estimatedVendorCostAvoided(
            transcriptionSeconds: transcriptionDuration
        )

        let record = UsageRecord(
            transcriptionSeconds: transcriptionDuration,
            wordCount: wordCount,
            estimatedTypingSecondsSaved: saved,
            estimatedVendorCostAvoidedUSD: avoided
        )

        usageRecords = usageStore.add(record)
        usageSummary = UsageSummary.from(records: usageRecords)
        syncGlobalUsageIfNeeded(force: false)
    }

    private func openSystemSettings(urlStrings: [String]) -> Bool {
        for value in urlStrings {
            guard let url = URL(string: value) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }

        let settingsApp = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        if FileManager.default.fileExists(atPath: settingsApp.path) {
            NSWorkspace.shared.open(settingsApp)
            return true
        }

        return false
    }

    private func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    private func publishIfChanged<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<AppViewModel, T>, _ value: T) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }

    private func startAccessibilityRefreshWindow() {
        accessibilityRefreshTask?.cancel()
        accessibilityRefreshTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<60 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let isReady = await MainActor.run { () -> Bool in
                    self.refreshSetupStatus(showReadyMessage: false)
                    return self.hasAccessibilityPermission
                }
                if isReady {
                    await MainActor.run {
                        self.statusMessage = "Accessibility is enabled."
                    }
                    return
                }
            }
            await MainActor.run {
                if !self.hasAccessibilityPermission {
                    self.statusMessage = "Accessibility still not detected in this running app. Relaunch Dataiku Chirp, then press Refresh Setup."
                }
            }
        }
    }
}
