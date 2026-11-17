import KnurlinkCore
import ServiceManagement
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case rules
    case tester
    case browsers
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .rules: "Rules"
        case .tester: "Test a Link"
        case .browsers: "Browsers"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .rules: "arrow.triangle.branch"
        case .tester: "link"
        case .browsers: "globe"
        case .about: "info"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .rules: .blue
        case .tester: .green
        case .browsers: .indigo
        case .about: .gray
        }
    }
}

@MainActor
final class SettingsRouter: ObservableObject {
    @Published var section: SettingsSection = .general
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updater: UpdateChecker
    @ObservedObject var router: SettingsRouter

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 960, idealWidth: 1000, minHeight: 540, idealHeight: 640)
        .onAppear { model.refresh() }
    }

    private var selection: Binding<SettingsSection?> {
        Binding(
            get: { router.section },
            set: { if let section = $0 { router.section = section } }
        )
    }

    private var sidebar: some View {
        List(selection: selection) {
            Section {
                ForEach([SettingsSection.general, .rules, .tester, .browsers]) { section in
                    sidebarRow(for: section)
                }
            }
            Section {
                sidebarRow(for: .about)
            }
        }
        .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        .toolbar(removing: .sidebarToggle)
    }

    private func sidebarRow(for section: SettingsSection) -> some View {
        Label {
            Text(section.title)
        } icon: {
            if section == .about {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                SidebarIcon(symbol: section.symbol, tint: section.tint)
            }
        }
        .badge(badgeCount(for: section))
        .tag(section)
    }

    private func badgeCount(for section: SettingsSection) -> Int {
        switch section {
        case .general: model.isDefaultBrowser ? 0 : 1
        case .about: updater.availableRelease == nil ? 0 : 1
        default: 0
        }
    }

    private var detail: some View {
        Group {
            switch router.section {
            case .general: GeneralSettingsView(model: model)
            case .rules: RulesSettingsView(model: model)
            case .tester: RuleTesterView(model: model)
            case .browsers: BrowsersSettingsView(model: model)
            case .about: AboutView(model: model, updater: updater)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(router.section.title)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = model.lastError {
                ErrorBanner(message: error)
            }
        }
    }
}

struct SidebarIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(tint.gradient))
    }
}

struct SectionFooter: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Default Browser") {
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.isDefaultBrowser ? "knURLink is your default browser" : "knURLink isn't your default browser")
                            .font(.headline)
                        Text(model.isDefaultBrowser
                            ? "Links you click anywhere come here first, then go where your rules send them."
                            : "It only sees links when it's the default browser.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if model.isDefaultBrowser {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    } else {
                        Button("Make Default") { model.makeDefaultBrowser() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Startup") {
                Toggle(isOn: Binding(
                    get: { model.launchesAtLogin },
                    set: { model.setLaunchesAtLogin($0) }
                )) {
                    Text("Launch at login")
                    Text("Starts quietly in the menu bar.")
                }
                if model.loginItemNeedsApproval {
                    HStack {
                        Label("Needs approval in Login Items", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
            }
        }
    }
}

struct RulesSettingsView: View {
    @ObservedObject var model: AppModel
    @FocusState private var focusedRule: UUID?

    var body: some View {
        Form {
            if model.config.rules.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Rules", systemImage: "arrow.triangle.branch")
                    } description: {
                        Text("Links that match a rule skip the picker and open straight in the browser you choose.")
                    } actions: {
                        Button("Add Rule", action: addRule)
                    }
                    .padding(.vertical, 24)
                }
            } else {
                Section {
                    ForEach($model.config.rules) { $rule in
                        RuleRow(model: model, rule: $rule, focus: $focusedRule)
                    }
                } header: {
                    RuleColumnHeader()
                } footer: {
                    HStack(alignment: .top, spacing: 16) {
                        SectionFooter("Use a domain (tiktok.com) or a domain with a path (github.com/my-org). Subdomains and deeper paths are covered. Leave the link blank to match everything from one app. Turn on Private to open matches in an incognito or private window. The most specific link wins, and a rule with no link is the fallback. Apps show up in the list while they're running.")
                        Button("Add Rule", action: addRule)
                    }
                }
            }
        }
        .onChange(of: focusedRule) { previous, _ in
            guard let previous, let index = model.config.rules.firstIndex(where: { $0.id == previous }) else { return }
            model.config.rules[index].pattern = RulePattern(model.config.rules[index].pattern).normalized
        }
    }

    private func addRule() {
        model.addBlankRule()
        focusedRule = model.config.rules.last?.id
    }
}

private enum RuleColumns {
    static let icon: CGFloat = 20
    static let source: CGFloat = 120
    static let arrow: CGFloat = 12
    static let target: CGFloat = 230
    static let privacy: CGFloat = 56
    static let delete: CGFloat = 16
    static let spacing: CGFloat = 10
    static let pickerInset: CGFloat = 11
}

private struct RuleColumnHeader: View {
    var body: some View {
        HStack(spacing: RuleColumns.spacing) {
            Color.clear.frame(width: RuleColumns.icon, height: 1)
            Text("Link").frame(maxWidth: .infinity, alignment: .leading)
            Text("From")
                .padding(.leading, RuleColumns.pickerInset)
                .frame(width: RuleColumns.source, alignment: .leading)
            Color.clear.frame(width: RuleColumns.arrow, height: 1)
            Text("Opens In")
                .padding(.leading, RuleColumns.pickerInset)
                .frame(width: RuleColumns.target, alignment: .leading)
            Text("Private")
                .frame(width: RuleColumns.privacy)
            Color.clear.frame(width: RuleColumns.delete, height: 1)
        }
    }
}

