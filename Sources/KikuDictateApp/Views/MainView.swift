import Carbon
import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var enginePathInput = ""
    @State private var modelPathInput = ""

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 22) {
                header
                setupSection
                modelSection
                hotkeySection
                behaviorSection
                usageSection
                securitySection
                statusSection
            }
            .padding(24)
        }
        .frame(minWidth: 780, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            enginePathInput = viewModel.localModelSettings.enginePath
            modelPathInput = viewModel.localModelSettings.modelPath
            viewModel.refreshSetupStatus(showReadyMessage: false)
        }
        .onChange(of: viewModel.localModelSettings) { settings in
            enginePathInput = settings.enginePath
            modelPathInput = settings.modelPath
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.03, green: 0.30, blue: 0.28), Color(red: 0.10, green: 0.55, blue: 0.46)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text("Kiku Dictate")
                    .font(.system(size: 30, weight: .bold))
                Text("Local voice-to-text for Dataiku teams")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge(viewModel.setupComplete ? "Ready" : "Setup", isOn: viewModel.setupComplete)
        }
    }

    private var setupSection: some View {
        section("Setup") {
            HStack(spacing: 10) {
                statusPill("Local engine", isOn: viewModel.engineReady)
                statusPill("Local model", isOn: viewModel.modelReady)
                statusPill("Microphone", isOn: viewModel.hasMicrophonePermission)
                statusPill("Auto-paste", isOn: viewModel.autoPasteReady)
            }

            HStack(spacing: 10) {
                if !viewModel.hasMicrophonePermission {
                    Button {
                        Task { await viewModel.requestMicrophonePermission() }
                    } label: {
                        Label("Enable Microphone", systemImage: "mic")
                    }

                    Button {
                        viewModel.openMicrophoneSettings()
                    } label: {
                        Label("Mic Settings", systemImage: "gearshape")
                    }
                }

                if !viewModel.hasAccessibilityPermission {
                    Button {
                        viewModel.requestAccessibilityPermission()
                    } label: {
                        Label("Enable Auto-paste", systemImage: "cursorarrow.click")
                    }

                    Button {
                        viewModel.openAccessibilitySettings()
                    } label: {
                        Label("Accessibility", systemImage: "gearshape")
                    }
                }

                Button {
                    viewModel.refreshSetupFromUI()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    viewModel.copyDiagnostics()
                } label: {
                    Label("Diagnostics", systemImage: "doc.on.doc")
                }
            }

            if !viewModel.runningFromApplications {
                Text(viewModel.currentAppPath.contains("/AppTranslocation/")
                     ? "Running from a translocated path. Move the app to /Applications or ~/Applications."
                     : "Running outside /Applications or ~/Applications.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var modelSection: some View {
        section("Local Model") {
            pathRow(
                title: "Engine",
                value: $enginePathInput,
                ready: viewModel.engineReady,
                save: { viewModel.updateEnginePath(enginePathInput) }
            )

            pathRow(
                title: "Model",
                value: $modelPathInput,
                ready: viewModel.modelReady,
                save: { viewModel.updateModelPath(modelPathInput) }
            )

            HStack(spacing: 10) {
                Button {
                    viewModel.copyInstallCommands()
                } label: {
                    Label("Copy Install Commands", systemImage: "terminal")
                }

                Button {
                    viewModel.openModelFolder()
                } label: {
                    Label("Open Model Folder", systemImage: "folder")
                }

                Button {
                    viewModel.resetModelSettings()
                } label: {
                    Label("Reset Paths", systemImage: "arrow.uturn.backward")
                }
            }

            Text(viewModel.localModelSettings.modelName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var hotkeySection: some View {
        section("Hotkey") {
            HStack(spacing: 12) {
                HotkeyCaptureButton(currentHotkey: viewModel.hotkey) { value in
                    viewModel.updateHotkey(value)
                } onCaptureStateChange: { active in
                    viewModel.setHotkeyCapture(active: active)
                } onInvalidCapture: {
                    viewModel.hotkeyCaptureInvalid()
                }

                Button {
                    viewModel.updateHotkey(Hotkey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)))
                } label: {
                    Label("Use Option Space", systemImage: "keyboard")
                }

                Button {
                    viewModel.updateHotkey(Hotkey(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey)))
                } label: {
                    Label("Use Control Space", systemImage: "keyboard")
                }

                Spacer()
            }

            Picker("Start Recording", selection: Binding(
                get: { viewModel.persistentStartMode },
                set: { viewModel.setPersistentStartMode($0) }
            )) {
                ForEach(PersistentStartMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var behaviorSection: some View {
        section("Behavior") {
            HStack(spacing: 18) {
                Toggle("Launch at login", isOn: Binding(
                    get: { viewModel.launchAtLoginEnabled },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))
                .toggleStyle(.switch)

                Toggle("Floating pill", isOn: Binding(
                    get: { viewModel.overlayPillVisible },
                    set: { viewModel.setOverlayPillVisible($0) }
                ))
                .toggleStyle(.switch)

                Spacer()

                Button {
                    viewModel.overlayPrimaryAction()
                } label: {
                    Label(viewModel.isRecording ? "Stop" : "Record", systemImage: viewModel.isRecording ? "stop.fill" : "mic.fill")
                }
                .keyboardShortcut(.space, modifiers: [.command])
                .disabled(viewModel.isProcessing || !viewModel.setupComplete)
            }
        }
    }

    private var usageSection: some View {
        section("Usage") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), alignment: .leading, spacing: 14) {
                usageValue("Words", "\(viewModel.usageSummary.totalWords)")
                usageValue("Today", "\(viewModel.usageSummary.todayWords)")
                usageValue("Time saved", formattedHours(viewModel.usageSummary.totalTypingHoursSaved))
                usageValue("Spend avoided", formattedUSD(viewModel.usageSummary.totalVendorCostAvoidedUSD))
                usageValue("Sessions", "\(viewModel.usageSummary.sessions)")
                usageValue("Minutes", formattedMinutes(viewModel.usageSummary.totalTranscriptionMinutes))
                usageValue("This month", "\(viewModel.usageSummary.monthWords)")
                usageValue("Last", "\(viewModel.usageSummary.lastRecordingWords) words")
            }

            Text(viewModel.usagePricingNote)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Usage log: \(viewModel.usageStoragePath)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var securitySection: some View {
        section("Security") {
            HStack(spacing: 10) {
                securityPoint("No API key")
                securityPoint("No transcript history")
                securityPoint("No prompt input")
                securityPoint("Temp audio deleted")
            }
        }
    }

    private var statusSection: some View {
        HStack(spacing: 10) {
            if viewModel.isProcessing {
                ProgressView()
                    .controlSize(.small)
            }

            if viewModel.isRecording {
                Text("Recording \(formattedDuration(viewModel.recordingDuration))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            } else {
                Text(viewModel.statusMessage)
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .foregroundStyle(.secondary)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func pathRow(title: String, value: Binding<String>, ready: Bool, save: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            statusDot(ready)
            Text(title)
                .frame(width: 58, alignment: .leading)
                .foregroundStyle(.secondary)
            TextField(title, text: value)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
            Button {
                save()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
        }
    }

    private func statusBadge(_ title: String, isOn: Bool) -> some View {
        HStack(spacing: 6) {
            statusDot(isOn)
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func statusPill(_ title: String, isOn: Bool) -> some View {
        HStack(spacing: 6) {
            statusDot(isOn)
            Text(title)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func securityPoint(_ title: String) -> some View {
        Label(title, systemImage: "checkmark.shield")
            .font(.caption.weight(.medium))
            .foregroundStyle(Color(red: 0.03, green: 0.38, blue: 0.32))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.green.opacity(0.10)))
    }

    private func statusDot(_ ready: Bool) -> some View {
        Circle()
            .fill(ready ? Color(red: 0.08, green: 0.58, blue: 0.42) : Color.orange)
            .frame(width: 8, height: 8)
    }

    private func usageValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minHeight: 44, alignment: .leading)
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds), 0)
        let minutes = total / 60
        let remaining = total % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    private func formattedUSD(_ value: Double) -> String {
        if value > 0, value < 0.01 {
            return String(format: "$%.4f", value)
        }
        return String(format: "$%.2f", value)
    }

    private func formattedMinutes(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formattedHours(_ value: Double) -> String {
        if value < 1 {
            return String(format: "%.0f min", value * 60)
        }
        return String(format: "%.1f hr", value)
    }
}

