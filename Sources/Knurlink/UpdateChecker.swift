import Foundation
import KnurlinkCore
import os

@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case failed(String)
    }

    private static let logger = Logger(subsystem: "dev.knurlink.Knurlink", category: "updates")

    @Published private(set) var state: State = .idle

    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"

    private let session = URLSession(configuration: .ephemeral)

    var availableRelease: ReleaseInfo? {
        if case let .available(release) = state { return release }
        return nil
    }

    func check() async {
        guard state != .checking else { return }
        state = .checking
        var request = URLRequest(url: ReleaseInfo.latestEndpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status != 404 else {
                state = .upToDate
                return
            }
            guard status == 200 else {
                state = .failed("GitHub answered with status \(status).")
                return
            }
            let release = try JSONDecoder().decode(ReleaseInfo.self, from: data)
            state = release.isNewer(than: currentVersion) ? .available(release) : .upToDate
        } catch {
            Self.logger.error("Update check failed: \(error.localizedDescription, privacy: .public)")
            state = .failed(error.localizedDescription)
        }
    }
}
