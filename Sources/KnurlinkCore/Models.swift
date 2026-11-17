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
    public var opensPrivately: Bool

    private enum CodingKeys: String, CodingKey {
        case id, pattern, domain, sourceBundleID, target, opensPrivately
    }

    public init(
        id: UUID = UUID(),
        pattern: String = "",
        sourceBundleID: String? = nil,
        target: BrowserTarget,
        opensPrivately: Bool = false
    ) {
        self.id = id
        self.pattern = pattern
        self.sourceBundleID = sourceBundleID
        self.target = target
        self.opensPrivately = opensPrivately
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
            ?? container.decodeIfPresent(String.self, forKey: .domain)
            ?? ""
        sourceBundleID = try container.decodeIfPresent(String.self, forKey: .sourceBundleID)
        target = try container.decode(BrowserTarget.self, forKey: .target)
        opensPrivately = try container.decodeIfPresent(Bool.self, forKey: .opensPrivately) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pattern, forKey: .pattern)
        try container.encodeIfPresent(sourceBundleID, forKey: .sourceBundleID)
        try container.encode(target, forKey: .target)
        if opensPrivately {
            try container.encode(true, forKey: .opensPrivately)
        }
    }
}

public struct Config: Codable, Equatable, Sendable {
    public var rules: [Rule]
    public var appVisibility: [String: Bool]
    public var hiddenProfiles: [String: [String]]
    public var checksForUpdates: Bool

    public init(
        rules: [Rule] = [],
        appVisibility: [String: Bool] = [:],
        hiddenProfiles: [String: [String]] = [:],
        checksForUpdates: Bool = true
    ) {
        self.rules = rules
        self.appVisibility = appVisibility
        self.hiddenProfiles = hiddenProfiles
        self.checksForUpdates = checksForUpdates
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rules = try container.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        appVisibility = try container.decodeIfPresent([String: Bool].self, forKey: .appVisibility) ?? [:]
        hiddenProfiles = try container.decodeIfPresent([String: [String]].self, forKey: .hiddenProfiles) ?? [:]
        checksForUpdates = try container.decodeIfPresent(Bool.self, forKey: .checksForUpdates) ?? true
    }

    public func isProfileVisible(_ directory: String, in bundleID: String) -> Bool {
        !(hiddenProfiles[bundleID]?.contains(directory) ?? false)
    }

    public mutating func setProfile(_ directory: String, in bundleID: String, visible: Bool) {
        var hidden = Set(hiddenProfiles[bundleID] ?? [])
        if visible {
            hidden.remove(directory)
        } else {
            hidden.insert(directory)
        }
        hiddenProfiles[bundleID] = hidden.isEmpty ? nil : hidden.sorted()
    }
}
