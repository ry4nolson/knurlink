import AppKit
import KnurlinkCore
import os
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    private static let logger = Logger(subsystem: "dev.knurlink.Knurlink", category: "config")

    @Published var config: Config {
        didSet {
            guard config != oldValue else { return }
            persist()
        }
    }
    @Published private(set) var apps: [BrowserApp] = []
    @Published private(set) var sourceApps: [SourceApp] = []
    @Published private(set) var isDefaultBrowser = false
    @Published private(set) var launchesAtLogin = false
    @Published private(set) var loginItemNeedsApproval = false
    @Published private(set) var lastError: String?

    private let store: ConfigStore

    init(store: ConfigStore = .standard) {
        self.store = store
        do {
            config = try store.load()
        } catch {
            config = Config()
            Self.logger.error("Config unreadable: \(error.localizedDescription, privacy: .public)")
            do {
                let moved = try store.quarantineInvalidFile()
                lastError = "The saved rules could not be read and were moved to \(moved.lastPathComponent)."
            } catch {
                lastError = "The saved rules could not be read: \(error.localizedDescription)"
            }
        }
        refresh()
    }

    var allOptions: [BrowserOption] {
        BrowserCatalog.options(for: apps)
    }

    var visibleOptions: [BrowserOption] {
        BrowserCatalog.options(for: apps.filter(isVisible))
    }

    func refresh() {
        apps = BrowserCatalog.installedApps()
        sourceApps = SourceApp.candidates(including: config.rules.compactMap(\.sourceBundleID))
        let probe = URL(string: "https://example.com")!
        let current = NSWorkspace.shared.urlForApplication(toOpen: probe).flatMap { Bundle(url: $0)?.bundleIdentifier }
        isDefaultBrowser = current != nil && current == Bundle.main.bundleIdentifier
        refreshLoginItem()
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            Self.logger.error("Login item change failed: \(error.localizedDescription, privacy: .public)")
            lastError = "Could not change launch at login: \(error.localizedDescription)"
        }
        refreshLoginItem()
    }

    private func refreshLoginItem() {
        let status = SMAppService.mainApp.status
        launchesAtLogin = status == .enabled || status == .requiresApproval
        loginItemNeedsApproval = status == .requiresApproval
    }

    func isVisible(_ app: BrowserApp) -> Bool {
        config.appVisibility[app.bundleID] ?? app.isKnownBrowser
    }

    func setVisible(_ visible: Bool, for app: BrowserApp) {
        config.appVisibility[app.bundleID] = visible
    }

    func resolve(_ target: BrowserTarget) -> BrowserOption? {
        guard let app = apps.first(where: { $0.bundleID == target.bundleID }) else { return nil }
        guard let directory = target.profileDirectory else { return BrowserOption(app: app, profile: nil) }
        guard let profile = app.profiles.first(where: { $0.directory == directory }) else { return nil }
        return BrowserOption(app: app, profile: profile)
    }

    func routedOption(for url: URL, source: String?) -> BrowserOption? {
        DomainMatcher.rule(for: url, source: source, in: config.rules).flatMap { resolve($0.target) }
    }

    func setRule(domain: String, target: BrowserTarget) {
        let normalized = RulePattern(domain).normalized
        guard !normalized.isEmpty else { return }
        let existing = config.rules.firstIndex {
            $0.sourceBundleID == nil && RulePattern($0.pattern).normalized == normalized
        }
        if let existing {
            config.rules[existing].target = target
        } else {
            config.rules.append(Rule(pattern: normalized, target: target))
        }
    }

    func addBlankRule() {
        guard let target = (visibleOptions.first ?? allOptions.first)?.target else { return }
        config.rules.append(Rule(target: target))
    }

    func removeRule(id: UUID) {
        config.rules.removeAll { $0.id == id }
    }

    func makeDefaultBrowser() {
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http") { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    Self.logger.error("Default browser change failed: \(error.localizedDescription, privacy: .public)")
                }
                self?.refresh()
            }
        }
    }

    private func persist() {
        do {
            try store.save(config)
            lastError = nil
        } catch {
            Self.logger.error("Config save failed: \(error.localizedDescription, privacy: .public)")
            lastError = "Could not save rules: \(error.localizedDescription)"
        }
    }
}
