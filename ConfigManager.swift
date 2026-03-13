import Foundation
import AppKit
import KeyboardShortcuts

@MainActor
final class ConfigManager: ObservableObject {
    @Published var mappings: [AppMapping] = [] {
        didSet { saveAndReapply() }
    }
    
    private let configURL: URL
    
    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppToggler")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        configURL = support.appendingPathComponent("hotkeys.json")
        
        load()
        setupHotkeys()
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: configURL),
              let decoded = try? JSONDecoder().decode([AppMapping].self, from: data) else { return }
        mappings = normalizeShortcutStorageNames(in: decoded)
    }
    
    private func save() {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        try? data.write(to: configURL)
    }
    
    private func setupHotkeys() {
        KeyboardShortcuts.removeAllHandlers()
        
        for mapping in mappings {
            let name = mapping.keyboardShortcutName
            KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
                self?.toggleApp(for: mapping)
            }
        }
    }
    
    private func saveAndReapply() {
        save()
        setupHotkeys()
    }
    
    func addMapping(_ mapping: AppMapping) {
        guard !mappings.contains(where: { $0.bundleIdentifier == mapping.bundleIdentifier }) else { return }
        
        var newMapping = mapping
        if newMapping.shortcutName.isEmpty || mappings.contains(where: { $0.shortcutName == newMapping.shortcutName }) {
            newMapping.shortcutName = uniqueShortcutStorageName(for: newMapping.id)
        }
        
        mappings.append(newMapping)
    }

    func updateMappingApp(id: UUID, app: ScannedApp) {
        guard let index = mappings.firstIndex(where: { $0.id == id }) else { return }
        let existing = mappings[index]
        
        // Prevent duplicate app targets across rows.
        if app.bundleIdentifier != existing.bundleIdentifier &&
            mappings.contains(where: { $0.bundleIdentifier == app.bundleIdentifier && $0.id != id }) {
            return
        }
        
        mappings[index].displayName = app.displayName
        mappings[index].bundleIdentifier = app.bundleIdentifier
        mappings[index].appPath = app.path
    }
    
    func removeMapping(id: UUID) {
        mappings.removeAll { $0.id == id }
    }

    private func uniqueShortcutStorageName(for id: UUID) -> String {
        let base = AppMapping.shortcutStorageName(for: id)
        if !mappings.contains(where: { $0.shortcutName == base }) {
            return base
        }
        
        var counter = 1
        while mappings.contains(where: { $0.shortcutName == "\(base).\(counter)" }) {
            counter += 1
        }
        return "\(base).\(counter)"
    }
    
    private func normalizeShortcutStorageNames(in input: [AppMapping]) -> [AppMapping] {
        var used = Set<String>()
        var normalized: [AppMapping] = []
        
        for var mapping in input {
            let candidate = mapping.shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.isEmpty || used.contains(candidate) {
                var unique = AppMapping.shortcutStorageName(for: mapping.id)
                var counter = 1
                while used.contains(unique) {
                    unique = "\(AppMapping.shortcutStorageName(for: mapping.id)).\(counter)"
                    counter += 1
                }
                mapping.shortcutName = unique
            }
            
            used.insert(mapping.shortcutName)
            normalized.append(mapping)
        }
        
        return normalized
    }
    
    // MARK: - Toggle Logic (exactly as you wanted)
    func toggleApp(for mapping: AppMapping) {
        let workspace = NSWorkspace.shared
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: mapping.bundleIdentifier)
        
        if let app = runningApps.first {
            if app.isActive && !app.isHidden {
                _ = app.hide()
            } else {
                showApp(app, for: mapping, workspace: workspace)
            }
        } else {
            // Not running → launch
            openOrActivateApp(for: mapping, workspace: workspace)
        }
    }
    
    private func showApp(_ app: NSRunningApplication, for mapping: AppMapping, workspace: NSWorkspace) {
        _ = app.unhide()
        let didActivate = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        
        // Some apps stay hidden/minimized after activate; fallback through NSWorkspace.
        if app.isHidden || !didActivate {
            openOrActivateApp(for: mapping, workspace: workspace)
        }
    }
    
    private func openOrActivateApp(for mapping: AppMapping, workspace: NSWorkspace) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.createsNewApplicationInstance = false
        
        if let path = mapping.appPath {
            let url = URL(fileURLWithPath: path)
            workspace.openApplication(at: url, configuration: config)
        } else if let appURL = workspace.urlForApplication(withBundleIdentifier: mapping.bundleIdentifier) {
            workspace.openApplication(at: appURL, configuration: config)
        }
    }
}
