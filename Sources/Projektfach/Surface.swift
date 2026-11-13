import SwiftUI
import FachCore

private extension Kind {
    var label: String { switch self { case .text: return "Text"; case .image: return "Bild"; case .files: return "Dateien" } }
    var symbol: String { switch self { case .text: return "text.alignleft"; case .image: return "photo"; case .files: return "doc.on.doc" } }
}

struct KeyEditor: NSViewRepresentable {
    @ObservedObject var keys: HotKey
    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.bezelStyle = .rounded
        button.target = button
        button.action = #selector(RecorderButton.begin)
        button.setAccessibilityLabel("Globales Tastenkürzel ändern")
        return button
    }
    func updateNSView(_ button: RecorderButton, context: Context) {
        button.configured = keys.choice.label
        if !button.listening { button.title = keys.choice.label }
        button.record = { keys.register($0) }
    }
}

struct Surface: View {
    @ObservedObject var desk: Desk
    @ObservedObject var keys: HotKey
    @State private var dictating = false
    @State private var settings = false
    @State private var confirmClear = false
    @FocusState private var searchFocus: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "tray.2.fill").font(.title2).foregroundStyle(Color.accentColor)
                Text("Projektfach").font(.title2.weight(.semibold))
                Spacer()
                Button { dictating = true } label: {
                    Label("Diktieren", systemImage: "mic.fill")
                }.buttonStyle(.borderedProminent)
                Button { settings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Einstellungen").help("Einstellungen")
            }.padding(16)
            Divider()
            HStack {
                Picker("Ansicht", selection: $desk.showingProject) {
                    Text("Zwischenablage (\(desk.rows.count))").tag(false)
                    Text("Projektordner").tag(true)
                }.labelsHidden().pickerStyle(.segmented).fixedSize()
                Spacer()
                Toggle("Kopiertes sammeln", isOn: Binding(get: { desk.live }, set: { enabled in
                    if desk.live != enabled { desk.toggle() }
                })).toggleStyle(.switch).controlSize(.small)
            }.padding(.horizontal, 14).padding(.vertical, 8)
            if desk.live && !desk.captureNotice.isEmpty {
                Text(desk.captureNotice).font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14)
            }
            Divider()
            if desk.showingProject {
                ProjectContents(desk: desk, browser: desk.browser)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Verlauf und Bildtext suchen", text: $desk.query)
                        .textFieldStyle(.plain).focused($searchFocus)
                        .onSubmit { desk.use(paste: true) }
                        .onKeyPress(.downArrow) { desk.move(1); return .handled }
                        .onKeyPress(.upArrow) { desk.move(-1); return .handled }
                    if !desk.query.isEmpty {
                        Button { desk.query = ""; searchFocus = true } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).accessibilityLabel("Suche leeren")
                    }
                }.padding(14)
                Divider()
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Verlauf").font(.headline).padding(.horizontal, 14).padding(.vertical, 10)
                        if desk.matches.isEmpty {
                            Text(desk.query.isEmpty ? (desk.live ? "Kopiere in einer anderen App Text, ein Bild oder eine Datei mit ⌘C." : "Diktiere eine Notiz oder aktiviere „Kopiertes sammeln“.") : "Keine passenden Einträge.")
                                .foregroundStyle(.secondary).padding(.horizontal, 14)
                            Spacer()
                        } else {
                            ScrollViewReader { proxy in
                                List(desk.matches, selection: $desk.selection) { row in
                                    HStack {
                                        Image(systemName: row.kind.symbol).frame(width: 20)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(row.kind == .image && !row.searchable.isEmpty ? row.searchable : row.title).lineLimit(1)
                                            Text("\(row.kind.label) · \(row.date.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }.padding(.vertical, 3).tag(row.id).id(row.id)
                                }.listStyle(.sidebar)
                                .onChange(of: desk.selection) { _, id in if let id { proxy.scrollTo(id) } }
                                .onKeyPress(.return) { desk.use(paste: true); return .handled }
                            }
                        }
                    }.frame(width: 265).frame(maxHeight: .infinity)
                    Divider()
                    if let row = desk.current {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(row.kind.label, systemImage: row.kind.symbol).font(.headline).foregroundStyle(.secondary)
                                if row.kind == .image, let image = desk.preview(row) {
                                    Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 180).accessibilityLabel("Bildvorschau")
                                }
                                Text(desk.reading.contains(row.id) ? "Bildtext wird erkannt …" :
                                     (row.searchable.isEmpty ? "Kein lesbarer Text." : row.searchable))
                                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                            }.padding(20)
                        }.frame(maxWidth: .infinity)
                    } else {
                        ContentUnavailableView("Vorschau", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            Divider()
            HStack {
                Menu {
                    ForEach(desk.projects) { project in
                        Button(project.path) { desk.chooseProject(URL(fileURLWithPath: project.path)) }
                    }
                    Divider()
                    Button("Projektordner hinzufügen …") { desk.addProject() }
                } label: { Label(desk.destination.isEmpty ? "Projekt wählen" : URL(fileURLWithPath: desk.destination).lastPathComponent,
                                 systemImage: "folder") }
                .fixedSize()
                Spacer()
                if !desk.showingProject {
                    Button("Kopieren") { desk.use(paste: false) }.disabled(desk.current == nil)
                    Button(desk.exporting ? "Legt ab …" : "Im Projekt ablegen") { desk.export() }
                        .keyboardShortcut(.return, modifiers: .command).buttonStyle(.borderedProminent)
                        .disabled(desk.current == nil || desk.exporting || desk.reading.contains(desk.selection ?? ""))
                } else if !desk.destination.isEmpty {
                    Button("Ordner im Finder öffnen") { NSWorkspace.shared.open(URL(fileURLWithPath: desk.destination)) }
                }
            }.padding(12)
            if !desk.message.isEmpty || !keys.problem.isEmpty {
                HStack {
                    Text(desk.message.isEmpty ? keys.problem : desk.message).font(.callout)
                    Spacer()
                    if let url = desk.lastExport {
                        Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    }
                    Button("OK") { desk.message = ""; keys.problem = ""; desk.lastExport = nil }.controlSize(.small)
                }.padding(.horizontal, 14).padding(.bottom, 10)
            }
        }
        .frame(minWidth: 650, minHeight: 400)
        .onChange(of: desk.showingProject) { _, showing in
            if showing { desk.browser.load(desk.destination) } else { searchFocus = true }
        }
        .onAppear { searchFocus = true }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in if !settings { searchFocus = true } }
        .onExitCommand { desk.dismiss() }
        .sheet(isPresented: $dictating) { DictationSheet(desk: desk) }
        .sheet(isPresented: $settings) {
            Form {
                Section("Bedienung") { LabeledContent("Verlauf öffnen") { KeyEditor(keys: keys).frame(width: 142) }
                    if !keys.problem.isEmpty { Text(keys.problem) }
                }
                Section("Aufbewahrung") {
                    Toggle("Nur für diese Sitzung speichern", isOn: Binding(get: { desk.sessionOnly }, set: { desk.mode(session: $0) }))
                    Text("Beim Wechsel zurück zum lokalen Verlauf werden die Sitzungseinträge verworfen. Der lokale Verlauf bleibt separat gespeichert.")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Aufbewahren", selection: Binding(get: { desk.days }, set: { desk.retention($0) })) {
                        ForEach([1, 7, 30], id: \.self) { Text("\($0) Tage").tag($0) }
                    }
                    TextField("Ausgeschlossene App-IDs", text: $desk.exclusions, prompt: Text("z. B. com.apple.mail"))
                    Text("Mehrere Bundle-IDs mit Komma trennen.").font(.caption)
                    Button("Aktuellen Verlauf leeren …", role: .destructive) { confirmClear = true }
                }
                HStack {
                    Button("App beenden") { NSApp.terminate(nil) }
                    Spacer()
                    Button("Fertig") { settings = false }.keyboardShortcut(.defaultAction)
                }
            }.formStyle(.grouped).frame(width: 480, height: 435)
            .confirmationDialog("Aktuellen Verlauf vollständig löschen?", isPresented: $confirmClear) {
                Button("Verlauf löschen", role: .destructive) { desk.erase(all: true) }
            }
        }
    }
}

