import AppKit
import KnurlinkCore
import os

enum Launcher {
    private static let logger = Logger(subsystem: "dev.knurlink.Knurlink", category: "launcher")

    static func open(_ url: URL, with option: BrowserOption, privately: Bool = false) {
        let configuration = NSWorkspace.OpenConfiguration()
        let completion: (NSRunningApplication?, Error?) -> Void = { _, error in
            guard let error else { return }
            logger.error("Could not open \(option.title, privacy: .public): \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async { presentFailure(error, option: option) }
        }
        if let profile = option.profile, SafariProfileMenu.supportsProfiles(bundleID: option.app.bundleID) {
            openInSafari(url, profile: profile, option: option)
            return
        }
        let privateArgument = privately ? PrivateWindow.argument(forBundleID: option.app.bundleID) : nil
        if option.profile != nil || privateArgument != nil {
            configuration.arguments = [
                option.profile.map { "--profile-directory=\($0.directory)" },
                privateArgument,
                url.absoluteString,
            ].compactMap { $0 }
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: option.app.url, configuration: configuration, completionHandler: completion)
        } else {
            NSWorkspace.shared.open([url], withApplicationAt: option.app.url, configuration: configuration, completionHandler: completion)
        }
    }

    private static func openInSafari(_ url: URL, profile: BrowserProfile, option: BrowserOption) {
        guard SafariAutomation.isTrusted else {
            SafariAutomation.requestTrust()
            open(url, with: BrowserOption(app: option.app, profile: nil))
            return
        }
        SafariAutomation.open(url, inProfile: profile.name, app: option.app) { error in
            guard error != nil else { return }
            DispatchQueue.main.async { open(url, with: BrowserOption(app: option.app, profile: nil)) }
        }
    }

    private static func presentFailure(_ error: Error, option: BrowserOption) {
        let alert = NSAlert()
        alert.messageText = "Could not open the link in \(option.title)"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
