import AppKit
import CoreServices
import Darwin

/// Watch the macOS screenshot destination. Existing files establish the baseline.
final class ScreenshotFolder {
    static var systemFolder: URL {
        let value = UserDefaults.standard.persistentDomain(forName: "com.apple.screencapture")?["location"] as? String
        if let value, !value.isEmpty { return URL(fileURLWithPath: NSString(string: value).expandingTildeInPath) }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }

    private let queue = DispatchQueue(label: "Griffbereit.screenshots", qos: .utility)
    private let source: DispatchSourceFileSystemObject
    private let folder: URL
    private let receive: (Data, String) -> Void
    private let report: (String) -> Void
    private var seen: Set<URL>
    private var scheduled: DispatchWorkItem?

    init(folder: URL, receive: @escaping (Data, String) -> Void, report: @escaping (String) -> Void) throws {
        self.folder = folder
        self.receive = receive
        self.report = report
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EACCES) }
        do { seen = Set(try Self.images(in: folder)) } catch { close(descriptor); throw error }
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: queue)
        source.setEventHandler { [weak self] in self?.schedule() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        queue.async { [weak self] in self?.schedule() }
    }
    deinit { source.cancel() }

    private static func images(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            .filter { ["png", "jpg", "jpeg", "tif", "tiff", "heic"].contains($0.pathExtension.lowercased()) }
    }

    static func isScreenshot(_ url: URL) -> Bool {
        if let item = MDItemCreateWithURL(nil, url as CFURL),
           (MDItemCopyAttribute(item, "kMDItemIsScreenCapture" as CFString) as? NSNumber)?.boolValue == true { return true }
        if getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, XATTR_NOFOLLOW) > 0 { return true }
        let name = url.deletingPathExtension().lastPathComponent.lowercased()
        return ["bildschirmfoto ", "screenshot ", "screen shot "].contains(where: name.hasPrefix)
    }

    private func schedule() {
        scheduled?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.scan() }
        scheduled = item
        queue.asyncAfter(deadline: .now() + .milliseconds(450), execute: item)
    }

    private func scan() {
        do {
            let current = Set(try Self.images(in: folder))
            let new = current.subtracting(seen).sorted { $0.lastPathComponent < $1.lastPathComponent }
            seen = current
            for url in new where Self.isScreenshot(url) {
                do {
                    let info = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
                    guard info.isRegularFile == true, info.isSymbolicLink != true else { continue }
                    guard (info.fileSize ?? 0) <= 32 * 1024 * 1024 else { report("Screenshot ist zu groß."); continue }
                    let bytes = try Data(contentsOf: url)
                    let png: Data?
                    if url.pathExtension.lowercased() == "png" { png = bytes }
                    else { png = NSBitmapImageRep(data: bytes)?.representation(using: .png, properties: [:]) }
                    if let png, !png.isEmpty { receive(png, url.lastPathComponent) }
                    else { report("Screenshot konnte nicht gelesen werden.") }
                } catch { report("Screenshot konnte nicht gelesen werden: " + error.localizedDescription) }
            }
        } catch { report("Screenshot-Ordner: " + error.localizedDescription) }
    }
}