private struct ProjectContents: View {
    @ObservedObject var desk: Desk
    @ObservedObject var browser: ProjectBrowser

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(desk.destination.isEmpty ? "Projektordner" : URL(fileURLWithPath: desk.destination).lastPathComponent)
                    .font(.headline).lineLimit(1).help(desk.destination)
                Spacer()
                if !desk.destination.isEmpty {
                    Button { browser.load(desk.destination) } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Ordner aktualisieren")
                }
            }.padding(14)
            if desk.destination.isEmpty {
                ContentUnavailableView {
                    Label("Projektordner wählen", systemImage: "folder")
                } actions: {
                    Button("Ordner auswählen …") { desk.addProject() }
                }
            } else if browser.loading {
                ProgressView("Ordner wird gelesen …").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !browser.error.isEmpty {
                ContentUnavailableView("Ordner nicht lesbar", systemImage: "folder.badge.questionmark",
                                       description: Text(browser.error))
            } else if browser.entries.isEmpty {
                ContentUnavailableView {
                    Label("Der Ordner ist leer", systemImage: "folder")
                } description: {
                    Text("Wähle in der Zwischenablage einen Eintrag und klicke auf „Im Projekt ablegen“.")
                } actions: {
                    Button("Zur Zwischenablage") { desk.showingProject = false }
                }
            } else {
                List(browser.entries) { entry in
                    HStack {
                        Label(entry.url.lastPathComponent, systemImage: entry.directory ? "folder" : "doc").lineLimit(1)
                        Spacer()
                        Button("Im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
                            .buttonStyle(.borderless)
                    }
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
