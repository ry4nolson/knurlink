import XCTest
@testable import KnurlinkCore

final class DomainMatcherTests: XCTestCase {
    private let brave = BrowserTarget(bundleID: "com.brave.Browser")
    private let chrome = BrowserTarget(bundleID: "com.google.Chrome", profileDirectory: "Profile 1")
    private let slack = "com.tinyspeck.slackmacgap"

    func testNormalizeStripsSchemePathPortAndWWW() {
        XCTAssertEqual(DomainMatcher.normalize(" https://WWW.TikTok.com:443/@someone/video/1?x=1 "), "tiktok.com")
        XCTAssertEqual(DomainMatcher.normalize("*.tiktok.com"), "tiktok.com")
        XCTAssertEqual(DomainMatcher.normalize("tiktok.com."), "tiktok.com")
        XCTAssertEqual(DomainMatcher.normalize(""), "")
    }

    func testMatchesExactAndSubdomains() {
        XCTAssertTrue(DomainMatcher.matches(host: "tiktok.com", pattern: "tiktok.com"))
        XCTAssertTrue(DomainMatcher.matches(host: "www.tiktok.com", pattern: "tiktok.com"))
        XCTAssertTrue(DomainMatcher.matches(host: "vm.tiktok.com", pattern: "TikTok.com"))
        XCTAssertTrue(DomainMatcher.matches(host: "vm.tiktok.com", pattern: "https://www.tiktok.com/"))
    }

    func testDoesNotMatchLookalikes() {
        XCTAssertFalse(DomainMatcher.matches(host: "nottiktok.com", pattern: "tiktok.com"))
        XCTAssertFalse(DomainMatcher.matches(host: "tiktok.com.evil.com", pattern: "tiktok.com"))
        XCTAssertFalse(DomainMatcher.matches(host: "tiktok.com", pattern: "vm.tiktok.com"))
        XCTAssertFalse(DomainMatcher.matches(host: "tiktok.com", pattern: ""))
        XCTAssertFalse(DomainMatcher.matches(host: "tiktok.com", pattern: "  "))
    }

    func testRuleLookupUsesURLHostNotUserInfo() throws {
        let rules = [Rule(pattern: "tiktok.com", target: brave)]
        let spoofed = try XCTUnwrap(URL(string: "https://tiktok.com@evil.com/video"))
        XCTAssertNil(DomainMatcher.rule(for: spoofed, in: rules))
        let real = try XCTUnwrap(URL(string: "https://vm.tiktok.com/ZT8abc/"))
        XCTAssertEqual(DomainMatcher.rule(for: real, in: rules)?.target, brave)
    }

    func testMostSpecificRuleWins() throws {
        let rules = [
            Rule(pattern: "google.com", target: brave),
            Rule(pattern: "mail.google.com", target: chrome),
        ]
        let mail = try XCTUnwrap(URL(string: "https://mail.google.com/mail/u/0"))
        XCTAssertEqual(DomainMatcher.rule(for: mail, in: rules)?.target, chrome)
        let docs = try XCTUnwrap(URL(string: "https://docs.google.com/document"))
        XCTAssertEqual(DomainMatcher.rule(for: docs, in: rules)?.target, brave)
        let other = try XCTUnwrap(URL(string: "https://example.com"))
        XCTAssertNil(DomainMatcher.rule(for: other, in: rules))
    }

    func testPatternParsing() {
        XCTAssertEqual(RulePattern("https://GitHub.com/Acme-Corp/?tab=repos").normalized, "github.com/acme-corp")
        XCTAssertEqual(RulePattern("www.tiktok.com").normalized, "tiktok.com")
        XCTAssertEqual(RulePattern("github.com/a/b/").pathSegments, ["a", "b"])
        XCTAssertTrue(RulePattern("  ").isEmpty)
        XCTAssertTrue(RulePattern("/orphan/path").isEmpty)
    }

    func testPathRulesMatchOnSegmentBoundaries() throws {
        let pattern = RulePattern("github.com/acme-corp")
        XCTAssertTrue(pattern.matches(try XCTUnwrap(URL(string: "https://github.com/acme-corp"))))
        XCTAssertTrue(pattern.matches(try XCTUnwrap(URL(string: "https://github.com/Acme-Corp/ui-kit/pull/12?x=1"))))
        XCTAssertFalse(pattern.matches(try XCTUnwrap(URL(string: "https://github.com/acme-corp-fork/repo"))))
        XCTAssertFalse(pattern.matches(try XCTUnwrap(URL(string: "https://github.com/other/acme-corp"))))
        XCTAssertFalse(pattern.matches(try XCTUnwrap(URL(string: "https://github.com/"))))
        XCTAssertFalse(pattern.matches(try XCTUnwrap(URL(string: "https://evil.com/github.com/acme-corp"))))
    }

    func testPathRuleBeatsDomainRule() throws {
        let rules = [
            Rule(pattern: "github.com", target: brave),
            Rule(pattern: "github.com/acme-corp", target: chrome),
        ]
        let work = try XCTUnwrap(URL(string: "https://github.com/acme-corp/web-app"))
        XCTAssertEqual(DomainMatcher.rule(for: work, in: rules)?.target, chrome)
        let personal = try XCTUnwrap(URL(string: "https://github.com/someone/thing"))
        XCTAssertEqual(DomainMatcher.rule(for: personal, in: rules)?.target, brave)
    }

