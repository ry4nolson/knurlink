public enum PrivateWindow {
    private static let incognito: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "com.google.Chrome.canary",
        "org.chromium.Chromium",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "com.vivaldi.Vivaldi",
    ]

    private static let inPrivate: Set<String> = [
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Beta",
        "com.microsoft.edgemac.Dev",
        "com.microsoft.edgemac.Canary",
    ]

    private static let firefox: Set<String> = [
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "org.mozilla.nightly",
    ]

    public static func argument(forBundleID bundleID: String) -> String? {
        if incognito.contains(bundleID) { return "--incognito" }
        if inPrivate.contains(bundleID) { return "--inprivate" }
        if firefox.contains(bundleID) { return "-private-window" }
        return nil
    }
}
