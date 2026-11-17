import KnurlinkCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let error = model.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            defaultBrowserSection
            startupSection
            rulesSection
            RuleTesterView(model: model)
            browsersSection
        }
        .padding(20)
        .frame(width: 720)
        .onAppear { model.refresh() }
    }

    private var defaultBrowserSection: some View {
        GroupBox("Default browser") {
            HStack {
                if model.isDefaultBrowser {
                    Label("knURLink is handling your links", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("knURLink only sees links when it's the default browser.")
                }
                Spacer()
                Button("Make Default") { model.makeDefaultBrowser() }
                    .disabled(model.isDefaultBrowser)
            }
            .padding(6)
        }
    }

    private var startupSection: some View {
        GroupBox("Startup") {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchesAtLogin },
                    set: { model.setLaunchesAtLogin($0) }
                ))
                if model.loginItemNeedsApproval {
                    Text("Allow knURLink under System Settings > General > Login Items to finish turning this on.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
    }

    private var rulesSection: some View {
        GroupBox("Rules") {
            VStack(alignment: .leading, spacing: 8) {
                if model.config.rules.isEmpty {
                    Text("No rules yet. Links that match a rule skip the picker.")
                        .foregroundStyle(.secondary)
                }
                ForEach($model.config.rules) { $rule in
                    HStack {
                        TextField("any link", text: $rule.pattern)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { rule.pattern = RulePattern(rule.pattern).normalized }
                        Text("from")
                            .foregroundStyle(.secondary)
                        Picker("", selection: $rule.sourceBundleID) {
                            Text("Any app").tag(String?.none)
                            ForEach(model.sourceApps) { app in
                                Text(app.name).tag(String?.some(app.bundleID))
                            }
                            if let source = rule.sourceBundleID, !model.sourceApps.contains(where: { $0.bundleID == source }) {
                                Text(source).tag(String?.some(source))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        Picker("", selection: $rule.target) {
                            ForEach(model.allOptions) { option in
                                Text(option.title).tag(option.target)
                            }
                            if model.resolve(rule.target) == nil {
                                Text("Missing: \(rule.target.bundleID)").tag(rule.target)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                        Button {
                            model.removeRule(id: rule.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Add Rule") { model.addBlankRule() }
                Text("Use a domain (tiktok.com) or a domain with a path (github.com/my-org). Subdomains and deeper paths are covered. Leave the link blank to match everything from one app. The most specific link wins, and a rule with no link is the fallback. Apps show up in the list while they're running.")
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
    }

    private var browsersSection: some View {
        GroupBox("Show in picker") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(model.apps) { app in
                    Toggle(isOn: Binding(
                        get: { model.isVisible(app) },
                        set: { model.setVisible($0, for: app) }
                    )) {
                        HStack(spacing: 6) {
                            Image(nsImage: app.icon)
                                .resizable()
                                .frame(width: 18, height: 18)
                            Text(app.name)
                            if app.profiles.count > 1 {
                                Text("\(app.profiles.count) profiles")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
    }
}
