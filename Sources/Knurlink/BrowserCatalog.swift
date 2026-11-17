import AppKit
import KnurlinkCore
import os

struct BrowserProfile: Hashable {
    let directory: String
    let name: String
    let pictureURL: URL?
}

struct BrowserApp: Identifiable {
    let bundleID: String
    let name: String
    let url: URL
    let icon: NSImage
    let profiles: [BrowserProfile]
    let isKnownBrowser: Bool

    var id: String { bundleID }
}

struct BrowserOption: Identifiable {
    let app: BrowserApp
    let profile: BrowserProfile?

    var target: BrowserTarget {
        BrowserTarget(bundleID: app.bundleID, profileDirectory: profile?.directory)
    }

    var id: BrowserTarget { target }

    var title: String {
        guard let profile else { return app.name }
        return "\(app.name) (\(profile.name))"
    }

    var supportsPrivateWindow: Bool {
        PrivateWindow.argument(forBundleID: app.bundleID) != nil
    }
}

enum BrowserCatalog {
    private static let logger = Logger(subsystem: "dev.knurlink.Knurlink", category: "catalog")
    private static let probeURL = URL(string: "https://example.com")!

    private static let chromiumDataDirectories: [String: String] = [
        "com.google.Chrome": "Google/Chrome",
        "com.google.Chrome.beta": "Google/Chrome Beta",
        "com.google.Chrome.dev": "Google/Chrome Dev",
        "com.google.Chrome.canary": "Google/Chrome Canary",
        "org.chromium.Chromium": "Chromium",
        "com.brave.Browser": "BraveSoftware/Brave-Browser",
        "com.brave.Browser.beta": "BraveSoftware/Brave-Browser-Beta",
        "com.brave.Browser.nightly": "BraveSoftware/Brave-Browser-Nightly",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.vivaldi.Vivaldi": "Vivaldi",
    ]

    private static let otherKnownBrowsers: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
        "company.thebrowser.Browser",
        "company.thebrowser.dia",
        "com.operasoftware.Opera",
        "com.kagi.kagimacOS",
        "com.duckduckgo.macos.browser",
        "app.zen-browser.zen",
    ]

    static func installedApps() -> [BrowserApp] {
        let ownBundleID = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        return NSWorkspace.shared.urlsForApplications(toOpen: probeURL)
            .compactMap { url -> BrowserApp? in
                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      bundleID != ownBundleID,
                      seen.insert(bundleID).inserted
                else { return nil }
                return BrowserApp(
                    bundleID: bundleID,
                    name: displayName(for: url),
                    url: url,
                    icon: NSWorkspace.shared.icon(forFile: url.path),
                    profiles: chromiumProfiles(for: bundleID),
                    isKnownBrowser: chromiumDataDirectories[bundleID] != nil || otherKnownBrowsers.contains(bundleID)
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func options(for apps: [BrowserApp]) -> [BrowserOption] {
        apps.flatMap { app in
            app.profiles.count > 1
                ? app.profiles.map { BrowserOption(app: app, profile: $0) }
                : [BrowserOption(app: app, profile: nil)]
        }
    }

    private static func displayName(for url: URL) -> String {
        FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private static func chromiumProfiles(for bundleID: String) -> [BrowserProfile] {
        guard let dataDirectory = chromiumDataDirectories[bundleID] else { return [] }
        let root = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(dataDirectory)
        let localState = root.appendingPathComponent("Local State")
        guard FileManager.default.fileExists(atPath: localState.path) else { return [] }
        do {
            let state = try JSONSerialization.jsonObject(with: Data(contentsOf: localState)) as? [String: Any]
            let profile = state?["profile"] as? [String: Any]
            let infoCache = profile?["info_cache"] as? [String: [String: Any]] ?? [:]
            return infoCache
                .map { directory, info in
                    let picture = root
                        .appendingPathComponent(directory)
                        .appendingPathComponent("Google Profile Picture.png")
                    return BrowserProfile(
                        directory: directory,
                        name: info["name"] as? String ?? directory,
                        pictureURL: FileManager.default.fileExists(atPath: picture.path) ? picture : nil
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            logger.error("Could not read profiles for \(bundleID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
