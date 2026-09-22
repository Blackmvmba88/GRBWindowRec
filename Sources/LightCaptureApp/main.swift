import SwiftUI
import AppKit
import AVFoundation
import ScreenCaptureKit

enum SourceKind: String, CaseIterable, Identifiable {
    case display = "Pantalla"
    case application = "Aplicación"
    var id: String { rawValue }
}

struct CaptureChoice: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
}

@MainActor
final class Recorder: NSObject, ObservableObject, SCRecordingOutputDelegate, SCStreamDelegate {
    @Published var sourceKind: SourceKind = .display { didSet { chooseDefault() } }
    @Published var selectedID = ""
    @Published var captureSystemAudio = true
    @Published var captureMicrophone = true
    @Published private(set) var displays: [CaptureChoice] = []
    @Published private(set) var applications: [CaptureChoice] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed = 0
    @Published private(set) var status = "Buscando pantallas y aplicaciones…"
    @Published private(set) var lastRecording: URL?
    @Published private(set) var needsScreenPermission = false

    private var shareableContent: SCShareableContent?
    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var timer: Timer?
    private var startedAt: Date?
    private var pendingOutput: URL?

    var choices: [CaptureChoice] { sourceKind == .display ? displays : applications }
    var elapsedText: String {
        String(format: "%02d:%02d:%02d", elapsed / 3600, (elapsed % 3600) / 60, elapsed % 60)
    }
    var recordingsURL: URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
        return movies.appendingPathComponent("GRBWindowRec", isDirectory: true)
    }

    override init() {
        super.init()
        Task {
            await requestMicrophonePermission()
            await refreshSources()
        }
    }

    private func requestMicrophonePermission() async {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        _ = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func refreshSources() async {
        guard !isRecording else { return }
        isLoading = true
        status = "Buscando contenido disponible…"
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            shareableContent = content
            needsScreenPermission = false

            displays = content.displays.map { display in
                let name = NSScreen.screens.first(where: {
                    ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
                })?.localizedName ?? "Pantalla \(display.displayID)"
                return CaptureChoice(
                    id: "display:\(display.displayID)",
                    name: name,
                    detail: "\(display.width) × \(display.height)"
                )
            }

            let visibleBundleIDs = Set(content.windows.compactMap { $0.owningApplication?.bundleIdentifier })
            applications = content.applications
                .filter { visibleBundleIDs.contains($0.bundleIdentifier) && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
                .map {
                    CaptureChoice(
                        id: "app:\($0.processID)",
                        name: $0.applicationName,
                        detail: $0.bundleIdentifier
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            chooseDefault()
            status = "Listo: \(displays.count) pantalla(s), \(applications.count) app(s)"
        } catch {
            needsScreenPermission = true
            status = "Permiso de Grabación de pantalla pendiente. Actívalo en Ajustes del Sistema y pulsa actualizar."
        }
        isLoading = false
    }

    func openScreenPermissions() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    func toggle() {
        if isRecording { Task { await stop() } }
        else { Task { await start() } }
    }

    func start() async {
        guard let content = shareableContent else {
            await refreshSources()
            return
        }
        do {
            try FileManager.default.createDirectory(at: recordingsURL, withIntermediateDirectories: true)
            let filter: SCContentFilter
            let size: (Int, Int)
            let label: String

            switch sourceKind {
            case .display:
                guard let displayID = UInt32(selectedID.replacingOccurrences(of: "display:", with: "")),
                      let display = content.displays.first(where: { $0.displayID == displayID }) else {
                    throw CaptureError.noSelection
                }
                let ownApp = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
                filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
                size = (display.width, display.height)
                label = displays.first(where: { $0.id == selectedID })?.name ?? "pantalla"

            case .application:
                guard let pid = pid_t(selectedID.replacingOccurrences(of: "app:", with: "")),
                      let app = content.applications.first(where: { $0.processID == pid }),
                      let display = bestDisplay(for: app, in: content) else {
                    throw CaptureError.noSelection
                }
                filter = SCContentFilter(display: display, including: [app], exceptingWindows: [])
                size = (display.width, display.height)
                label = app.applicationName
            }

            let configuration = SCStreamConfiguration()
            configuration.width = min(size.0, 3840)
            configuration.height = min(size.1, 2160)
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            configuration.queueDepth = 6
            configuration.showsCursor = true
            configuration.capturesAudio = captureSystemAudio
            configuration.excludesCurrentProcessAudio = true
            configuration.captureMicrophone = captureMicrophone
            configuration.sampleRate = 48_000
            configuration.channelCount = 2

            let stamp = DateFormatter()
            stamp.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let safeLabel = label.replacingOccurrences(of: "/", with: "-")
            let output = recordingsURL.appendingPathComponent("\(safeLabel)_\(stamp.string(from: Date())).mp4")
            let outputConfiguration = SCRecordingOutputConfiguration()
            outputConfiguration.outputURL = output
            outputConfiguration.outputFileType = .mp4
            outputConfiguration.videoCodecType = .h264

            let recorder = SCRecordingOutput(configuration: outputConfiguration, delegate: self)
            let newStream = SCStream(filter: filter, configuration: configuration, delegate: self)
            try newStream.addRecordingOutput(recorder)
            stream = newStream
            recordingOutput = recorder
            pendingOutput = output
            status = "Preparando captura de \(label)…"
            try await newStream.startCapture()
        } catch {
            status = "No se pudo iniciar: \(error.localizedDescription)"
            cleanup()
        }
    }

    func stop() async {
        guard let stream else { return }
        status = "Guardando…"
        do { try await stream.stopCapture() }
        catch {
            status = "Error al detener: \(error.localizedDescription)"
            cleanup()
        }
    }

    func openRecordings() {
        try? FileManager.default.createDirectory(at: recordingsURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(recordingsURL)
    }

    func playLast() { if let lastRecording { NSWorkspace.shared.open(lastRecording) } }

    nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in
            self.isRecording = true
            self.startedAt = Date()
            self.elapsed = 0
            self.status = "Grabando la selección exacta"
            self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let start = self.startedAt else { return }
                    self.elapsed = Int(Date().timeIntervalSince(start))
                }
            }
        }
    }

    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in
            if let output = self.pendingOutput { self.lastRecording = output }
            self.status = "Grabación guardada correctamente"
            self.cleanup()
        }
    }

    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        Task { @MainActor in
            self.status = "Falló la grabación: \(error.localizedDescription)"
            self.cleanup()
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Task { @MainActor in
            self.status = "La captura se detuvo: \(error.localizedDescription)"
            self.cleanup()
        }
    }

    private func bestDisplay(for app: SCRunningApplication, in content: SCShareableContent) -> SCDisplay? {
        let appWindows = content.windows.filter { $0.owningApplication?.processID == app.processID }
        return content.displays.max { lhs, rhs in
            overlapArea(windows: appWindows, display: lhs) < overlapArea(windows: appWindows, display: rhs)
        } ?? content.displays.first
    }

    private func overlapArea(windows: [SCWindow], display: SCDisplay) -> CGFloat {
        windows.reduce(0) { $0 + $1.frame.intersection(display.frame).area }
    }

    private func chooseDefault() {
        let available = choices
        if !available.contains(where: { $0.id == selectedID }) { selectedID = available.first?.id ?? "" }
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        startedAt = nil
        stream = nil
        recordingOutput = nil
        pendingOutput = nil
        isRecording = false
    }
}

