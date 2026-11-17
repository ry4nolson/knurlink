import KnurlinkCore
import SwiftUI

struct AboutView: View {
    private static let repository = URL(string: "https://github.com/ry4nolson/knurlink")!
    private static let sponsor = URL(string: "https://www.texasbeardcompany.com")!

    @ObservedObject var model: AppModel
    @ObservedObject var updater: UpdateChecker

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 84, height: 84)
            VStack(spacing: 2) {
                Text("knURLink")
                    .font(.title2.weight(.semibold))
                Text("Version \(updater.currentVersion)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("Decides which browser a link opens in.")
                .foregroundStyle(.secondary)

            Divider()

            updateStatus
            Toggle("Check for updates automatically", isOn: $model.config.checksForUpdates)
                .toggleStyle(.checkbox)

            Divider()

            HStack(spacing: 16) {
                Button("GitHub") { NSWorkspace.shared.open(Self.repository) }
                Button("Releases") { NSWorkspace.shared.open(ReleaseInfo.releasesPage) }
            }
            .buttonStyle(.link)

            VStack(spacing: 6) {
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
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 340)
        .task { await updater.check() }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updater.state {
        case .idle, .checking:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking for updates…")
                    .foregroundStyle(.secondary)
            }
        case .upToDate:
            HStack(spacing: 10) {
                Label("You're up to date", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                checkButton
            }
        case let .available(release):
            VStack(spacing: 8) {
                Label("Version \(release.displayVersion) is available", systemImage: "arrow.down.circle.fill")
                    .foregroundStyle(.orange)
                Button("Download") { NSWorkspace.shared.open(release.downloadURL) }
                    .keyboardShortcut(.defaultAction)
            }
        case let .failed(message):
            VStack(spacing: 6) {
                Label("Couldn't check for updates", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                checkButton
            }
        }
    }

    private var checkButton: some View {
        Button("Check Again") {
            Task { await updater.check() }
        }
        .controlSize(.small)
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
