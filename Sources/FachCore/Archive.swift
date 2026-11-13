import Foundation
import CryptoKit
import CSQLite

public enum Kind: String, Sendable { case text, image, files }

public struct Record: Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: Kind
    public let title: String
    public let searchable: String
    public let date: Date
}

public struct FachError: LocalizedError {
    public let errorDescription: String?
    public init(_ reason: String) { errorDescription = reason }
}

public final class Archive {
    private var db: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(file: URL? = nil) throws {
        if let file {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        guard sqlite3_open(file?.path ?? ":memory:", &db) == SQLITE_OK else { throw failure() }
        try statement("PRAGMA secure_delete=ON", []) { handle in
            guard sqlite3_step(handle) == SQLITE_ROW, sqlite3_column_int(handle, 0) == 1 else { throw failure() }
        }
        try execute("""
            CREATE TABLE IF NOT EXISTS clip(
                id TEXT PRIMARY KEY, kind TEXT NOT NULL, title TEXT NOT NULL,
                words TEXT NOT NULL, touched REAL NOT NULL, payload BLOB NOT NULL)
            """)
    }

    deinit { sqlite3_close(db) }

    private func failure() -> FachError {
        FachError(db.map { String(cString: sqlite3_errmsg($0)) } ?? "Der Speicher ist nicht verfügbar.")
    }

    private enum Value { case text(String), bytes(Data), number(Double) }

    private func statement<T>(_ sql: String, _ values: [Value], _ body: (OpaquePointer) throws -> T) throws -> T {
        var handle: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &handle, nil) == SQLITE_OK, let handle else { throw failure() }
        defer { sqlite3_finalize(handle) }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .number(let number): result = sqlite3_bind_double(handle, index, number)
            case .text(let text):
                result = text.withCString { sqlite3_bind_text(handle, index, $0, Int32(text.utf8.count), transient) }
            case .bytes(let data):
                result = data.withUnsafeBytes { sqlite3_bind_blob(handle, index, $0.baseAddress, Int32($0.count), transient) }
            }
            guard result == SQLITE_OK else { throw failure() }
        }
        return try body(handle)
    }

    private func execute(_ sql: String, _ values: [Value] = []) throws {
        try statement(sql, values) { guard sqlite3_step($0) == SQLITE_DONE else { throw failure() } }
    }

    @discardableResult
    public func save(_ kind: Kind, payload: Data, title: String, words: String = "", now: Date = Date()) throws -> String {
        guard !payload.isEmpty, payload.count <= 12 * 1024 * 1024 else {
            throw FachError("Leere Inhalte und Einträge über 12 MB werden übersprungen.")
        }
        let id = kind.rawValue + SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        try execute("BEGIN IMMEDIATE")
        do {
            try execute("""
                INSERT INTO clip VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET touched=excluded.touched
                """, [.text(id), .text(kind.rawValue), .text(title), .text(words), .number(now.timeIntervalSince1970), .bytes(payload)])
            try execute("""
                DELETE FROM clip WHERE id IN (SELECT id FROM clip ORDER BY touched DESC, rowid DESC LIMIT -1 OFFSET 150)
                """)
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
        return id
    }

    public func setWords(_ words: String, id: String) throws {
        try execute("UPDATE clip SET words=? WHERE id=?", [.text(words), .text(id)])
    }

    public func purge(before date: Date) throws {
        try execute("DELETE FROM clip WHERE touched < ?", [.number(date.timeIntervalSince1970)])
    }

    public func delete(_ id: String) throws { try execute("DELETE FROM clip WHERE id=?", [.text(id)]) }
    public func clear() throws { try execute("DELETE FROM clip") }

    public func list() throws -> [Record] {
        try statement("SELECT id,kind,title,words,touched FROM clip ORDER BY touched DESC, rowid DESC", []) { s in
            func string(_ i: Int32) -> String {
                String(decoding: UnsafeBufferPointer(start: sqlite3_column_text(s, i), count: Int(sqlite3_column_bytes(s, i))), as: UTF8.self)
            }
            var records = [Record]()
            while true {
                switch sqlite3_step(s) {
                case SQLITE_ROW:
                    guard let kind = Kind(rawValue: string(1)) else { throw FachError("Unbekannter Eintragstyp.") }
                    records.append(Record(id: string(0), kind: kind, title: string(2), searchable: string(3),
                                          date: Date(timeIntervalSince1970: sqlite3_column_double(s, 4))))
                case SQLITE_DONE: return records
                default: throw failure()
                }
            }
        }
    }

    public func data(_ id: String) throws -> Data {
        try statement("SELECT payload FROM clip WHERE id=?", [.text(id)]) { s in
            switch sqlite3_step(s) {
            case SQLITE_ROW: return Data(bytes: sqlite3_column_blob(s, 0), count: Int(sqlite3_column_bytes(s, 0)))
            case SQLITE_DONE: throw FachError("Dieser Eintrag ist nicht mehr im Verlauf.")
            default: throw failure()
            }
        }
    }
}
