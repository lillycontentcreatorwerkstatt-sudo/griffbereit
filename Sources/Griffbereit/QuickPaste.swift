import AppKit
import SwiftUI
import FachCore

private final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class ShadeView: NSView {
    var cancel: () -> Void = {}
    override func mouseDown(with event: NSEvent) { cancel() }
}

@MainActor
final class QuickPaste: NSObject, NSWindowDelegate {
    private var shades: [NSPanel] = []
    private var panel: NSPanel?
    var isVisible: Bool { panel != nil }

    func show(desk: Desk, target: NSRunningApplication) {
        close()
        let screens = NSScreen.screens
        guard let screen = screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        let area = screen.visibleFrame
        let size = NSSize(width: min(area.width - 20, max(360, min(640, area.width * 0.5))),
                          height: min(area.height - 20, max(220, area.height * 0.5)))
        for display in screens {
            let shade = NSPanel(contentRect: display.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            shade.backgroundColor = .black.withAlphaComponent(0.25)
            shade.isOpaque = false
            shade.hasShadow = false
            shade.level = .floating
            shade.hidesOnDeactivate = false
            shade.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            let view = ShadeView()
            view.cancel = { [weak self] in self?.close() }
            shade.contentView = view
            shade.orderFrontRegardless()
            shades.append(shade)
        }

        let picker = PickerPanel(contentRect: NSRect(origin: .zero, size: size),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        picker.title = "Schnell einfügen"
        picker.isOpaque = false
        picker.backgroundColor = .clear
        picker.hasShadow = true
        picker.hidesOnDeactivate = false
        picker.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        picker.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        picker.delegate = self
        panel = picker
        picker.contentView = NSHostingView(rootView: PasteList(desk: desk, target: target, close: { [weak self] in self?.close() }))
        picker.setFrameOrigin(NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2))
        picker.orderFrontRegardless()
        picker.makeKey()
    }

    func windowDidResignKey(_ notification: Notification) {
        if (notification.object as? NSPanel) === panel { close() }
    }

    func close() {
        let previous = panel
        panel = nil
        previous?.delegate = nil
        previous?.orderOut(nil)
        for shade in shades { shade.orderOut(nil) }
        shades.removeAll()
    }
}

private struct PasteList: View {
    @ObservedObject var desk: Desk
    let target: NSRunningApplication
    let close: () -> Void
    @State private var query = ""
    @State private var selection: String?
    @State private var notice = ""
    @FocusState private var searching: Bool
    private var rows: [Record] { desk.matching(query) }

    private func move(_ step: Int) {
        let list = rows
        guard !list.isEmpty else { return }
        let position = list.firstIndex { $0.id == selection } ?? 0
        selection = list[max(0, min(list.count - 1, position + step))].id
    }

    private func paste(_ record: Record) {
        do {
            try desk.copyToPasteboard(record)
            guard !target.isTerminated else { notice = "Kopiert. Die Ziel-App wurde beendet."; return }
            guard AXIsProcessTrusted() else {
                notice = "Kopiert. Für diesen Eintrag: Esc drücken und mit ⌘V einsetzen."
                return
            }
            close()
            desk.pasteInto(target)
        } catch { notice = error.localizedDescription }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "clipboard")
                Text("Einfügen in " + (target.localizedName ?? "App")).font(.headline)
                Spacer()
                Button(action: close) { Image(systemName: "xmark") }.buttonStyle(.plain)
                    .accessibilityLabel("Schließen")
            }.padding(14)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Zwischenablage durchsuchen", text: $query)
                    .textFieldStyle(.plain).focused($searching)
                    .onKeyPress(.upArrow) { move(-1); return .handled }
                    .onKeyPress(.downArrow) { move(1); return .handled }
                    .onSubmit { if let row = rows.first(where: { $0.id == selection }) ?? rows.first { paste(row) } }
            }.padding(.horizontal, 14).padding(.bottom, 12)
            Divider()
            if rows.isEmpty {
                ContentUnavailableView(query.isEmpty ? "Der Verlauf ist leer" : "Keine Treffer", systemImage: "clipboard")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(rows) { row in
                                Button { paste(row) } label: {
                                    HStack(spacing: 10) {
                                        PasteSymbol(desk: desk, row: row)
                                        Text(row.title).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                        Text(row.date.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                    }.padding(8).contentShape(Rectangle())
                                }.buttonStyle(.plain).frame(maxWidth: .infinity)
                                    .background(selection == row.id ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 6))
                                    .id(row.id)
                            }
                        }.padding(6)
                    }.onChange(of: selection) { _, id in if let id { proxy.scrollTo(id) } }
                }
            }
            if !notice.isEmpty {
                Divider()
                Text(notice).font(.callout).padding(10)
            }
            if !AXIsProcessTrusted() {
                Button("Bedienungshilfen für direktes Einfügen öffnen …") {
                    close()
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }.buttonStyle(.link).padding(10)
            }
        }.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear { selection = rows.first?.id; searching = true }
        .onChange(of: query) { _, _ in selection = rows.first?.id }
        .onExitCommand(perform: close)
    }
}

private struct PasteSymbol: View {
    let desk: Desk
    let row: Record
    @State private var preview: NSImage?
    var body: some View {
        Group {
            if let preview {
                Image(nsImage: preview).resizable().scaledToFit()
            } else {
                Image(systemName: row.kind == .files ? "doc.on.doc" : row.kind == .image ? "photo" : "text.alignleft")
                    .foregroundStyle(.secondary)
            }
        }.frame(width: 32, height: 32)
        .onAppear { if row.kind == .image { preview = desk.preview(row) } }
        .onDisappear { preview = nil }
    }
}
