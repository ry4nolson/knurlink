import KnurlinkCore
import SwiftUI

struct RuleTesterView: View {
    @ObservedObject var model: AppModel
    @State private var input = ""
    @State private var source: String?

    var body: some View {
        GroupBox("Test a link") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Paste a link to see where it would open", text: $input)
                        .textFieldStyle(.roundedBorder)
                    Text("from")
                        .foregroundStyle(.secondary)
                    Picker("", selection: $source) {
                        Text("Any app").tag(String?.none)
                        ForEach(model.sourceApps) { app in
                            Text(app.name).tag(String?.some(app.bundleID))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
                if let outcome = model.testOutcome(for: input, source: source) {
                    result(for: outcome)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
    }

    @ViewBuilder
    private func result(for outcome: RuleTestOutcome) -> some View {
        switch outcome {
        case .invalid:
            Label("That's not a web link.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        case .noMatch:
            Label("No rule matches. The picker opens.", systemImage: "circle.grid.cross")
                .foregroundStyle(.secondary)
        case let .missingTarget(winner):
            Label("Matched \(model.describe(winner)), but its browser is missing. The picker opens.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
        case let .routed(option, winner, others):
            Label("Opens in \(option.title)", systemImage: "arrow.right.circle.fill")
                .foregroundStyle(.green)
            Text("Matched rule: \(model.describe(winner))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !others.isEmpty {
                Text("Also matched, but less specific: \(others.map(model.describe).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
