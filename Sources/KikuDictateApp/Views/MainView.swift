import Carbon
import AppKit
import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var enginePathInput = ""
    @State private var modelPathInput = ""
    @State private var modelNameInput = ""
    @State private var showAdvancedRuntime = false
    @State private var showGlobalUsage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            HStack(alignment: .top, spacing: 10) {
                usagePanel
                    .frame(width: 312)

                VStack(alignment: .leading, spacing: 10) {
                    setupPanel
                    preferencesPanel
                }
            }

            runtimeStrip
            statusBar
        }
        .padding(16)
        .frame(minWidth: 720, idealWidth: 740, minHeight: 500, idealHeight: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.canvas)
        .preferredColorScheme(.light)
        .onAppear {
            enginePathInput = viewModel.localModelSettings.enginePath
            modelPathInput = viewModel.localModelSettings.modelPath
            modelNameInput = viewModel.localModelSettings.modelName
            viewModel.refreshSetupStatus(showReadyMessage: false)
            resizeMainWindowToDashboard()
        }
        .onChange(of: viewModel.localModelSettings) { settings in
            enginePathInput = settings.enginePath
            modelPathInput = settings.modelPath
            modelNameInput = settings.modelName
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            DataikuChirpMark()
                .frame(width: 58, height: 50)

            VStack(alignment: .leading, spacing: 1) {
                Text("Dataiku Chirp")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("Local voice-to-text for Dataiku teams")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }

            Spacer()

            statusBadge(viewModel.setupComplete ? "Ready" : "Setup needed", isOn: viewModel.setupComplete)
            primaryActionButton
        }
    }

    private var primaryActionButton: some View {
        Group {
            if !viewModel.hasMicrophonePermission {
                Button {
                    Task { await viewModel.requestMicrophonePermission() }
                } label: {
                    Label("Mic", systemImage: "mic")
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
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .tint(viewModel.isRecording ? Palette.red : Palette.green)
    }

    private var usagePanel: some View {
        panel {
            HStack {
                Label("Usage", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Button {
                    showGlobalUsage.toggle()
                } label: {
                    Label("Team", systemImage: "building.2")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showGlobalUsage, arrowEdge: .top) {
                    globalUsagePopover
                        .padding(16)
                        .frame(width: 430)
                }
                Text(viewModel.setupComplete ? "Live" : "After setup")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(viewModel.setupComplete ? Palette.green : Palette.orange)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                usageValue("Words", "\(viewModel.usageSummary.totalWords)")
                usageValue("Today", "\(viewModel.usageSummary.todayWords)")
                usageValue("Time saved", formattedHours(viewModel.usageSummary.totalTypingHoursSaved))
                usageValue("Spend avoided", formattedUSD(viewModel.usageSummary.totalVendorCostAvoidedUSD))
            }

            Divider()
                .padding(.vertical, 1)

            VStack(alignment: .leading, spacing: 7) {
                Text("Trust defaults")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.muted)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 7) {
                    trustPoint("No API key")
                    trustPoint("No history")
                    trustPoint("No prompt")
                    trustPoint("Temp audio deleted")
                }
            }

            Text("Only aggregate counters are stored.")
                .font(.caption2)
                .foregroundStyle(Palette.muted)
        }
    }

    private var globalUsagePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Team Usage", systemImage: "building.2")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Spacer()
                if viewModel.isSyncingGlobalUsage {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                globalUsageValue("Team words", "\(viewModel.globalUsageSnapshot.totalWords)")
                globalUsageValue("Active installs", "\(viewModel.globalUsageSnapshot.activeInstallations)")
                globalUsageValue("Team time saved", formattedHours(viewModel.globalUsageSnapshot.totalTypingHoursSaved))
                globalUsageValue("Team spend avoided", formattedUSD(viewModel.globalUsageSnapshot.totalVendorCostAvoidedUSD))
            }

            Divider()

            Toggle("Share my aggregate counters", isOn: Binding(
                get: { viewModel.globalUsageSettings.enabled },
                set: { enabled in viewModel.setGlobalUsageSharing(enabled) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)

            HStack(spacing: 10) {
                Text("Team")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 56, alignment: .leading)

                Picker("Team", selection: Binding(
                    get: { viewModel.globalUsageSettings.team },
                    set: { viewModel.setGlobalUsageTeam($0) }
                )) {
                    ForEach(DataikuTeam.allCases) { team in
                        Text(team.rawValue).tag(team)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.syncGlobalUsageNow()
                } label: {
                    Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.isSyncingGlobalUsage)

                Button {
                    viewModel.refreshGlobalUsage()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isSyncingGlobalUsage)

                Spacer()
            }
            .controlSize(.small)

            Label("Aggregate only: no audio or transcript text.", systemImage: "lock.shield")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Palette.green)

            Text(viewModel.globalUsageStatus)
                .font(.caption2)
                .foregroundStyle(Palette.muted)
                .lineLimit(2)
        }
    }

    private var setupPanel: some View {
        panel {
            HStack {
                Label("Setup", systemImage: "checklist")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                if !viewModel.runningFromApplications {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.orange)
                }
            }

            HStack(spacing: 10) {
                setupRow(
                    title: "Speech",
                    subtitle: viewModel.engineReady && viewModel.modelReady ? "Ready" : "Needs runtime",
                    systemImage: "cpu",
                    isOn: viewModel.engineReady && viewModel.modelReady,
                    actionTitle: viewModel.engineReady && viewModel.modelReady ? nil : "Fix",
                    action: viewModel.engineReady && viewModel.modelReady ? nil : { showAdvancedRuntime = true }
                )

                setupRow(
                    title: "Mic",
                    subtitle: viewModel.hasMicrophonePermission ? "Ready" : "Needed",
                    systemImage: "mic",
                    isOn: viewModel.hasMicrophonePermission,
                    actionTitle: viewModel.hasMicrophonePermission ? nil : "Enable",
                    action: viewModel.hasMicrophonePermission ? nil : { Task { await viewModel.requestMicrophonePermission() } }
                )

                setupRow(
                    title: "Paste",
                    subtitle: viewModel.hasAccessibilityPermission ? "Enabled" : "Optional",
                    systemImage: "cursorarrow.click",
                    isOn: viewModel.autoPasteReady,
                    actionTitle: viewModel.hasAccessibilityPermission ? nil : "Enable",
                    action: viewModel.hasAccessibilityPermission ? nil : { viewModel.requestAccessibilityPermission() }
                )
            }
        }
    }

    private var preferencesPanel: some View {
        panel {
            HStack {
                Label("Preferences", systemImage: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
            }

            HStack(alignment: .center, spacing: 8) {
                Text("Shortcut")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 58, alignment: .leading)

                HotkeyCaptureButton(
                    currentHotkey: viewModel.hotkey,
                    allowSingleKey: viewModel.allowSingleKeyShortcuts
                ) { value in
                    viewModel.updateHotkey(value)
                } onCaptureStateChange: { active in
                    viewModel.setHotkeyCapture(active: active)
                } onInvalidCapture: {
                    viewModel.hotkeyCaptureInvalid()
                }
            }

            HStack(spacing: 7) {
                shortcutPreset("Control Space", keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey))
                shortcutPreset("Control Shift Space", keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | shiftKey))
                shortcutPreset("Command Shift D", keyCode: UInt32(kVK_ANSI_D), modifiers: UInt32(cmdKey | shiftKey))
            }

            HStack(spacing: 10) {
                Picker("Start", selection: Binding(
                    get: { viewModel.persistentStartMode },
                    set: { viewModel.setPersistentStartMode($0) }
                )) {
                    ForEach(PersistentStartMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)

                Spacer()

                compactToggle("1-key", isOn: Binding(
                    get: { viewModel.allowSingleKeyShortcuts },
                    set: { viewModel.setAllowSingleKeyShortcuts($0) }
                ))
            }

            HStack(spacing: 12) {
                compactToggle("Login", isOn: Binding(
                    get: { viewModel.launchAtLoginEnabled },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))

                compactToggle("Pill", isOn: Binding(
                    get: { viewModel.overlayPillVisible },
                    set: { viewModel.setOverlayPillVisible($0) }
                ))
            }
        }
    }

    private var runtimeStrip: some View {
        HStack(spacing: 10) {
            Label("Model: \(viewModel.modelSummary)", systemImage: "cube.box")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(viewModel.modelReady ? Palette.ink : Palette.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer()

            Button {
                showAdvancedRuntime.toggle()
            } label: {
                Label("Advanced Runtime", systemImage: showAdvancedRuntime ? "chevron.down" : "chevron.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .popover(isPresented: $showAdvancedRuntime, arrowEdge: .top) {
                advancedRuntimePopover
                    .padding(16)
                    .frame(width: 680)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.panel))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.stroke))
    }

    private var advancedRuntimePopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Advanced Runtime")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Button("Done") {
                    showAdvancedRuntime = false
                }
                .controlSize(.small)
            }

            Text("Model file: \(viewModel.modelFileName) (\(viewModel.modelSizeDescription))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.ink)

            pathRow(
                title: "Name",
                value: $modelNameInput,
                ready: true,
                save: { viewModel.updateModelName(modelNameInput) }
            )

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

            HStack(spacing: 8) {
                Button {
                    viewModel.copyInstallCommands()
                } label: {
                    Label("Copy Install", systemImage: "terminal")
                }

                Button {
                    viewModel.openModelFolder()
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }

                Button {
                    viewModel.resetModelSettings()
                } label: {
                    Label("Reset", systemImage: "arrow.uturn.backward")
                }

                Button {
                    viewModel.copyDiagnostics()
                } label: {
                    Label("Diagnostics", systemImage: "doc.on.doc")
                }
            }
            .controlSize(.small)

            Text("Usage metrics: \(viewModel.usageStoragePath)")
                .font(.caption2)
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if viewModel.isProcessing {
                ProgressView()
                    .controlSize(.small)
            }

            if viewModel.isRecording {
                Label("Recording \(formattedDuration(viewModel.recordingDuration))", systemImage: "waveform")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.green)
            } else {
                Text(viewModel.statusMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()
        }
        .frame(minHeight: 18)
    }

    private func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.panel))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.stroke))
    }

    private func setupRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isOn: Bool,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isOn ? Palette.green : Palette.orange)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.ink)
            }

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Palette.muted)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func shortcutPreset(_ title: String, keyCode: UInt32, modifiers: UInt32) -> some View {
        Button {
            viewModel.updateHotkey(Hotkey(keyCode: keyCode, modifiers: modifiers))
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func compactToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private func pathRow(title: String, value: Binding<String>, ready: Bool, save: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            statusDot(ready)
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(width: 48, alignment: .leading)
                .foregroundStyle(Palette.muted)
            TextField(title, text: value)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
            Button {
                save()
            } label: {
                Label("Save", systemImage: "checkmark")
            }
            .controlSize(.small)
        }
    }

    private func statusBadge(_ title: String, isOn: Bool) -> some View {
        HStack(spacing: 6) {
            statusDot(isOn)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.ink)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.stroke))
    }

    private func trustPoint(_ title: String) -> some View {
        Label(title, systemImage: "checkmark.shield")
            .font(.caption2.weight(.medium))
            .foregroundStyle(Palette.green)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private func statusDot(_ ready: Bool) -> some View {
        Circle()
            .fill(ready ? Palette.green : Palette.orange)
            .frame(width: 7, height: 7)
    }

    private func usageValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.muted)
            Text(value)
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(minHeight: 44, alignment: .leading)
    }

    private func globalUsageValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.muted)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(minHeight: 40, alignment: .leading)
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

    private func resizeMainWindowToDashboard() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.title.contains("Dataiku Chirp") }) else {
                return
            }

            window.minSize = NSSize(width: 720, height: 500)
            window.setContentSize(NSSize(width: 740, height: 520))
        }
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

