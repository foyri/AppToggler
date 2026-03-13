import Foundation

struct ScannedApp: Identifiable, Hashable {
    let id = UUID()
    let displayName: String
    let bundleIdentifier: String
    let path: String
}

func scanInstalledApps() -> [ScannedApp] {
    var apps: [ScannedApp] = []
    let searchPaths = [
        "/Applications",
        "/System/Applications",
        "/System/Library/CoreServices",
        (NSHomeDirectory() as NSString).appendingPathComponent("Applications")
    ]
    let fm = FileManager.default
    
    for base in searchPaths {
        let baseURL = URL(fileURLWithPath: base)
        guard let enumerator = fm.enumerator(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isApplicationKey, .nameKey],
            options: [.skipsPackageDescendants]
        ) else { continue }
        
        for case let url as URL in enumerator {
            guard url.pathExtension == "app" else { continue }
            
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier,
                  !bundleID.isEmpty else { continue }
            
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                       (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
                       url.deletingPathExtension().lastPathComponent
            
            apps.append(ScannedApp(displayName: name, bundleIdentifier: bundleID, path: url.path))
        }
    }
    
    // Deduplicate by bundleID
    return Array(Dictionary(grouping: apps, by: { $0.bundleIdentifier }).compactMapValues { $0.first }.values)
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
}
