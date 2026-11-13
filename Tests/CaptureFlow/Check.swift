import AppKit
import FachCore

@main
struct CaptureFlowCheck {
    @MainActor static func wait(_ description: String, until predicate: () -> Bool) async throws {
        let limit = Date().addingTimeInterval(5)
        while !predicate(), Date() < limit {
            try await Task.sleep(for: .milliseconds(50))
        }
        guard predicate() else { throw FachError(description) }
    }

    @MainActor static func main() async throws {
        let board = NSPasteboard.withUniqueName()
        let suite = "projektfach-check-" + UUID().uuidString
        let settings = UserDefaults(suiteName: suite)!
        settings.set(true, forKey: "session")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer {
            board.releaseGlobally()
            settings.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        let desk = Desk(pasteboard: board, defaults: settings, screenshotFolder: folder)
        func copy(_ text: String) {
            board.clearContents()
            board.setString(text, forType: .string)
        }
        guard desk.live else { throw FachError("Automatisches Sammeln ist beim Start aus") }
        copy("Erster Fund")
        try await wait("Erste Kopie erscheint nicht") { desk.current?.title == "Erster Fund" }
        copy("Zweiter Fund")
        try await wait("Neue Kopie fehlt in der Vorschau") { desk.rows.count == 2 && desk.current?.title == "Zweiter Fund" }
        guard let first = desk.matching("Erster Fund").first else { throw FachError("Schnellsuche findet den Text nicht") }
        try desk.copyToPasteboard(first)
        guard board.string(forType: .string) == "Erster Fund", desk.current?.title == "Zweiter Fund" else {
            throw FachError("Schnellauswahl kopiert die falsche Zeile")
        }
        _ = NSApplication.shared
        let picker = QuickPaste()
        picker.show(desk: desk, target: NSRunningApplication.current)
        guard picker.isVisible, let panel = NSApp.windows.first(where: { $0.title == "Schnell einfügen" && $0.isVisible }),
              panel.styleMask.contains(.nonactivatingPanel), panel.frame.height <= (panel.screen?.visibleFrame.height ?? 0) * 0.6 else {
            throw FachError("Kompaktes Einfügefenster fehlt")
        }
        picker.close()
        guard !picker.isVisible, !panel.isVisible else { throw FachError("Auswahlfenster noch sichtbar") }
        print("✓ Schnellauswahl öffnen, schließen und eine andere Zeile als die Hauptauswahl kopieren")
        desk.chooseProject(folder)
        try await wait("Ordner konnte nicht gelesen werden") { !desk.browser.loading }
        guard desk.showingProject, desk.browser.entries.isEmpty, desk.browser.error.isEmpty else {
            throw FachError("Falscher Zustand für leeres Projekt")
        }
        desk.showingProject = false
        desk.export()
        try await wait("Ablage fehlt") { desk.lastExport != nil }
        guard let saved = desk.lastExport, try String(contentsOf: saved.appendingPathComponent("Notiz.md"), encoding: .utf8) == "Zweiter Fund" else {
            throw FachError("Exportierter Inhalt falsch")
        }
        desk.chooseProject(folder)
        try await wait("Ablage im Projektordner unsichtbar") { desk.browser.entries.first?.url.lastPathComponent == saved.lastPathComponent }
        desk.toggle()
        copy("Während der Pause")
        try await Task.sleep(for: .milliseconds(800))
        guard desk.rows.count == 2 else { throw FachError("Aufnahme läuft trotz Pause") }
        desk.query = "Alter Suchfilter"
        try desk.saveNote("  Eine diktierte Idee.  ")
        guard !desk.live, desk.query.isEmpty, desk.current?.searchable == "Eine diktierte Idee.",
              desk.rows.count == 3, !desk.showingProject else { throw FachError("Diktat im Verlauf fehlt") }
        desk.export()
        try await wait("Diktat wurde nicht exportiert") { desk.lastExport != nil }
        guard let note = desk.lastExport, try String(contentsOf: note.appendingPathComponent("Notiz.md"), encoding: .utf8) == "Eine diktierte Idee." else {
            throw FachError("Diktat im Projektordner fehlerhaft")
        }
        print("✓ Diktattext übernehmen und bei pausierter Zwischenablage als Markdown ablegen")
        desk.toggle()
        let testImage = NSImage(size: NSSize(width: 900, height: 150))
        testImage.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 900, height: 150).fill()
        ("Projektfach Bildprobe" as NSString).draw(at: NSPoint(x: 30, y: 40),
            withAttributes: [.font: NSFont.systemFont(ofSize: 50), .foregroundColor: NSColor.black])
        testImage.unlockFocus()
        let png = NSBitmapImageRep(data: testImage.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        let before = desk.rows.count
        try png.write(to: folder.appendingPathComponent("Bildschirmfoto 2026-11-13.png"), options: .atomic)
        try await wait("Screenshot-Datei löst keine Nachfrage aus") { desk.images.count == 1 }
        guard desk.rows.count == before else { throw FachError("Bild vor Entscheidung gespeichert") }
        await desk.keepImage(textOnly: true)
        guard desk.current?.searchable.localizedCaseInsensitiveContains("Bildprobe") == true else { throw FachError("OCR: " + desk.imageError + " / " + (desk.current?.title ?? "leer")) }
        guard !desk.rows.contains(where: { $0.kind == .image }) else { throw FachError("Bild bei Nur Text gespeichert") }
        board.clearContents()
        board.setData(png, forType: .png)
        try await wait("Bild aus Zwischenablage fehlt") { desk.images.count == 1 }
        await desk.keepImage(textOnly: false)
        try await wait("Bild nicht gespeichert") { desk.current?.kind == .image }
        let kept = desk.rows.filter { $0.kind != .image }.map(\.id)
        desk.erase(all: false)
        guard desk.rows.map(\.id) == kept else { throw FachError("Einzellöschung hat falsche Einträge entfernt") }
        desk.query = "Erster Fund"
        desk.erase(all: true)
        guard desk.rows.isEmpty, desk.current == nil, board.data(forType: .png) == png,
              FileManager.default.fileExists(atPath: saved.appendingPathComponent("Notiz.md").path) else {
            throw FachError("Verlauf leeren bei aktiver Suche fehlerhaft")
        }
        print("✓ Einzelnen Eintrag und gesamten gefilterten Verlauf löschen")
        print("✓ Screenshot-Datei, OCR ohne Bildspeicherung und Bildwahl aus der Zwischenablage")
        print("✓ Aufnehmen, neue Auswahl, Ordnerwahl, Export, Ordneransicht und Pause")
    }
}
