import Carbon
import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var enginePathInput = ""
    @State private var modelPathInput = ""
    @State private var showAdvancedRuntime = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                header
                primaryPanel
                setupSection
                preferencesSection
                usageSection
                trustSection
                advancedRuntimeSection
                statusSection
            }
            .padding(26)
        }
        .frame(minWidth: 840, minHeight: 660)
        .background(Palette.canvas)
        .preferredColorScheme(.light)
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
        HStack(alignment: .center, spacing: 16) {
            KikuMark()
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text("Kiku Dictate")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("Private voice-to-text for Dataiku teams")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }

            Spacer()

            statusBadge(viewModel.setupComplete ? "Ready" : "Setup needed", isOn: viewModel.setupComplete)
        }
    }

    private var primaryPanel: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.setupComplete ? "Ready to dictate" : "Finish setup to start")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.ink)

                Text(primarySubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(viewModel.hotkey.displayValue, systemImage: "keyboard")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(.white))

                    Label("On-device transcription", systemImage: "lock.shield")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Palette.green.opacity(0.11)))
                }
            }

            Spacer()

            primaryActionButton
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.panel))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.stroke))
    }

    private var primarySubtitle: String {
        if viewModel.isRecording {
            return "Recording now. Press the shortcut again or use Stop when you are done."
        }
        if viewModel.isProcessing {
            return "Transcribing locally. Audio stays on this Mac."
        }
        if !viewModel.engineReady || !viewModel.modelReady {
            return "The local speech engine needs attention from Advanced Runtime."
        }
        if !viewModel.hasMicrophonePermission {
            return "Microphone permission is required before dictation can start."
        }
        if !viewModel.hasAccessibilityPermission {
            return "Dictation works, but auto-paste needs Accessibility permission."
        }
        return "Use the shortcut or Record button from any app, then Kiku will paste the result."
    }

    private var primaryActionButton: some View {
        Group {
            if !viewModel.hasMicrophonePermission {
                Button {
                    Task { await viewModel.requestMicrophonePermission() }
                } label: {
                    Label("Enable Microphone", systemImage: "mic")
                }
            } else {
                Button {
                    viewModel.overlayPrimaryAction()
                } label: {
                    Label(viewModel.isRecording ? "Stop" : "Record", systemImage: viewModel.isRecording ? "stop.fill" : "mic.fill")
                }
                .disabled(viewModel.isProcessing || !viewModel.setupComplete)
            }
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(viewModel.isRecording ? Palette.red : Palette.green)
    }

    private var setupSection: some View {
        section("Setup") {
            HStack(alignment: .top, spacing: 12) {
                setupItem(
                    title: "Speech engine",
                    subtitle: viewModel.engineReady && viewModel.modelReady ? "Installed locally" : "Needs IT setup",
                    systemImage: "cpu",
                    isOn: viewModel.engineReady && viewModel.modelReady,
                    actionTitle: viewModel.engineReady && viewModel.modelReady ? nil : "Advanced",
                    action: viewModel.engineReady && viewModel.modelReady ? nil : { showAdvancedRuntime = true }
                )

                setupItem(
                    title: "Microphone",
                    subtitle: viewModel.hasMicrophonePermission ? "Ready to record" : "Permission needed",
                    systemImage: "mic",
                    isOn: viewModel.hasMicrophonePermission,
                    actionTitle: viewModel.hasMicrophonePermission ? nil : "Enable",
                    action: viewModel.hasMicrophonePermission ? nil : { Task { await viewModel.requestMicrophonePermission() } }
                )

                setupItem(
                    title: "Auto-paste",
                    subtitle: viewModel.hasAccessibilityPermission ? "Enabled" : "Optional permission",
                    systemImage: "cursorarrow.click",
                    isOn: viewModel.autoPasteReady,
                    actionTitle: viewModel.hasAccessibilityPermission ? nil : "Enable",
                    action: viewModel.hasAccessibilityPermission ? nil : { viewModel.requestAccessibilityPermission() }
                )
            }

            if !viewModel.runningFromApplications {
                Label(viewModel.currentAppPath.contains("/AppTranslocation/")
                      ? "This copy is translocated. Move it to /Applications or ~/Applications and reopen."
                      : "Install in /Applications or ~/Applications so permissions remain stable.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.orange)
            }
        }
    }

    private var preferencesSection: some View {
        section("Preferences") {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Shortcut")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.muted)

                    HStack(spacing: 10) {
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
                            Label("Option Space", systemImage: "keyboard")
                        }

                        Button {
                            viewModel.updateHotkey(Hotkey(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey)))
                        } label: {
                            Label("Control Space", systemImage: "keyboard")
                        }
                    }
                }

                Spacer()
            }

            HStack(spacing: 18) {
                Picker("Start Recording", selection: Binding(
                    get: { viewModel.persistentStartMode },
                    set: { viewModel.setPersistentStartMode($0) }
                )) {
                    ForEach(PersistentStartMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 310)

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
            }
        }
    }

    private var usageSection: some View {
        section("Usage") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), alignment: .leading, spacing: 12) {
                usageValue("Words", "\(viewModel.usageSummary.totalWords)")
                usageValue("Today", "\(viewModel.usageSummary.todayWords)")
                usageValue("Time saved", formattedHours(viewModel.usageSummary.totalTypingHoursSaved))
                usageValue("Spend avoided", formattedUSD(viewModel.usageSummary.totalVendorCostAvoidedUSD))
            }

            Text("Estimates only. Kiku stores aggregate counters, not transcript text.")
                .font(.caption)
                .foregroundStyle(Palette.muted)
        }
    }

    private var trustSection: some View {
        section("Trust defaults") {
            HStack(spacing: 10) {
                trustPoint("No API key")
                trustPoint("No transcript history")
                trustPoint("No prompt input")
                trustPoint("Temp audio deleted")
            }
        }
    }

    private var advancedRuntimeSection: some View {
        DisclosureGroup(isExpanded: $showAdvancedRuntime) {
            VStack(alignment: .leading, spacing: 10) {
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

                    Button {
                        viewModel.copyDiagnostics()
                    } label: {
                        Label("Copy Diagnostics", systemImage: "doc.on.doc")
                    }
                }

                Text("Runtime: \(viewModel.localModelSettings.modelName). Usage metrics: \(viewModel.usageStoragePath)")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
            .padding(.top, 10)
        } label: {
            Label("Advanced Runtime", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(Palette.ink)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.panel))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.stroke))
    }

    private var statusSection: some View {
        HStack(spacing: 10) {
            if viewModel.isProcessing {
                ProgressView()
                    .controlSize(.small)
            }

            if viewModel.isRecording {
                Label("Recording \(formattedDuration(viewModel.recordingDuration))", systemImage: "waveform")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.green)
            } else {
                Text(viewModel.statusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }
        }
        .frame(minHeight: 20)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.panel))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.stroke))
    }

    private func setupItem(
        title: String,
        subtitle: String,
        systemImage: String,
        isOn: Bool,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isOn ? Palette.green : Palette.orange)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Palette.muted)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pathRow(title: String, value: Binding<String>, ready: Bool, save: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            statusDot(ready)
            Text(title)
                .frame(width: 58, alignment: .leading)
                .foregroundStyle(Palette.muted)
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
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.stroke))
    }

    private func trustPoint(_ title: String) -> some View {
        Label(title, systemImage: "checkmark.shield")
            .font(.caption.weight(.medium))
            .foregroundStyle(Palette.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Palette.green.opacity(0.10)))
    }

    private func statusDot(_ ready: Bool) -> some View {
        Circle()
            .fill(ready ? Palette.green : Palette.orange)
            .frame(width: 8, height: 8)
    }

    private func usageValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Palette.muted)
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Palette.ink)
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

    private func formattedHours(_ value: Double) -> String {
        if value < 1 {
            return String(format: "%.0f min", value * 60)
        }
        return String(format: "%.1f hr", value)
    }
}

