import AppKit
import KnurlinkCore
import os
import ServiceManagement

enum RuleTestOutcome {
    case invalid
    case noMatch
    case missingTarget(winner: Rule)
    case routed(option: BrowserOption, winner: Rule, others: [Rule])
}

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
    @Published private(set) var hasAccessibilityAccess = SafariAutomation.isTrusted

    private var accessibilityPoll: Timer?
    private var isRefreshingApps = false
    private static let catalogQueue = DispatchQueue(label: "dev.knurlink.Knurlink.catalog", qos: .utility)

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
        BrowserCatalog.options(for: apps.filter(isVisible)).filter { option in
            option.profile.map { config.isProfileVisible($0.directory, in: option.app.bundleID) } ?? true
        }
    }

    func refresh() {
        hasAccessibilityAccess = SafariAutomation.isTrusted
        apps = BrowserCatalog.installedApps()
        sourceApps = SourceApp.candidates(including: config.rules.compactMap(\.sourceBundleID))
        let probe = URL(string: "https://example.com")!
        let current = NSWorkspace.shared.urlForApplication(toOpen: probe).flatMap { Bundle(url: $0)?.bundleIdentifier }
        isDefaultBrowser = current != nil && current == Bundle.main.bundleIdentifier
        refreshLoginItem()
    }

    func refreshAppsInBackground() {
        guard !isRefreshingApps else { return }
        isRefreshingApps = true
        Self.catalogQueue.async { [weak self] in
            let apps = BrowserCatalog.installedApps()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshingApps = false
                self.apps = apps
            }
        }
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

    func requestAccessibilityAccess() {
        SafariAutomation.requestTrust()
        accessibilityPoll?.invalidate()
        let deadline = Date().addingTimeInterval(180)
        accessibilityPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { return timer.invalidate() }
                guard SafariAutomation.isTrusted || Date() > deadline else { return }
                timer.invalidate()
                self.accessibilityPoll = nil
                self.refresh()
            }
        }
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

    func isVisible(_ profile: BrowserProfile, of app: BrowserApp) -> Bool {
        config.isProfileVisible(profile.directory, in: app.bundleID)
    }

    func setVisible(_ visible: Bool, for profile: BrowserProfile, of app: BrowserApp) {
        config.setProfile(profile.directory, in: app.bundleID, visible: visible)
    }

    func visibleProfileCount(of app: BrowserApp) -> Int {
        app.profiles.filter { isVisible($0, of: app) }.count
    }

    func resolve(_ target: BrowserTarget) -> BrowserOption? {
        guard let app = apps.first(where: { $0.bundleID == target.bundleID }) else { return nil }
        guard let directory = target.profileDirectory else { return BrowserOption(app: app, profile: nil) }
        guard let profile = app.profiles.first(where: { $0.directory == directory }) else { return nil }
        return BrowserOption(app: app, profile: profile)
    }

    func route(for url: URL, source: String?) -> (option: BrowserOption, privately: Bool)? {
        guard let rule = DomainMatcher.rule(for: url, source: source, in: config.rules),
              let option = resolve(rule.target)
        else { return nil }
        return (option, rule.opensPrivately)
    }

    func testOutcome(for input: String, source: String?) -> RuleTestOutcome? {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let url = DomainMatcher.webURL(from: input) else { return .invalid }
        let ranked = DomainMatcher.rankedRules(for: url, source: source, in: config.rules)
        guard let winner = ranked.first else { return .noMatch }
        guard let option = resolve(winner.target) else { return .missingTarget(winner: winner) }
        return .routed(option: option, winner: winner, others: Array(ranked.dropFirst()))
    }

    func describe(_ rule: Rule) -> String {
        let pattern = RulePattern(rule.pattern).normalized
        let link = pattern.isEmpty ? "any link" : pattern
        guard let source = rule.sourceBundleID, !source.isEmpty else { return link }
        let name = sourceApps.first { $0.bundleID == source }?.name ?? source
        return "\(link) from \(name)"
    }

    func setRule(domain: String, target: BrowserTarget, privately: Bool) {
        let normalized = RulePattern(domain).normalized
        guard !normalized.isEmpty else { return }
        let existing = config.rules.firstIndex {
            $0.sourceBundleID == nil && RulePattern($0.pattern).normalized == normalized
        }
        if let existing {
            config.rules[existing].target = target
            config.rules[existing].opensPrivately = privately
        } else {
            config.rules.append(Rule(pattern: normalized, target: target, opensPrivately: privately))
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
