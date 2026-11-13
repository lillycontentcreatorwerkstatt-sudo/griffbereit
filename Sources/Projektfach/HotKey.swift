import AppKit
import Carbon.HIToolbox

struct KeyChoice: Codable {
    var code: UInt32
    var modifiers: UInt32
    var label: String
    static let initial = KeyChoice(code: UInt32(kVK_ANSI_J), modifiers: UInt32(cmdKey | shiftKey), label: "⇧⌘J")
}

final class HotKey: ObservableObject {
    @Published var choice = KeyChoice.initial
    @Published var problem = ""
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    let perform: () -> Void

    init(perform: @escaping () -> Void) {
        self.perform = perform
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                          nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == 0x50464B59 else { return OSStatus(eventNotHandledErr) }
            Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue().perform()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { problem = "Die globale Tastatursteuerung ist nicht verfügbar."; return }
        let stored = UserDefaults.standard.data(forKey: "keyChoice").flatMap { try? JSONDecoder().decode(KeyChoice.self, from: $0) }
        register(stored ?? .initial)
    }

    func register(_ next: KeyChoice) {
        if ref != nil, next.code == choice.code, next.modifiers == choice.modifiers { problem = ""; return }
        var replacement: EventHotKeyRef?
        let status = RegisterEventHotKey(next.code, next.modifiers, EventHotKeyID(signature: 0x50464B59, id: 1),
                                         GetApplicationEventTarget(), 0, &replacement)
        guard status == noErr else { problem = "Dieses Kürzel ist belegt. Wähle ein anderes."; return }
        if let ref { UnregisterEventHotKey(ref) }
        ref = replacement
        choice = next
        problem = ""
        UserDefaults.standard.set(try? JSONEncoder().encode(next), forKey: "keyChoice")
    }
    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}

final class RecorderButton: NSButton {
    var record: (KeyChoice) -> Void = { _ in }
    var configured = ""
    var listening = false
    override var acceptsFirstResponder: Bool { true }
    override func resignFirstResponder() -> Bool { listening = false; title = configured; return super.resignFirstResponder() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard listening else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }
    override func keyDown(with event: NSEvent) {
        guard listening else { super.keyDown(with: event); return }
        defer { listening = false; title = configured }
        guard event.keyCode != kVK_Escape else { return }
        let mods = event.modifierFlags
        guard mods.contains(.command) || mods.contains(.control) || mods.contains(.option),
              let letter = event.charactersIgnoringModifiers?.uppercased(), letter.count == 1,
              letter.rangeOfCharacter(from: .alphanumerics) != nil else { NSSound.beep(); return }
        var flags: UInt32 = 0
        var label = ""
        for (mask, bit, glyph) in [(NSEvent.ModifierFlags.control, controlKey, "⌃"), (.option, optionKey, "⌥"),
                                   (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘")] where mods.contains(mask) {
            flags |= UInt32(bit)
            label += glyph
        }
        record(KeyChoice(code: UInt32(event.keyCode), modifiers: flags, label: label + letter))
    }
    @objc func begin() { window?.makeFirstResponder(self); listening = true; title = "Kürzel drücken …" }
}