private enum Palette {
    static let canvas = Color(red: 0.965, green: 0.963, blue: 0.945)
    static let panel = Color(red: 0.995, green: 0.992, blue: 0.976)
    static let stroke = Color(red: 0.84, green: 0.85, blue: 0.81)
    static let ink = Color(red: 0.07, green: 0.10, blue: 0.15)
    static let muted = Color(red: 0.37, green: 0.41, blue: 0.46)
    static let green = Color(red: 0.00, green: 0.56, blue: 0.43)
    static let orange = Color(red: 0.91, green: 0.42, blue: 0.12)
    static let red = Color(red: 0.76, green: 0.18, blue: 0.16)
    static let yellow = Color(red: 0.98, green: 0.77, blue: 0.25)
    static let blue = Color(red: 0.16, green: 0.33, blue: 0.76)
}

private struct KikuMark: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                RoundedRectangle(cornerRadius: size * 0.18)
                    .fill(Palette.ink)

                Circle()
                    .fill(Palette.green)
                    .frame(width: size * 0.20, height: size * 0.20)
                    .offset(x: -size * 0.18, y: -size * 0.18)

                Circle()
                    .fill(Palette.yellow)
                    .frame(width: size * 0.15, height: size * 0.15)
                    .offset(x: size * 0.20, y: -size * 0.10)

                Circle()
                    .fill(Palette.blue)
                    .frame(width: size * 0.16, height: size * 0.16)
                    .offset(x: -size * 0.02, y: size * 0.22)

                Path { path in
                    path.move(to: CGPoint(x: size * 0.32, y: size * 0.34))
                    path.addLine(to: CGPoint(x: size * 0.52, y: size * 0.46))
                    path.addLine(to: CGPoint(x: size * 0.70, y: size * 0.40))
                    path.move(to: CGPoint(x: size * 0.52, y: size * 0.46))
                    path.addLine(to: CGPoint(x: size * 0.48, y: size * 0.68))
                }
                .stroke(.white.opacity(0.88), style: StrokeStyle(lineWidth: size * 0.055, lineCap: .round, lineJoin: .round))

                HStack(spacing: size * 0.035) {
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: size * 0.02)
                            .fill(.white.opacity(0.95))
                            .frame(width: size * 0.035, height: size * CGFloat([0.16, 0.25, 0.34, 0.22][index]))
                    }
                }
                .offset(x: size * 0.19, y: size * 0.20)
            }
        }
    }
}
