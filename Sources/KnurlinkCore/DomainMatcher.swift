import Foundation

public struct RulePattern: Equatable, Sendable {
    public let host: String
    public let pathSegments: [String]

    public init(_ raw: String) {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let scheme = value.range(of: "://") {
            value = String(value[scheme.upperBound...])
        }
        value = String(value.prefix { $0 != "?" && $0 != "#" })
        let parts = value.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        host = DomainMatcher.normalize(parts.first.map(String.init) ?? "")
        pathSegments = parts.count > 1 ? parts[1].split(separator: "/").map(String.init) : []
    }

    public var isEmpty: Bool { host.isEmpty }

    public var normalized: String {
        isEmpty ? "" : ([host] + pathSegments).joined(separator: "/")
    }

    public func matches(_ url: URL) -> Bool {
        guard !isEmpty, let urlHost = url.host, DomainMatcher.matches(host: urlHost, pattern: host) else { return false }
        let urlSegments = url.path.lowercased().split(separator: "/").map(String.init)
        return urlSegments.count >= pathSegments.count && Array(urlSegments.prefix(pathSegments.count)) == pathSegments
    }
}

public enum DomainMatcher {
    private static let compoundSecondLevels: Set<String> = ["co", "com", "org", "net", "gov", "ac", "edu"]

    public static func normalize(_ input: String) -> String {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let scheme = value.range(of: "://") {
            value = String(value[scheme.upperBound...])
        }
        value = String(value.prefix { $0 != "/" && $0 != "?" && $0 != "#" })
        if let userInfoEnd = value.lastIndex(of: "@") {
            value = String(value[value.index(after: userInfoEnd)...])
        }
        if let port = value.firstIndex(of: ":") {
            value = String(value[..<port])
        }
        while value.hasPrefix("*") || value.hasPrefix(".") {
            value.removeFirst()
        }
        while value.hasSuffix(".") {
            value.removeLast()
        }
        if value.hasPrefix("www.") {
            value.removeFirst(4)
        }
        return value
    }

    public static func matches(host: String, pattern: String) -> Bool {
        let normalizedPattern = normalize(pattern)
        guard !normalizedPattern.isEmpty else { return false }
        let normalizedHost = normalize(host)
        return normalizedHost == normalizedPattern || normalizedHost.hasSuffix("." + normalizedPattern)
    }

    public static func rankedRules(for url: URL, source: String? = nil, in rules: [Rule]) -> [Rule] {
        rules
            .enumerated()
            .compactMap { offset, rule -> (rule: Rule, specificity: [Int], offset: Int)? in
                let pattern = RulePattern(rule.pattern)
                let requiredSource = rule.sourceBundleID.flatMap { $0.isEmpty ? nil : $0 }
                guard !pattern.isEmpty || requiredSource != nil else { return nil }
                guard pattern.isEmpty || pattern.matches(url) else { return nil }
                guard requiredSource == nil || requiredSource == source else { return nil }
                return (rule, [pattern.host.count, pattern.pathSegments.count, requiredSource == nil ? 0 : 1], offset)
            }
            .sorted {
                $0.specificity == $1.specificity
                    ? $0.offset < $1.offset
                    : $1.specificity.lexicographicallyPrecedes($0.specificity)
            }
            .map(\.rule)
    }

    public static func rule(for url: URL, source: String? = nil, in rules: [Rule]) -> Rule? {
        rankedRules(for: url, source: source, in: rules).first
    }

    public static func webURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.host?.isEmpty == false
        else { return nil }
        return url
    }

    public static func suggestedDomain(forHost host: String) -> String {
        let normalizedHost = normalize(host)
        let labels = normalizedHost.split(separator: ".").map(String.init)
        guard labels.count > 2, labels.contains(where: { Int($0) == nil }) else { return normalizedHost }
        let topLevel = labels[labels.count - 1]
        let secondLevel = labels[labels.count - 2]
        let labelCount = topLevel.count == 2 && compoundSecondLevels.contains(secondLevel) ? 3 : 2
        return labels.suffix(labelCount).joined(separator: ".")
    }
}
