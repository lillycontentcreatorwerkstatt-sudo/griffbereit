import AppKit
import SwiftUI
import Vision
import FachCore

struct Project: Codable, Identifiable, Equatable {
    var id: String { path }
    let path: String
    var name: String { URL(fileURLWithPath: path).lastPathComponent }
}

@MainActor
final class Desk: ObservableObject {
    @Published var rows: [Record] = []
    @Published var selection: Record.ID?
    @Published var query = "" { didSet { alignSelection() } }
    @Published var message = ""
    @Published var showingProject = false
    @Published var captureNotice = ""
    @Published var lastExport: URL?
    let browser = ProjectBrowser()
    private var exportCount = 0
    @Published private(set) var exporting = false
    struct ImageChoice: Identifiable {
        let id = UUID()
        let png: Data
        let name: String
    }
    @Published private(set) var images: [ImageChoice] = []
    @Published var imageBusy = false
    @Published var voiceNotice = ""
    @Published var imageError = ""
    @Published var dictating = false
    var stopDictation: () -> Void = {}
    var showImageChoice: () -> Void = {}
    private var watcher: ScreenshotFolder?
    private let screenshotFolder: URL
    private var watchID = UUID()
    @Published var folderNotice = ""
    @Published var projects: [Project] = []
    @Published var destination = "" { didSet { defaults.set(destination, forKey: "destination") } }
    @Published private(set) var live = false
    @Published private(set) var sessionOnly = false
    @Published var days = 7
    @Published var exclusions = "" { didSet { defaults.set(exclusions, forKey: "exclusions") } }
    let defaults: UserDefaults
    private let pb: NSPasteboard
    private var archive: Archive?
    private var clock: Timer?
    private var change = 0
    private var nextCleanup = Date.distantPast
    var target: NSRunningApplication?
    var dismiss: () -> Void = {}
    var updateIcon: () -> Void = {}
    var matches: [Record] { matching(query) }
    func matching(_ query: String) -> [Record] {
        let terms = query.split(whereSeparator: { $0.isWhitespace })
        return rows.filter { row in terms.allSatisfy { term in
            row.title.localizedStandardContains(String(term)) || row.searchable.localizedStandardContains(String(term))
        } }
    }
    var current: Record? { matches.first { $0.id == selection } }

    init(pasteboard: NSPasteboard = .general, defaults: UserDefaults = .standard, screenshotFolder: URL = ScreenshotFolder.systemFolder) {
        self.screenshotFolder = screenshotFolder
        self.pb = pasteboard
        self.defaults = defaults
        sessionOnly = defaults.bool(forKey: "session")
        days = defaults.object(forKey: "days") as? Int ?? 7
        exclusions = defaults.string(forKey: "exclusions") ?? ""
        if let data = defaults.data(forKey: "projects") {
            projects = (try? JSONDecoder().decode([Project].self, from: data)) ?? []
        }
        destination = defaults.string(forKey: "destination") ?? projects.first?.path ?? ""
        do {
            archive = try makeArchive(session: sessionOnly)
            try tidy()
            try refresh()
            live = defaults.object(forKey: "automaticCollection") as? Bool ?? true
        } catch { message = error.localizedDescription }
        change = pb.changeCount
        let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
        updateWatcher()
    }

    deinit { clock?.invalidate() }

