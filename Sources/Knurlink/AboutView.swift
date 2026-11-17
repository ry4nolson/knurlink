import KnurlinkCore
import SwiftUI

struct AboutView: View {
    private static let repository = URL(string: "https://github.com/ry4nolson/knurlink")!
    private static let sponsor = URL(string: "https://www.texasbeardcompany.com")!

    @ObservedObject var model: AppModel
    @ObservedObject var updater: UpdateChecker

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 80, height: 80)
                    VStack(spacing: 2) {
                        Text("knURLink")
                            .font(.title.weight(.semibold))
                        Text("Version \(updater.currentVersion)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Text("Decides which browser a link opens in.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Software Update") {
                updateStatus
                Toggle("Check for updates automatically", isOn: $model.config.checksForUpdates)
            }

            Section {
                linkRow("GitHub Repository", symbol: "chevron.left.forwardslash.chevron.right", url: Self.repository)
                linkRow("Release Notes", symbol: "doc.text", url: ReleaseInfo.releasesPage)
            }

            Section {
                VStack(spacing: 8) {
                    Text("Sponsored by")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        NSWorkspace.shared.open(Self.sponsor)
                    } label: {
                        SponsorLogoView()
                    }
                    .buttonStyle(.plain)
                    .help("texasbeardcompany.com")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .task { await updater.check() }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updater.state {
        case .idle, .checking:
            HStack {
                Text("Checking for updates…")
                    .foregroundStyle(.secondary)
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
        case .upToDate:
            HStack {
                statusLabel("knURLink is up to date", symbol: "checkmark.circle.fill", tint: .green)
                Spacer()
                checkButton
            }
        case let .available(release):
            HStack {
                statusLabel("Version \(release.displayVersion) is available", symbol: "arrow.down.circle.fill", tint: .orange)
                Spacer()
                Button("Download") { NSWorkspace.shared.open(release.downloadURL) }
                    .buttonStyle(.borderedProminent)
            }
        case let .failed(message):
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    statusLabel("Couldn't check for updates", symbol: "exclamationmark.triangle.fill", tint: .orange)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                checkButton
            }
        }
    }

    private func statusLabel(_ text: String, symbol: String, tint: Color) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
        }
    }

    private var checkButton: some View {
        Button("Check Now") {
            Task { await updater.check() }
        }
    }

    private func linkRow(_ title: String, symbol: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: symbol)
                        .frame(width: 20)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SponsorLogoView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let logo {
            Image(nsImage: logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 30)
        } else {
            Text("Texas Beard Company")
                .font(.subheadline.weight(.bold))
        }
    }

    private var logo: NSImage? {
        Bundle.main.url(forResource: colorScheme == .dark ? "SponsorLogoWhite" : "SponsorLogo", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
    }
}
