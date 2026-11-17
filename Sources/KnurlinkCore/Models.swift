import Foundation

public struct BrowserTarget: Codable, Hashable, Sendable {
    public var bundleID: String
    public var profileDirectory: String?

    public init(bundleID: String, profileDirectory: String? = nil) {
        self.bundleID = bundleID
        self.profileDirectory = profileDirectory
    }
}

public struct Rule: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var pattern: String
    public var sourceBundleID: String?
    public var target: BrowserTarget

    private enum CodingKeys: String, CodingKey {
        case id, pattern, domain, sourceBundleID, target
    }

    public init(id: UUID = UUID(), pattern: String = "", sourceBundleID: String? = nil, target: BrowserTarget) {
        self.id = id
        self.pattern = pattern
        self.sourceBundleID = sourceBundleID
        self.target = target
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
            ?? container.decodeIfPresent(String.self, forKey: .domain)
            ?? ""
        sourceBundleID = try container.decodeIfPresent(String.self, forKey: .sourceBundleID)
        target = try container.decode(BrowserTarget.self, forKey: .target)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pattern, forKey: .pattern)
        try container.encodeIfPresent(sourceBundleID, forKey: .sourceBundleID)
        try container.encode(target, forKey: .target)
    }
}

public struct Config: Codable, Equatable, Sendable {
    public var rules: [Rule]
    public var appVisibility: [String: Bool]

    public init(rules: [Rule] = [], appVisibility: [String: Bool] = [:]) {
        self.rules = rules
        self.appVisibility = appVisibility
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rules = try container.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        appVisibility = try container.decodeIfPresent([String: Bool].self, forKey: .appVisibility) ?? [:]
    }
}
