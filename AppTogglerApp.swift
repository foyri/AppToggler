import SwiftUI
import AppKit
import KeyboardShortcuts

@main
struct AppTogglerApp: App {
    @StateObject private var config = ConfigManager()
    
    var body: some Scene {
        MenuBarExtra("App Toggler", systemImage: "keyboard") {
            ForEach(config.mappings) { mapping in
                let shortcut = KeyboardShortcuts.getShortcut(for: mapping.keyboardShortcutName)
                Button("\(mapping.displayName) \(shortcut?.description ?? "—")") {
                    config.toggleApp(for: mapping)
                }
            }
            
            Divider()
            
            Button("Configure…") {
                NSApp.activate(ignoringOtherApps: true)
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
                    styleMask: [.titled, .closable],
                    backing: .buffered,
                    defer: false
                )
                window.title = "App Toggler — Hotkeys"
                window.contentView = NSHostingView(
                    rootView: ConfigView()
                        .environmentObject(config)
                )
                window.center()
                window.makeKeyAndOrderFront(nil)
            }
            
            Button("Quit") { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.automatic)
    }
}
