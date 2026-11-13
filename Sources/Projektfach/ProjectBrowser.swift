import AppKit

struct FolderEntry: Identifiable {
    let url: URL
    let directory: Bool
    var id: URL { url }
}

@MainActor
final class ProjectBrowser: ObservableObject {
    @Published private(set) var entries: [FolderEntry] = []
    @Published private(set) var loading = false
    @Published private(set) var error = ""
    private var request = UUID()

    func load(_ path: String) {
        request = UUID()
        let token = request
        entries = []
        error = ""
        loading = !path.isEmpty
        guard loading else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result {
                try FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: path),
                    includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                    .map { url in FolderEntry(url: url, directory: try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true) }
                    .sorted { lhs, rhs in
                        if lhs.directory != rhs.directory { return lhs.directory }
                        return lhs.url.lastPathComponent.localizedStandardCompare(rhs.url.lastPathComponent) == .orderedAscending
                    }
            }
            DispatchQueue.main.async {
                guard self.request == token else { return }
                self.loading = false
                do { self.entries = try result.get() }
                catch { self.error = error.localizedDescription }
            }
        }
    }
}
