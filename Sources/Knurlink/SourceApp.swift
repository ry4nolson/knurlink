import AppKit

struct SourceApp: Identifiable, Hashable {
    let bundleID: String
    let name: String

    var id: String { bundleID }

    static func candidates(including ruleSources: [String]) -> [SourceApp] {
        let ownBundleID = Bundle.main.bundleIdentifier
        var names: [String: String] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let bundleID = app.bundleIdentifier, bundleID != ownBundleID else { continue }
            names[bundleID] = app.localizedName ?? bundleID
        }
        for bundleID in ruleSources where !bundleID.isEmpty && names[bundleID] == nil {
            names[bundleID] = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
                .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") }
                ?? bundleID
        }
        return names
            .map { SourceApp(bundleID: $0.key, name: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