    private func makeArchive(session: Bool) throws -> Archive {
        if session { return try Archive() }
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                  appropriateFor: nil, create: true)
        return try Archive(file: folder.appendingPathComponent("Projektfach/funde.sqlite"))
    }

    func mode(session: Bool) {
        guard session != sessionOnly else { return }
        do {
            let next = try makeArchive(session: session)
            try next.purge(before: Date().addingTimeInterval(-Double(days) * 86400))
            let entries = try next.list()
            clearChoices()
            archive = next
            rows = entries
            sessionOnly = session
            defaults.set(session, forKey: "session")
            change = pb.changeCount
            alignSelection()
        } catch { message = error.localizedDescription }
    }

    func retention(_ value: Int) {
        days = value
        defaults.set(value, forKey: "days")
        do { try tidy(); try refresh() } catch { message = error.localizedDescription }
    }

    private func tidy() throws {
        try archive?.purge(before: Date().addingTimeInterval(-Double(days) * 86400))
        nextCleanup = Date().addingTimeInterval(300)
    }

    func toggle() {
        guard archive != nil else { message = "Der Verlaufsspeicher ist nicht verfügbar."; return }
        change = pb.changeCount
        live.toggle()
        captureNotice = ""
        if live { showingProject = false; query = "" }
        defaults.set(live, forKey: "automaticCollection")
        updateWatcher()
        updateIcon()
    }

    private func alignSelection() {
        let visible = matches
        if !visible.contains(where: { $0.id == selection }) { selection = visible.first?.id }
    }

    func move(_ step: Int) {
        let visible = matches
        guard !visible.isEmpty else { return }
        let index = visible.firstIndex { $0.id == selection } ?? 0
        selection = visible[max(0, min(visible.count - 1, index + step))].id
    }

    private func refresh() throws { rows = try archive?.list() ?? []; alignSelection() }

    private func poll() {
        do {
            if Date() >= nextCleanup { try tidy(); try refresh() }
            guard live, let archive else { return }
            let blocked = "macOS blockiert die Zwischenablage. Erlaube Projektfach das Einsetzen aus anderen Apps in den Systemeinstellungen."
            if #available(macOS 15.4, *), pb.accessBehavior == .alwaysDeny {
                if captureNotice != blocked { captureNotice = blocked }
                return
            }
            if captureNotice == blocked { captureNotice = "" }
            guard pb.changeCount != change else { return }
            change = pb.changeCount
            captureNotice = ""
            let marked = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
                          "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword"]
            guard !(pb.types ?? []).contains(where: { marked.contains($0.rawValue) }) else { return }
            let excluded = exclusions.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init)
            let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
            let credentials = ["com.apple.Passwords", "com.apple.keychainaccess", "com.1password.1password",
                               "com.bitwarden.desktop", "org.keepassxc.keepassxc"]
            guard !(credentials + excluded).contains(where: { $0.caseInsensitiveCompare(source) == .orderedSame }) else { return }
            let text = pb.string(forType: .string)
            if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
                let names = urls.map(\.lastPathComponent)
                try archive.save(.files, payload: JSONEncoder().encode(urls.map(\.path)), title: names.first ?? "Datei",
                                 words: names.joined(separator: "\n"))
            } else if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !((text.hasPrefix("https://") || text.hasPrefix("http://")) && !text.contains(where: { $0.isWhitespace })
                        && (pb.types?.contains(.png) == true || pb.types?.contains(.tiff) == true)) {
                guard text.utf8.count <= 256 * 1024 else { captureNotice = "Text über 256 KiB übersprungen."; return }
                let title = text.split(whereSeparator: { $0.isNewline }).first.map { String($0.prefix(90)) } ?? "Text"
                try archive.save(.text, payload: Data(text.utf8), title: title, words: text)
            } else if let png = Self.png(pb) {
                guard png.count <= 12 * 1024 * 1024 else { captureNotice = "Bild über 12 MiB übersprungen."; return }
                offerImage(png, name: "Bild aus der Zwischenablage")
                return
            } else {
                captureNotice = "Kein lesbarer Inhalt. Kopiere Text, ein Bild oder eine Datei mit ⌘C. Falls macOS nachfragt, erlaube den Zugriff."
                return
            }
            let followNewest = selection == nil || selection == matches.first?.id
            try refresh()
            if followNewest { selection = matches.first?.id }
        } catch { message = error.localizedDescription }
    }

    private static func png(_ pb: NSPasteboard) -> Data? {
        if let png = pb.data(forType: .png) { return png }
        guard let data = pb.data(forType: .tiff), data.count <= 32 * 1024 * 1024,
              let bitmap = NSBitmapImageRep(data: data) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func updateWatcher() {
        watcher = nil
        watchID = UUID()
        let id = watchID
        folderNotice = ""
        guard live else { clearChoices(); return }
        do {
            watcher = try ScreenshotFolder(folder: screenshotFolder) { [weak self] png, name in
                DispatchQueue.main.async {
                    guard let self, self.watchID == id else { return }
                    self.offerImage(png, name: name)
                }
            } report: { [weak self] warning in
                DispatchQueue.main.async { if self?.watchID == id { self?.folderNotice = warning } }
            }
        } catch {
            folderNotice = "Kein Zugriff auf den Screenshot-Ordner „" + screenshotFolder.lastPathComponent + "“. Prüfe den Ordnerzugriff in den Systemeinstellungen."
        }
    }

    private func clearChoices() {
        images = []
        imageBusy = false
        imageError = ""
    }

    private func offerImage(_ png: Data, name: String) {
        guard live, !images.contains(where: { $0.png == png }) else { return }
        guard png.count <= 12 * 1024 * 1024, images.count < 12 else {
            captureNotice = "Bild übersprungen: maximal 12 MiB pro Bild und 12 offene Entscheidungen."
            return
        }
        images.append(ImageChoice(png: png, name: name))
        if images.count == 1 { showImageChoice() }
    }

    func skipImage() {
        guard !images.isEmpty, !imageBusy else { return }
        images.removeFirst()
        imageError = ""
    }

    func keepImage(textOnly: Bool) async {
        guard !imageBusy, let choice = images.first, let archive else { return }
        imageBusy = true
        imageError = ""
        defer { if images.first?.id == choice.id || images.isEmpty { imageBusy = false } }
        do {
            if textOnly {
                let words = try await Task.detached(priority: .userInitiated) {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    request.automaticallyDetectsLanguage = true
                    try VNImageRequestHandler(data: choice.png).perform([request])
                    return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                }.value
                guard images.first?.id == choice.id else { return }
                guard !words.isEmpty else { throw FachError("Kein Text erkannt. Du kannst das Bild behalten oder überspringen.") }
                try saveNote(words)
            } else {
                let id = try archive.save(.image, payload: choice.png, title: choice.name)
                query = ""
                try refresh()
                selection = id
                showingProject = false
                message = "Bild im Verlauf gespeichert."
            }
            imageBusy = false
            skipImage()
        } catch { if images.first?.id == choice.id { imageError = error.localizedDescription } }
    }

    func saveNote(_ draft: String) throws {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw FachError("Die Notiz ist leer.") }
        guard let archive else { throw FachError("Der Verlaufsspeicher ist nicht verfügbar.") }
        let title = text.split(whereSeparator: { $0.isNewline }).first.map { String($0.prefix(90)) } ?? "Notiz"
        let id = try archive.save(.text, payload: Data(text.utf8), title: title, words: text)
        query = ""
        try refresh()
        selection = id
        showingProject = false
        lastExport = nil
        message = "Notiz übernommen."
    }

    func addProject(browse: Bool = true) {
        let choose = NSOpenPanel()
        choose.canChooseFiles = false
        choose.canChooseDirectories = true
        choose.canCreateDirectories = true
        choose.prompt = "Projekt wählen"
        guard choose.runModal() == .OK, let url = choose.url else { return }
        chooseProject(url, browse: browse)
    }

    func chooseProject(_ url: URL, browse: Bool = true) {
        let project = Project(path: url.standardizedFileURL.path)
        if !projects.contains(project) { projects.append(project) }
        defaults.set(try? JSONEncoder().encode(projects), forKey: "projects")
        destination = project.path
        lastExport = nil
        showingProject = browse
        if browse { browser.load(destination) }
    }

    func export(automatic: Bool = false) {
        guard automatic || !exporting, let record = current, let store = archive else { return }
        if destination.isEmpty { addProject(browse: false) }
        guard !destination.isEmpty else { return }
        do {
            let data = try store.data(record.id)
            let root = URL(fileURLWithPath: destination)
            exportCount += 1
            exporting = true
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try ProjectExport.write(record, data: data, to: root) }
                DispatchQueue.main.async {
                    self.exportCount -= 1
                    self.exporting = self.exportCount > 0
                    do {
                        let folder = try result.get()
                        self.lastExport = folder
                        self.message = "Abgelegt in " + root.lastPathComponent
                        if self.showingProject { self.browser.load(self.destination) }
                    }
                    catch { self.message = error.localizedDescription }
                }
            }
        } catch { message = error.localizedDescription }
    }

    func erase(all: Bool) {
        do {
            if all { try archive?.clear() }
            else if let selection { try archive?.delete(selection) }
            try refresh()
        } catch { message = error.localizedDescription }
    }

    func preview(_ record: Record) -> NSImage? {
        guard record.kind == .image, let bytes = try? archive?.data(record.id) else { return nil }
        return NSImage(data: bytes)
    }

    func copyToPasteboard(_ record: Record) throws {
        guard let archive else { throw FachError("Der Verlaufsspeicher ist nicht verfügbar.") }
        let bytes = try archive.data(record.id)
        let objects: [NSPasteboardWriting]
        switch record.kind {
        case .text: objects = [String(decoding: bytes, as: UTF8.self) as NSString]
        case .image:
            guard let image = NSImage(data: bytes) else { throw FachError("Das Bild kann nicht geöffnet werden.") }
            objects = [image]
        case .files:
            let paths = try JSONDecoder().decode([String].self, from: bytes)
            guard paths.allSatisfy(FileManager.default.fileExists(atPath:)) else { throw FachError("Mindestens eine Datei wurde verschoben oder gelöscht.") }
            objects = paths.map { URL(fileURLWithPath: $0) as NSURL }
        }
        pb.clearContents()
        guard pb.writeObjects(objects) else { throw FachError("Die Zwischenablage konnte nicht beschrieben werden.") }
        change = pb.changeCount
    }

    func use(paste: Bool) {
        guard let record = current else { return }
        do {
            try copyToPasteboard(record)
            guard paste, let target, !target.isTerminated else { message = "Kopiert. Mit ⌘V einsetzen."; return }
            guard AXIsProcessTrusted() else { message = "Kopiert. Nutze ⌘V oder erlaube Direkt-Einfügen unter Bedienungshilfen."; return }
            dismiss()
            pasteInto(target)
        } catch { message = error.localizedDescription }
    }

    func pasteInto(_ target: NSRunningApplication) {
        let copiedChange = pb.changeCount
        if !target.isActive { target.activate(options: []) }
        Task { @MainActor in
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(30))
                guard pb.changeCount == copiedChange, !target.isTerminated else { return }
                if target.isActive {
                    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
                          let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else { break }
                    down.flags = .maskCommand
                    up.flags = .maskCommand
                    down.postToPid(target.processIdentifier)
                    up.postToPid(target.processIdentifier)
                    return
                }
            }
            message = "Kopiert. Aktiviere das Zielfenster und füge mit ⌘V ein."
        }
    }
}
