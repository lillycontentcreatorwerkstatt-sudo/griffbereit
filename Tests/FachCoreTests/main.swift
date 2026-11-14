import Foundation
import FachCore

private struct CheckFailure: Error {
    let line: UInt
}

private func equal<T: Equatable>(_ actual: T, _ expected: T, line: UInt = #line) throws {
    guard actual == expected else { throw CheckFailure(line: line) }
}
private func first<T>(_ value: T?, line: UInt = #line) throws -> T {
    guard let value else { throw CheckFailure(line: line) }
    return value
}
private func expectFailure<T>(_ operation: @autoclosure () throws -> T, line: UInt = #line) throws {
    do { _ = try operation() } catch { return }
    throw CheckFailure(line: line)
}

final class ArchiveChecks {
    private var temporaryDirectories = [URL]()
    deinit { for dir in temporaryDirectories { try? FileManager.default.removeItem(at: dir) } }
    private func directory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        temporaryDirectories.append(dir)
        return dir
    }

    func testReopenKeepsContentAndRecognizedWords() throws {
        let file = try directory().appendingPathComponent("test.sqlite")
        let data = Data([5, 7, 8])
        do {
            let store = try Archive(file: file)
            let id = try store.save(.image, payload: data, title: "Bild")
            try store.setWords("Projektplan", id: id)
            try store.save(.image, payload: data, title: "Bild")
        }
        let recovered = try Archive(file: file)
        let rows = try recovered.list()
        try equal(rows.count, 1)
        try equal(rows.first?.searchable, "Projektplan")
        try equal(try recovered.data(first(rows.first).id), data)
    }

    func testRetentionAndMemoryIsolation() throws {
        let store = try Archive()
        let recent = try store.save(.text, payload: Data("jetzt".utf8), title: "jetzt")
        try store.save(.text, payload: Data("alt".utf8), title: "alt", now: .distantPast)
        try store.purge(before: Date(timeIntervalSince1970: 100))
        try equal(try store.list().map(\.id), [recent])
        try equal(try Archive().list().isEmpty, true)
        try store.delete(recent)
        try expectFailure(try store.data(recent))
    }

    func testLimitAndClear() throws {
        let store = try Archive()
        for i in 0..<155 {
            try store.save(.text, payload: Data(String(i).utf8), title: String(i), now: Date(timeIntervalSince1970: Double(i)))
        }
        try equal(try store.list().count, 150)
        try equal(try store.list().last?.title, "5")
        try store.clear()
        try equal(try store.list().isEmpty, true)
    }

    func testImageAndMarkdownAreExportedTogetherWithoutOverwrite() throws {
        let root = try directory()
        let store = try Archive()
        let bytes = Data([0, 1, 2])
        try store.save(.image, payload: bytes, title: "Bild", words: "Bildtext")
        let row = try first(store.list().first)
        let a = try ProjectExport.write(row, data: bytes, to: root)
        let b = try ProjectExport.write(row, data: bytes, to: root)
        try equal(a != b, true)
        try equal(try Data(contentsOf: a.appendingPathComponent("Bild.png")), bytes)
        try equal(try String(contentsOf: a.appendingPathComponent("Bildnotiz.md")), "![Gespeichertes Bild](Bild.png)\n\nBildtext\n")
    }

    func testMissingSecondFileLeavesNoPartialExport() throws {
        let root = try directory()
        let source = root.appendingPathComponent("Quelle.txt")
        try Data("Memo".utf8).write(to: source)
        let payload = try JSONEncoder().encode([source.path, source.path + "-fehlt"])
        let store = try Archive()
        try store.save(.files, payload: payload, title: "Auswahl")
        let row = try first(store.list().first)
        try expectFailure(try ProjectExport.write(row, data: payload, to: root))
        try equal(try FileManager.default.contentsOfDirectory(atPath: root.path), ["Quelle.txt"])
    }

    func testTextExportIsByteExact() throws {
        let root = try directory()
        let store = try Archive()
        let bytes = Data("Grüße\nProjekt ①\n".utf8)
        try store.save(.text, payload: bytes, title: "../Probe")
        let row = try first(store.list().first)
        let folder = try ProjectExport.write(row, data: bytes, to: root)
        try equal(try Data(contentsOf: folder.appendingPathComponent("Notiz.md")), bytes)
        try equal(folder.deletingLastPathComponent().path, root.path)
    }

    func testExportFolderUsesLocalDay() throws {
        let root = try directory()
        let store = try Archive()
        let bytes = Data("Nachts".utf8)
        let night = Calendar.current.startOfDay(for: Date()).addingTimeInterval(1800)
        try store.save(.text, payload: bytes, title: "Nachts", now: night)
        let folder = try ProjectExport.write(try first(store.list().first), data: bytes, to: root)
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: night)
        let expected = String(format: "%04d-%02d-%02d ", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        try equal(folder.lastPathComponent.hasPrefix(expected), true)
    }
}

do {
    let checks = ArchiveChecks()
    try checks.testReopenKeepsContentAndRecognizedWords()
    print("✓ testReopenKeepsContentAndRecognizedWords")
    try checks.testRetentionAndMemoryIsolation()
    print("✓ testRetentionAndMemoryIsolation")
    try checks.testLimitAndClear()
    print("✓ testLimitAndClear")
    try checks.testImageAndMarkdownAreExportedTogetherWithoutOverwrite()
    print("✓ testImageAndMarkdownAreExportedTogetherWithoutOverwrite")
    try checks.testMissingSecondFileLeavesNoPartialExport()
    print("✓ testMissingSecondFileLeavesNoPartialExport")
    try checks.testTextExportIsByteExact()
    print("✓ testTextExportIsByteExact")
    try checks.testExportFolderUsesLocalDay()
    print("✓ testExportFolderUsesLocalDay")
} catch {
    FileHandle.standardError.write(Data("Fehlgeschlagen: \(error)\n".utf8))
    exit(1)
}
