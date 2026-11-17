import Foundation

public enum SafariProfileMenu {
    public static let bundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
    ]

    private static let prefix = "New "
    private static let suffix = " Window"
    private static let excludedNames: Set<String> = ["private", "empty tab group"]
    private static let privateWindowTitle = "New Private Window"
    private static let privateWindowKey = "N"
    private static let shiftModifier = 1

    public static func supportsProfiles(bundleID: String) -> Bool {
        bundleIDs.contains(bundleID)
    }

    public static func profileName(fromMenuTitle title: String) -> String? {
        guard title.hasPrefix(prefix), title.hasSuffix(suffix), title.count > prefix.count + suffix.count else { return nil }
        let name = String(title.dropFirst(prefix.count).dropLast(suffix.count))
            .trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !excludedNames.contains(name.lowercased()) else { return nil }
        return name
    }

    public static func profileNames(fromMenuTitles titles: [String]) -> [String] {
        var seen = Set<String>()
        return titles
            .compactMap(profileName(fromMenuTitle:))
            .filter { seen.insert($0).inserted }
    }

    public static func menuTitle(forProfile name: String) -> String {
        prefix + name + suffix
    }

    public static func isPrivateWindowItem(title: String?, commandKey: String?, modifiers: Int?) -> Bool {
        title == privateWindowTitle || (commandKey?.uppercased() == privateWindowKey && modifiers == shiftModifier)
    }
}