    func testSourceOnlyRuleMatchesAnyLinkFromThatApp() throws {
        let rules = [Rule(sourceBundleID: slack, target: chrome)]
        let url = try XCTUnwrap(URL(string: "https://example.com/anything"))
        XCTAssertEqual(DomainMatcher.rule(for: url, source: slack, in: rules)?.target, chrome)
        XCTAssertNil(DomainMatcher.rule(for: url, source: "com.apple.mail", in: rules))
        XCTAssertNil(DomainMatcher.rule(for: url, source: nil, in: rules))
    }

    func testDomainRuleBeatsSourceOnlyRule() throws {
        let rules = [
            Rule(sourceBundleID: slack, target: chrome),
            Rule(pattern: "tiktok.com", target: brave),
        ]
        let tiktok = try XCTUnwrap(URL(string: "https://www.tiktok.com/t/abc123/"))
        XCTAssertEqual(DomainMatcher.rule(for: tiktok, source: slack, in: rules)?.target, brave)
        let other = try XCTUnwrap(URL(string: "https://linear.app/acme/issue/1"))
        XCTAssertEqual(DomainMatcher.rule(for: other, source: slack, in: rules)?.target, chrome)
    }

    func testSourceScopedPatternBeatsUnscopedSamePattern() throws {
        let safari = BrowserTarget(bundleID: "com.apple.Safari")
        let rules = [
            Rule(pattern: "github.com", target: brave),
            Rule(pattern: "github.com", sourceBundleID: slack, target: chrome),
            Rule(pattern: "github.com/acme-corp", target: safari),
        ]
        let repo = try XCTUnwrap(URL(string: "https://github.com/someone/thing"))
        XCTAssertEqual(DomainMatcher.rule(for: repo, source: slack, in: rules)?.target, chrome)
        XCTAssertEqual(DomainMatcher.rule(for: repo, source: "com.apple.mail", in: rules)?.target, brave)
        let org = try XCTUnwrap(URL(string: "https://github.com/acme-corp/x"))
        XCTAssertEqual(DomainMatcher.rule(for: org, source: slack, in: rules)?.target, safari)
    }

    func testBlankRuleMatchesNothing() throws {
        let rules = [Rule(target: brave), Rule(pattern: " ", sourceBundleID: "", target: brave)]
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        XCTAssertNil(DomainMatcher.rule(for: url, source: slack, in: rules))
    }

    func testSuggestedDomain() {
        XCTAssertEqual(DomainMatcher.suggestedDomain(forHost: "vm.tiktok.com"), "tiktok.com")
        XCTAssertEqual(DomainMatcher.suggestedDomain(forHost: "www.tiktok.com"), "tiktok.com")
        XCTAssertEqual(DomainMatcher.suggestedDomain(forHost: "a.b.bbc.co.uk"), "bbc.co.uk")
        XCTAssertEqual(DomainMatcher.suggestedDomain(forHost: "localhost"), "localhost")
        XCTAssertEqual(DomainMatcher.suggestedDomain(forHost: "192.168.1.10"), "192.168.1.10")
    }
}

final class ConfigStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testLoadReturnsEmptyConfigWhenFileMissing() throws {
        let store = ConfigStore(fileURL: directory.appendingPathComponent("nested/config.json"))
        XCTAssertEqual(try store.load(), Config())
    }

    func testRoundTrip() throws {
        let store = ConfigStore(fileURL: directory.appendingPathComponent("nested/config.json"))
        let config = Config(
            rules: [
                Rule(pattern: "tiktok.com", target: BrowserTarget(bundleID: "com.brave.Browser")),
                Rule(sourceBundleID: "com.tinyspeck.slackmacgap", target: BrowserTarget(bundleID: "com.google.Chrome", profileDirectory: "Profile 1")),
            ],
            appVisibility: ["com.googlecode.iterm2": false]
        )
        try store.save(config)
        XCTAssertEqual(try store.load(), config)
    }

    func testDecodesPartialFile() throws {
        let fileURL = directory.appendingPathComponent("config.json")
        try Data(#"{"rules":[]}"#.utf8).write(to: fileURL)
        XCTAssertEqual(try ConfigStore(fileURL: fileURL).load(), Config())
    }

    func testDecodesLegacyDomainKey() throws {
        let fileURL = directory.appendingPathComponent("config.json")
        let legacy = #"{"rules":[{"domain":"tiktok.com","id":"CEF940D4-7519-454F-B1D7-E582AE330D43","target":{"bundleID":"com.brave.Browser"}}]}"#
        try Data(legacy.utf8).write(to: fileURL)
        let rule = try XCTUnwrap(ConfigStore(fileURL: fileURL).load().rules.first)
        XCTAssertEqual(rule.pattern, "tiktok.com")
        XCTAssertNil(rule.sourceBundleID)
        XCTAssertEqual(rule.target.bundleID, "com.brave.Browser")
    }

    func testInvalidFileThrowsAndCanBeQuarantined() throws {
        let fileURL = directory.appendingPathComponent("config.json")
        try Data("not json".utf8).write(to: fileURL)
        let store = ConfigStore(fileURL: fileURL)
        XCTAssertThrowsError(try store.load())
        let moved = try store.quarantineInvalidFile()
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path))
        XCTAssertEqual(try store.load(), Config())
    }
}
