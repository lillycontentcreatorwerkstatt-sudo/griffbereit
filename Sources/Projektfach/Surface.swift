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
    @State private var settings = false
    @State private var confirmClear = false
    @FocusState private var searchFocus: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "tray.2.fill").font(.title2).foregroundStyle(Color.accentColor)
                Text("Projektfach").font(.title2.weight(.semibold))
                Spacer()
                Button { desk.toggle() } label: {
                    Label(desk.live ? "Aufnahme pausieren" : "Aufnahme starten", systemImage: desk.live ? "pause.circle" : "record.circle")
                }
                Button { settings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Einstellungen").help("Einstellungen")
            }.padding(16)
            Divider()
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
                        Text(desk.query.isEmpty ? (desk.live ? "Kopiere einen Text, ein Bild oder eine Datei." : "Starte die Aufnahme für deinen ersten Fund.") : "Keine passenden Einträge.")
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
            Divider()
            HStack {
                Menu {
                    ForEach(desk.projects) { project in
                        Button(project.path) { desk.destination = project.path }
                    }
                    Divider()
                    Button("Projektordner hinzufügen …") { desk.addProject() }
                } label: { Label(desk.destination.isEmpty ? "Projekt wählen" : URL(fileURLWithPath: desk.destination).lastPathComponent,
                                 systemImage: "folder") }
                .fixedSize()
                Spacer()
                Button("Kopieren") { desk.use(paste: false) }.disabled(desk.current == nil)
                Button(desk.exporting ? "Legt ab …" : "Im Projekt ablegen") { desk.export() }
                    .keyboardShortcut(.return, modifiers: .command).buttonStyle(.borderedProminent)
                    .disabled(desk.current == nil || desk.exporting || desk.reading.contains(desk.selection ?? ""))
            }.padding(12)
            if !desk.message.isEmpty || !keys.problem.isEmpty {
                HStack {
                    Text(desk.message.isEmpty ? keys.problem : desk.message).font(.callout)
                    Spacer()
                    Button("OK") { desk.message = ""; keys.problem = "" }.controlSize(.small)
                }.padding(.horizontal, 14).padding(.bottom, 10)
            }
        }
        .frame(minWidth: 650, minHeight: 400)
        .onAppear { searchFocus = true }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in if !settings { searchFocus = true } }
        .onExitCommand { desk.dismiss() }
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
