import AppKit
import os

enum Launcher {
    private static let logger = Logger(subsystem: "dev.knurlink.Knurlink", category: "launcher")

    static func open(_ url: URL, with option: BrowserOption) {
        let configuration = NSWorkspace.OpenConfiguration()
        let completion: (NSRunningApplication?, Error?) -> Void = { _, error in
            guard let error else { return }
            logger.error("Could not open \(option.title, privacy: .public): \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async { presentFailure(error, option: option) }
        }
        if let profile = option.profile {
            configuration.arguments = ["--profile-directory=\(profile.directory)", url.absoluteString]
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: option.app.url, configuration: configuration, completionHandler: completion)
        } else {
            NSWorkspace.shared.open([url], withApplicationAt: option.app.url, configuration: configuration, completionHandler: completion)
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
