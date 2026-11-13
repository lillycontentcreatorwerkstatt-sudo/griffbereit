import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var item: NSStatusItem!
    private var window: NSWindow!
    private var desk: Desk!
    private var keys: HotKey!
    private var voiceKeys: HotKey!

    func applicationDidFinishLaunching(_ notification: Notification) {
        desk = Desk()
        keys = HotKey { [weak self] in self?.toggleWindow() }
        voiceKeys = HotKey(identifier: 2, initial: .voice) { [weak self] in
            guard let self else { return }
            if desk.dictating { desk.stopDictation(); return }
            show()
            guard window.attachedSheet == nil else { NSSound.beep(); return }
            desk.dictating = true
        }
        desk.showImageChoice = { [weak self] in
            guard let self, !desk.dictating, window.attachedSheet == nil else { return }
            show()
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(toggleWindow)
        desk.updateIcon = { [weak self] in self?.updateIcon() }
        desk.dismiss = { [weak self] in self?.window.orderOut(nil) }
        updateIcon()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 730, height: 465),
                          styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Projektfach"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: Surface(desk: desk, keys: keys, voiceKeys: voiceKeys))
        window.center()
        window.setFrameAutosaveName("Projektfach.Fenster")
        let menu = NSMenu()
        let edit = NSMenu(title: "Bearbeiten")
        for (name, action, key) in [("Kopieren", #selector(NSText.copy(_:)), "c"), ("Einsetzen", #selector(NSText.paste(_:)), "v"),
                                   ("Ausschneiden", #selector(NSText.cut(_:)), "x"), ("Alles auswählen", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(withTitle: name, action: action, keyEquivalent: key)
        }
        let menuItem = NSMenuItem()
        menuItem.submenu = edit
        menu.addItem(menuItem)
        NSApp.mainMenu = menu
        show()
    }

    private func updateIcon() {
        let label = desk.live ? "Projektfach, sammelt Kopiertes" : "Projektfach, Sammeln pausiert"
        let icon = NSImage(systemSymbolName: desk.live ? "tray.2.fill" : "tray.2", accessibilityDescription: label)
        icon?.isTemplate = true
        item.button?.image = icon
        item.button?.toolTip = label
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    @objc private func toggleWindow() {
        if window.attachedSheet != nil { show(); return }
        if window.isKeyWindow { window.orderOut(nil) } else { show() }
    }
    private func show() {
        let front = NSWorkspace.shared.frontmostApplication
        if front != NSRunningApplication.current { desk.target = front }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

@main
enum ProjektfachApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
