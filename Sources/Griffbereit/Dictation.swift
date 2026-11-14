import AVFoundation
import Speech
import SwiftUI
import FachCore

@MainActor
final class Dictation: ObservableObject {
    enum Phase { case ready, preparing, listening, finishing }
    @Published private(set) var phase = Phase.ready
    @Published var text = ""
    @Published var notice = ""
    private var session: UUID?
    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    func start() async {
        guard phase == .ready, text.isEmpty else { return }
        let id = UUID()
        session = id
        phase = .preparing
        notice = ""
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE")) else {
            finish("Die deutsche Spracherkennung ist auf diesem Mac nicht verfügbar.")
            return
        }
        let speech = await withCheckedContinuation { next in
            SFSpeechRecognizer.requestAuthorization { next.resume(returning: $0) }
        }
        guard session == id else { return }
        guard speech == .authorized else {
            finish("Erlaube Griffbereit unter Systemeinstellungen → Datenschutz & Sicherheit → Spracherkennung den Zugriff.")
            return
        }
        guard recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            finish("Die lokale deutsche Spracherkennung ist nicht verfügbar. Prüfe unter Systemeinstellungen → Tastatur die Diktatsprache Deutsch.")
            return
        }
        let allowed = await AVCaptureDevice.requestAccess(for: .audio)
        guard session == id else { return }
        guard allowed else {
            finish("Erlaube Griffbereit unter Systemeinstellungen → Datenschutz & Sicherheit → Mikrofon den Zugriff.")
            return
        }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            finish("Kein Mikrofon verfügbar. Wähle unter Systemeinstellungen → Ton eine Eingabequelle.")
            return
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        self.engine = engine
        self.recognizer = recognizer
        self.request = request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }
        do {
            engine.prepare()
            try engine.start()
            phase = .listening
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let words = result?.bestTranscription.formattedString
                let final = result?.isFinal == true
                let failure = error?.localizedDescription
                Task { @MainActor in
                    guard let self, self.session == id else { return }
                    if let words, !words.isEmpty { self.text = words }
                    if let failure { self.finish("Diktat beendet. " + failure) }
                    else if final { self.finish(self.text.isEmpty ? "Kein Text erkannt. Versuche es erneut." : "") }
                }
            }
        } catch { finish("Das Mikrofon konnte nicht gestartet werden. " + error.localizedDescription) }
    }

    private func stopInput() {
        if let engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            self.engine = nil
        }
        request?.endAudio()
        request = nil
    }

    func stop() {
        guard phase == .listening, let id = session else { return }
        phase = .finishing
        stopInput()
        task?.finish()
        Task {
            try? await Task.sleep(for: .seconds(3))
            if session == id { finish(text.isEmpty ? "Kein Text erkannt. Versuche es erneut." : "") }
        }
    }

    func finish(_ message: String = "") {
        session = nil
        stopInput()
        task?.cancel()
        task = nil
        recognizer = nil
        phase = .ready
        notice = message
    }
}

struct DictationSheet: View {
    @ObservedObject var desk: Desk
    @StateObject private var dictation = Dictation()
    @State private var saving = false
    @State private var pipeline: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    private func save(_ raw: String) {
        guard !saving, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        saving = true
        pipeline = Task { @MainActor in
            var text = raw
            var warning = ""
            do { text = try await NoteRewrite.polish(raw) }
            catch { warning = "Originaltext gespeichert. KI-Überarbeitung: " + error.localizedDescription }
            guard !Task.isCancelled else { return }
            do {
                try desk.saveNote(text)
                if !desk.destination.isEmpty { desk.export(automatic: true) }
                desk.voiceNotice = warning
                dismiss()
            } catch { dictation.notice = error.localizedDescription }
            saving = false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Notiz diktieren", systemImage: "mic").font(.title2.weight(.semibold))
            if saving { ProgressView("Sprachnotiz wird überarbeitet und abgelegt …") } else {
            switch dictation.phase {
            case .preparing: Text("Spracherkennung und Mikrofon werden vorbereitet …")
            case .listening: Label("Mikrofon an · Sprich jetzt.", systemImage: "waveform").foregroundStyle(.red)
            case .finishing: Text("Text wird fertiggestellt …")
            case .ready: Text(dictation.text.isEmpty ? "Diktiere eine kurze Notiz oder gib Text ein." : "Überarbeite den Entwurf oder lege ihn mit der lokalen KI ab.")
            }
            }
            TextEditor(text: $dictation.text)
                .accessibilityLabel("Notiztext").font(.body)
                .disabled(saving || dictation.phase != .ready)
                .border(Color.secondary.opacity(0.3))
            if !dictation.notice.isEmpty { Text(dictation.notice).font(.callout).textSelection(.enabled) }
            HStack {
                Button("Abbrechen") { pipeline?.cancel(); dictation.text = ""; dictation.finish(); dismiss() }
                Spacer()
                if dictation.phase == .listening {
                    Button("Diktat beenden") { dictation.stop() }.buttonStyle(.borderedProminent)
                } else if dictation.phase == .ready && dictation.text.isEmpty {
                    Button("Diktat starten") { Task { await dictation.start() } }
                } else {
                    Button("Überarbeiten und ablegen") { save(dictation.text) }
                        .buttonStyle(.borderedProminent)
                        .disabled(saving || dictation.phase != .ready || dictation.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }.padding(20).frame(width: 500, height: 320)
        .task {
            desk.stopDictation = { dictation.stop() }
            await dictation.start()
        }
        .onChange(of: dictation.phase) { old, new in
            if new == .ready && (old == .finishing || old == .listening) { save(dictation.text) }
        }
        .onDisappear { pipeline?.cancel(); desk.stopDictation = {}; dictation.finish() }
    }
}