enum CaptureError: LocalizedError {
    case noSelection
    var errorDescription: String? { "Selecciona una pantalla o aplicación disponible." }
}

private extension CGRect {
    var area: CGFloat { isNull || isInfinite ? 0 : width * height }
}

struct ContentView: View {
    @StateObject private var recorder = Recorder()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Circle().fill(recorder.isRecording ? .red : .secondary.opacity(0.35)).frame(width: 11, height: 11)
                Text(recorder.isRecording ? "GRABANDO" : "GRABAR")
                    .font(.caption.weight(.semibold)).tracking(1.4)
                Spacer()
                Button { Task { await recorder.refreshSources() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Actualizar pantallas y aplicaciones")
                .disabled(recorder.isRecording || recorder.isLoading)
            }

            Text(recorder.elapsedText)
                .font(.system(size: 50, weight: .medium, design: .monospaced))
                .contentTransition(.numericText())

            Picker("Tipo", selection: $recorder.sourceKind) {
                ForEach(SourceKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .disabled(recorder.isRecording)

            Picker("Contenido", selection: $recorder.selectedID) {
                ForEach(recorder.choices) { choice in
                    VStack(alignment: .leading) {
                        Text(choice.name)
                        Text(choice.detail).foregroundStyle(.secondary)
                    }.tag(choice.id)
                }
            }
            .disabled(recorder.isRecording || recorder.choices.isEmpty)

            HStack {
                Toggle("Audio del sistema", isOn: $recorder.captureSystemAudio)
                Toggle("Micrófono", isOn: $recorder.captureMicrophone)
            }
            .font(.caption)
            .disabled(recorder.isRecording)

            Button(action: recorder.toggle) {
                Label(recorder.isRecording ? "Detener y guardar" : "Grabar selección",
                      systemImage: recorder.isRecording ? "stop.fill" : "record.circle")
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(recorder.isRecording ? .red : .accentColor)
            .controlSize(.large)
            .disabled(!recorder.isRecording && recorder.selectedID.isEmpty)
            .keyboardShortcut(.space, modifiers: [])

            Text(recorder.status).font(.caption).foregroundStyle(.secondary)
                .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Abrir grabaciones", action: recorder.openRecordings)
                Spacer()
                Button("Reproducir última", action: recorder.playLast)
                    .disabled(recorder.lastRecording == nil || recorder.isRecording)
            }

            if recorder.needsScreenPermission {
                Button("Abrir permisos de pantalla", action: recorder.openScreenPermissions)
                    .buttonStyle(.link)
            }
        }
        .padding(24)
        .frame(width: 470, height: 440)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await recorder.refreshSources() }
        }
    }
}

@main
struct GRBWindowRecApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .windowResizability(.contentSize)
            .commands { CommandGroup(replacing: .newItem) { } }
    }
}