private struct RuleRow: View {
    @ObservedObject var model: AppModel
    @Binding var rule: Rule
    var focus: FocusState<UUID?>.Binding

    var body: some View {
        HStack(spacing: RuleColumns.spacing) {
            targetIcon
                .frame(width: RuleColumns.icon, height: RuleColumns.icon)
            TextField("Link", text: $rule.pattern, prompt: Text("Any link"))
                .frame(minWidth: 140)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .focused(focus, equals: rule.id)
                .onSubmit { rule.pattern = RulePattern(rule.pattern).normalized }
            Picker("From", selection: $rule.sourceBundleID) {
                Text("Any app").tag(String?.none)
                Divider()
                ForEach(model.sourceApps) { app in
                    Text(app.name).tag(String?.some(app.bundleID))
                }
                if let source = rule.sourceBundleID, !model.sourceApps.contains(where: { $0.bundleID == source }) {
                    Text(source).tag(String?.some(source))
                }
            }
            .labelsHidden()
            .fixedSize()
            .frame(width: RuleColumns.source, alignment: .leading)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: RuleColumns.arrow)
            Picker("Opens In", selection: $rule.target) {
                ForEach(model.allOptions) { option in
                    Text(option.title).tag(option.target)
                }
                if model.resolve(rule.target) == nil {
                    Text("Missing: \(rule.target.bundleID)").tag(rule.target)
                }
            }
            .labelsHidden()
            .fixedSize()
            .frame(width: RuleColumns.target, alignment: .leading)
            privateToggle
                .frame(width: RuleColumns.privacy)
            Button {
                model.removeRule(id: rule.id)
            } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .frame(width: RuleColumns.delete)
            .help("Delete Rule")
        }
        .contextMenu {
            Button("Delete Rule", role: .destructive) { model.removeRule(id: rule.id) }
        }
    }

    private var privateToggle: some View {
        let supported = model.resolve(rule.target)?.supportsPrivateWindow ?? false
        return Toggle(isOn: $rule.opensPrivately) {
            Label("Private Window", systemImage: "eyeglasses")
                .labelStyle(.iconOnly)
        }
        .toggleStyle(.button)
        .disabled(!supported)
        .help(supported
            ? "Open matching links in a private window"
            : "This browser can't open private windows from other apps")
    }

    @ViewBuilder
    private var targetIcon: some View {
        if let option = model.resolve(rule.target) {
            Image(nsImage: option.app.icon)
                .resizable()
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help("This browser or profile is missing")
        }
    }
}

struct BrowsersSettingsView: View {
    @ObservedObject var model: AppModel

    private func appRow(_ app: BrowserApp) -> some View {
        Toggle(isOn: Binding(
            get: { model.isVisible(app) },
            set: { model.setVisible($0, for: app) }
        )) {
            HStack(spacing: 10) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                    if app.profiles.count > 1 {
                        Text("\(model.visibleProfileCount(of: app)) of \(app.profiles.count) profiles shown")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func profileRow(_ profile: BrowserProfile, of app: BrowserApp) -> some View {
        let visible = model.isVisible(profile, of: app)
        let isLastVisible = visible && model.visibleProfileCount(of: app) == 1
        return Toggle(isOn: Binding(
            get: { visible },
            set: { model.setVisible($0, for: profile, of: app) }
        )) {
            HStack(spacing: 8) {
                ProfileAvatar(profile: profile)
                Text(profile.name)
            }
        }
        .disabled(isLastVisible)
        .help(isLastVisible ? "Turn off \(app.name) above to hide its last profile" : "")
        .padding(.leading, 38)
    }

    var body: some View {
        Form {
            Section {
                ForEach(model.apps) { app in
                    appRow(app)
                    if SafariProfileMenu.supportsProfiles(bundleID: app.bundleID), model.isVisible(app) {
                        SafariProfileAccessRow(model: model, app: app)
                    }
                    if app.profiles.count > 1, model.isVisible(app) {
                        ForEach(app.profiles, id: \.directory) { profile in
                            profileRow(profile, of: app)
                        }
                    }
                }
            } header: {
                Text("Show in Picker")
            } footer: {
                SectionFooter("Chromium browsers and Safari get one bubble per profile. Turn off the profiles you don't use. Hiding a browser or profile only takes it out of the picker. Rules can still send links to it.")
            }
        }
    }
}

private struct SafariProfileAccessRow: View {
    @ObservedObject var model: AppModel
    let app: BrowserApp

    private var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID).isEmpty
    }

    var body: some View {
        Group {
            if !model.hasAccessibilityAccess {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Safari profiles and private windows need Accessibility access", systemImage: "hand.raised.fill")
                            .foregroundStyle(.orange)
                        Text("macOS has no way to open a Safari profile or private window directly, so knURLink opens the window through Safari's File menu, then hands it the link.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Allow…") { model.requestAccessibilityAccess() }
                    Button("Open Settings…") { SafariAutomation.openAccessibilitySettings() }
                        .buttonStyle(.link)
                }
            } else if app.profiles.isEmpty, !isRunning {
                HStack {
                    Text("Open \(app.name) once so knURLink can see its profiles.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check Again") { model.refresh() }
                }
            }
        }
        .padding(.leading, 38)
    }
}

private struct ProfileAvatar: View {
    let profile: BrowserProfile

    var body: some View {
        if let image = profile.pictureURL.flatMap(NSImage.init(contentsOf:)) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 20, height: 20)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
    }
}
