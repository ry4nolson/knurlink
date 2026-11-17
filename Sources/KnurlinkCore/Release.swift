import Foundation

public struct AppVersion: Comparable, Sendable {
    public let components: [Int]

    public init(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let numeric = trimmed.hasPrefix("v") || trimmed.hasPrefix("V") ? String(trimmed.dropFirst()) : trimmed
        components = numeric.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }

    private func component(_ index: Int) -> Int {
        index < components.count ? components[index] : 0
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        for index in 0..<max(lhs.components.count, rhs.components.count) {
            let left = lhs.component(index)
            let right = rhs.component(index)
            if left != right { return left < right }
        }
        return false
    }
}

public struct ReleaseInfo: Decodable, Equatable, Sendable {
    public struct Asset: Decodable, Equatable, Sendable {
        public let name: String
        public let downloadURL: URL

        private enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
        }
    }

    public static let releasesPage = URL(string: "https://github.com/ry4nolson/knurlink/releases/latest")!
    public static let latestEndpoint = URL(string: "https://api.github.com/repos/ry4nolson/knurlink/releases/latest")!

    public let tagName: String
    public let pageURL: URL
    public let assets: [Asset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case pageURL = "html_url"
        case assets
    }

    public var version: AppVersion { AppVersion(tagName) }

    public var displayVersion: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    public var downloadURL: URL {
        let candidates = [assets.first { $0.name.hasSuffix(".dmg") }?.downloadURL, pageURL]
        return candidates.compactMap { $0 }.first(where: Self.isTrusted) ?? Self.releasesPage
    }

    public func isNewer(than current: String) -> Bool {
        version > AppVersion(current)
    }

    private static func isTrusted(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "github.com" && url.path.lowercased().hasPrefix("/ry4nolson/knurlink/")
    }
}
