import Foundation

public enum ProjectExport {
    public static func write(_ record: Record, data: Data, to root: URL) throws -> URL {
        let fm = FileManager.default
        let identifier = UUID().uuidString
        let temporary = root.appendingPathComponent(".griffbereit-" + identifier, isDirectory: true)
        try fm.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { if fm.fileExists(atPath: temporary.path) { try? fm.removeItem(at: temporary) } }
        let words = record.title.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let label = String(words.prefix(6).joined(separator: "-").prefix(48))
        let day = ISO8601DateFormatter().string(from: record.date).prefix(10)
        let target = root.appendingPathComponent("\(day) \(label.isEmpty ? "Fund" : label) \(identifier.prefix(8))")
        switch record.kind {
        case .text: try data.write(to: temporary.appendingPathComponent("Notiz.md"))
        case .image:
            try data.write(to: temporary.appendingPathComponent("Bild.png"))
            if !record.searchable.isEmpty {
                let note = "![Gespeichertes Bild](Bild.png)\n\n" + record.searchable + "\n"
                try Data(note.utf8).write(to: temporary.appendingPathComponent("Bildnotiz.md"))
            }
        case .files:
            let paths = try JSONDecoder().decode([String].self, from: data)
            guard !paths.isEmpty else { throw FachError("Der Eintrag enthält keine Dateien.") }
            for path in paths {
                let source = URL(fileURLWithPath: path)
                let info = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard info.isRegularFile == true, info.isSymbolicLink != true else {
                    throw FachError("Nur vorhandene reguläre Dateien lassen sich ablegen.")
                }
                var destination = temporary.appendingPathComponent(source.lastPathComponent)
                var suffix = 2
                while fm.fileExists(atPath: destination.path) {
                    destination = temporary.appendingPathComponent("\(suffix)-\(source.lastPathComponent)")
                    suffix += 1
                }
                try fm.copyItem(at: source, to: destination)
            }
        }
        try fm.moveItem(at: temporary, to: target)
        return target
    }
}
