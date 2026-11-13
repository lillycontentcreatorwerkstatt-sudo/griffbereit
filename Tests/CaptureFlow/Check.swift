import AppKit
import FachCore

@main
struct CaptureFlowCheck {
    @MainActor static func wait(_ description: String, until predicate: () -> Bool) throws {
        let limit = Date().addingTimeInterval(5)
        while !predicate(), Date() < limit {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        guard predicate() else { throw FachError(description) }
    }

    @MainActor static func main() throws {
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
        let desk = Desk(pasteboard: board, defaults: settings)
        func copy(_ text: String) {
            board.clearContents()
            board.setString(text, forType: .string)
        }
        copy("Vor dem Start")
        desk.toggle()
        copy("Erster Fund")
        try wait("Erste Kopie erscheint nicht") { desk.current?.title == "Erster Fund" }
        copy("Zweiter Fund")
        try wait("Neue Kopie fehlt in der Vorschau") { desk.rows.count == 2 && desk.current?.title == "Zweiter Fund" }
        desk.chooseProject(folder)
        try wait("Ordner konnte nicht gelesen werden") { !desk.browser.loading }
        guard desk.showingProject, desk.browser.entries.isEmpty, desk.browser.error.isEmpty else {
            throw FachError("Falscher Zustand für leeres Projekt")
        }
        desk.showingProject = false
        desk.export()
        try wait("Ablage fehlt") { desk.lastExport != nil }
        guard let saved = desk.lastExport, try String(contentsOf: saved.appendingPathComponent("Notiz.md"), encoding: .utf8) == "Zweiter Fund" else {
            throw FachError("Exportierter Inhalt falsch")
        }
        desk.chooseProject(folder)
        try wait("Ablage im Projektordner unsichtbar") { desk.browser.entries.first?.url.lastPathComponent == saved.lastPathComponent }
        desk.toggle()
        copy("Während der Pause")
        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
        guard desk.rows.count == 2 else { throw FachError("Aufnahme läuft trotz Pause") }
        print("✓ Aufnehmen, neue Auswahl, Ordnerwahl, Export, Ordneransicht und Pause")
    }
}
