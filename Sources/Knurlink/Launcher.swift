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
        let isSafari = SafariProfileMenu.supportsProfiles(bundleID: option.app.bundleID)
        if privately, isSafari {
            openPrivatelyInSafari(url, option: option)
            return
        }
        if let profile = option.profile, isSafari {
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

    private static func openPrivatelyInSafari(_ url: URL, option: BrowserOption) {
        guard SafariAutomation.isTrusted else {
            offerNormalWindow(url, option: option, error: SafariAutomationError.notTrusted)
            return
        }
        SafariAutomation.openPrivately(url, app: option.app) { error in
            guard let error else { return }
            DispatchQueue.main.async { offerNormalWindow(url, option: option, error: error) }
        }
    }

    private static func offerNormalWindow(_ url: URL, option: BrowserOption, error: Error) {
        let needsTrust = error as? SafariAutomationError == .notTrusted
        let alert = NSAlert()
        alert.messageText = "Could not open a private window in \(option.app.name)"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Normally")
        if needsTrust { alert.addButton(withTitle: "Allow Access…") }
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            open(url, with: option)
        } else if needsTrust, response == .alertSecondButtonReturn {
            SafariAutomation.requestTrust()
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
