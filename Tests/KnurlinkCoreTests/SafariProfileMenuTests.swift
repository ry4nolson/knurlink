import XCTest
@testable import KnurlinkCore

final class SafariProfileMenuTests: XCTestCase {
    func testReadsProfilesFromFileMenu() {
        let titles = [
            "New Personal Window",
            "New testprofile Window",
            "New Private Window",
            "New Tab",
            "New Tab at End",
            "New Empty Tab Group",
            "Open File…",
            "Close Window",
        ]
        XCTAssertEqual(SafariProfileMenu.profileNames(fromMenuTitles: titles), ["Personal", "testprofile"])
    }

    func testIgnoresPlainNewWindowWhenThereAreNoProfiles() {
        XCTAssertEqual(SafariProfileMenu.profileNames(fromMenuTitles: ["New Window", "New Private Window", "New Tab"]), [])
    }

    func testKeepsNamesWithSpacesAndDropsDuplicates() {
        let titles = ["New Side Projects Window", "New Work Window", "New Work Window"]
        XCTAssertEqual(SafariProfileMenu.profileNames(fromMenuTitles: titles), ["Side Projects", "Work"])
    }

    func testMenuTitleRoundTrips() {
        let title = SafariProfileMenu.menuTitle(forProfile: "Work Stuff")
        XCTAssertEqual(title, "New Work Stuff Window")
        XCTAssertEqual(SafariProfileMenu.profileName(fromMenuTitle: title), "Work Stuff")
    }

    func testOnlySafariSupportsProfiles() {
        XCTAssertTrue(SafariProfileMenu.supportsProfiles(bundleID: "com.apple.Safari"))
        XCTAssertTrue(SafariProfileMenu.supportsProfiles(bundleID: "com.apple.SafariTechnologyPreview"))
        XCTAssertFalse(SafariProfileMenu.supportsProfiles(bundleID: "com.google.Chrome"))
    }

    func testFindsPrivateWindowItemByTitleOrShortcut() {
        XCTAssertTrue(SafariProfileMenu.isPrivateWindowItem(title: "New Private Window", commandKey: nil, modifiers: nil))
        XCTAssertTrue(SafariProfileMenu.isPrivateWindowItem(title: "Nouvelle fenêtre privée", commandKey: "N", modifiers: 1))
        XCTAssertTrue(SafariProfileMenu.isPrivateWindowItem(title: nil, commandKey: "n", modifiers: 1))
    }

    func testIgnoresOtherNewWindowItems() {
        XCTAssertFalse(SafariProfileMenu.isPrivateWindowItem(title: "New Window", commandKey: "N", modifiers: 0))
        XCTAssertFalse(SafariProfileMenu.isPrivateWindowItem(title: "New Work Window", commandKey: nil, modifiers: nil))
        XCTAssertFalse(SafariProfileMenu.isPrivateWindowItem(title: "New Tab", commandKey: "T", modifiers: 0))
        XCTAssertFalse(SafariProfileMenu.isPrivateWindowItem(title: "Reopen Last Closed Tab", commandKey: "T", modifiers: 1))
    }
}
