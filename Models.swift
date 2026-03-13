import Foundation
import KeyboardShortcuts

struct AppMapping: Identifiable, Codable {
    var id = UUID()
    var displayName: String
    var bundleIdentifier: String
    var appPath: String?          // for reliable launch
    var shortcutName: String      // used by KeyboardShortcuts.Name(rawValue:)
    
    var keyboardShortcutName: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name(shortcutName)
    }
}

extension AppMapping {
    static func shortcutStorageName(for id: UUID) -> String {
        let token = id.uuidString
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        return "toggle.\(token)"
    }
}
