import KnurlinkCore
import SwiftUI

struct RuleTesterView: View {
    @ObservedObject var model: AppModel
    @State private var input = ""
    @State private var source: String?

    var body: some View {
        Form {
            Section {
                TextField("Link", text: $input, prompt: Text("Paste a link"))
                Picker("From", selection: $source) {
                    Text("Any app").tag(String?.none)
                    Divider()
                    ForEach(model.sourceApps) { app in
                        Text(app.name).tag(String?.some(app.bundleID))
                    }
                }
            } footer: {
                SectionFooter("See which rule a link would hit without opening it.")
            }

            Section("Result") {
                if let outcome = model.testOutcome(for: input, source: source) {
                    result(for: outcome)
                } else {
                    Text("Paste a link above to see where it would open.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func result(for outcome: RuleTestOutcome) -> some View {
        switch outcome {
        case .invalid:
            status("That's not a web link.", symbol: "exclamationmark.triangle.fill", tint: .orange)
        case .noMatch:
            status("No rule matches. The picker opens.", symbol: "circle.grid.cross.fill", tint: .secondary)
        case let .missingTarget(winner):
            status("Its browser is missing. The picker opens.", symbol: "exclamationmark.triangle.fill", tint: .orange)
            LabeledContent("Matched rule", value: model.describe(winner))
        case let .routed(option, winner, others):
            LabeledContent("Opens in") {
                HStack(spacing: 6) {
                    Image(nsImage: option.app.icon)
                        .resizable()
                        .frame(width: 18, height: 18)
                    Text(option.title)
                        .foregroundStyle(.primary)
                }
            }
            if winner.opensPrivately {
                LabeledContent("Window") {
                    if option.supportsPrivateWindow {
                        Label("Private", systemImage: "eyeglasses")
                    } else {
                        Text("Normal. \(option.app.name) can't open private windows.")
                    }
                }
            }
            LabeledContent("Matched rule", value: model.describe(winner))
            if !others.isEmpty {
                LabeledContent("Also matched") {
                    VStack(alignment: .trailing, spacing: 2) {
                        ForEach(others) { Text(model.describe($0)) }
                    }
                }
            }
        }
    }

    private func status(_ text: String, symbol: String, tint: some ShapeStyle) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
        }
    }
}
