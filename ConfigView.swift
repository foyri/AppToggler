import SwiftUI
import Foundation
import AppKit
import KeyboardShortcuts

struct ConfigView: View {
    @EnvironmentObject var config: ConfigManager
    @State private var scannedApps: [ScannedApp] = []
    @State private var isLoadingApps = false
    private static var cachedApps: [ScannedApp] = []
    
    var body: some View {
        VStack {
            List {
                ForEach(config.mappings) { mapping in
                    HStack(spacing: 12) {
                        Picker("Application", selection: appSelectionBinding(for: mapping)) {
                            ForEach(appOptions(for: mapping), id: \.bundleIdentifier) { app in
                                Text(app.displayName).tag(app.bundleIdentifier)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        KeyboardShortcuts.Recorder(for: mapping.keyboardShortcutName)
                            .frame(width: 170, alignment: .trailing)
                        
                        Button("−", role: .destructive) {
                            config.removeMapping(id: mapping.id)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            HStack {
                Button("Add Hotkey...") {
                    addHotkeyRow()
                }
                .disabled(isLoadingApps)
                
                Button("Scan Apps") { reloadApps() }
                    .disabled(isLoadingApps)
                
                Button("Quit") { NSApp.terminate(nil) }
            }
            .padding()

            Text("Shortcuts must include a non-modifier key. Some combinations are reserved by macOS (for example, Control+Command+D and Control+Command+Space).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            
            if isLoadingApps {
                Text("Scanning applications...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 520, height: 380)
        .onAppear {
            if !Self.cachedApps.isEmpty {
                scannedApps = Self.cachedApps
            }
        }
    }
    
    private func reloadApps(addAfterScan: Bool = false) {
        guard !isLoadingApps else { return }
        isLoadingApps = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = scanInstalledApps()
            DispatchQueue.main.async {
                Self.cachedApps = apps
                scannedApps = apps
                isLoadingApps = false
                if addAfterScan {
                    addHotkeyRow()
                }
            }
        }
    }
    
    private func nextAvailableApp() -> ScannedApp? {
        let used = Set(config.mappings.map(\.bundleIdentifier))
        return scannedApps.first(where: { !used.contains($0.bundleIdentifier) })
    }
    
    private func addHotkeyRow() {
        if scannedApps.isEmpty {
            reloadApps(addAfterScan: true)
            return
        }
        
        guard let app = nextAvailableApp() else { return }
        var newMapping = AppMapping(
            displayName: app.displayName,
            bundleIdentifier: app.bundleIdentifier,
            appPath: app.path,
            shortcutName: ""
        )
        newMapping.shortcutName = AppMapping.shortcutStorageName(for: newMapping.id)
        config.addMapping(newMapping)
    }
    
    private func appOptions(for mapping: AppMapping) -> [ScannedApp] {
        let usedElsewhere = Set(
            config.mappings
                .filter { $0.id != mapping.id }
                .map(\.bundleIdentifier)
        )
        
        var options = scannedApps.filter { app in
            app.bundleIdentifier == mapping.bundleIdentifier || !usedElsewhere.contains(app.bundleIdentifier)
        }
        
        if !options.contains(where: { $0.bundleIdentifier == mapping.bundleIdentifier }) {
            options.insert(
                ScannedApp(
                    displayName: mapping.displayName,
                    bundleIdentifier: mapping.bundleIdentifier,
                    path: mapping.appPath ?? ""
                ),
                at: 0
            )
        }
        
        return options.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
    
    private func appSelectionBinding(for mapping: AppMapping) -> Binding<String> {
        Binding(
            get: { mapping.bundleIdentifier },
            set: { newBundleID in
                guard let app = scannedApps.first(where: { $0.bundleIdentifier == newBundleID }) else { return }
                config.updateMappingApp(id: mapping.id, app: app)
            }
        )
    }
}