private struct DataikuChirpMark: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let unit = min(width, height)

            ZStack {
                DataikuBirdShape()
                    .fill(Palette.ink)
                    .frame(width: width * 0.82, height: height * 0.94)
                    .position(x: width * 0.38, y: height * 0.55)

                Circle()
                    .fill(Palette.canvas)
                    .frame(width: unit * 0.075, height: unit * 0.075)
                    .position(x: width * 0.48, y: height * 0.37)

                RoundedRectangle(cornerRadius: unit * 0.016)
                    .fill(Palette.ink)
                    .frame(width: width * 0.34, height: height * 0.07)
                    .position(x: width * 0.50, y: height * 0.78)

                SpeechBubbleShape()
                    .fill(Palette.ink)
                    .frame(width: width * 0.34, height: height * 0.28)
                    .position(x: width * 0.78, y: height * 0.20)
            }
        }
        .aspectRatio(58 / 50, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct DataikuBirdShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.86))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.39, y: rect.minY + h * 0.54))
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.54, y: rect.minY + h * 0.25),
            control1: CGPoint(x: rect.minX + w * 0.43, y: rect.minY + h * 0.40),
            control2: CGPoint(x: rect.minX + w * 0.49, y: rect.minY + h * 0.26)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.73, y: rect.minY + h * 0.28),
            control1: CGPoint(x: rect.minX + w * 0.61, y: rect.minY + h * 0.19),
            control2: CGPoint(x: rect.minX + w * 0.70, y: rect.minY + h * 0.21)
        )
        path.addLine(to: CGPoint(x: rect.minX + w * 0.86, y: rect.minY + h * 0.22))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.78, y: rect.minY + h * 0.34))
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.60, y: rect.minY + h * 0.61),
            control1: CGPoint(x: rect.minX + w * 0.77, y: rect.minY + h * 0.48),
            control2: CGPoint(x: rect.minX + w * 0.70, y: rect.minY + h * 0.59)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w * 0.32, y: rect.minY + h * 0.60),
            control1: CGPoint(x: rect.minX + w * 0.50, y: rect.minY + h * 0.64),
            control2: CGPoint(x: rect.minX + w * 0.40, y: rect.minY + h * 0.64)
        )
        path.addLine(to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.86))
        path.closeSubpath()

        return path
    }
}

private struct SpeechBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bubbleRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width * 0.88,
            height: rect.height * 0.78
        )
        let corner = bubbleRect.height / 2

        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: corner, height: corner))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.30, y: bubbleRect.maxY - 1))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.minY + rect.height * 0.92),
            control: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.92)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.54, y: bubbleRect.maxY - 1),
            control: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.99)
        )
        path.closeSubpath()

        return path
    }
}
