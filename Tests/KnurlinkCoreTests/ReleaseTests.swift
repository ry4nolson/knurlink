import XCTest
@testable import KnurlinkCore

final class ReleaseTests: XCTestCase {
    func testVersionOrdering() {
        XCTAssertTrue(AppVersion("1.0.1") > AppVersion("1.0.0"))
        XCTAssertTrue(AppVersion("v1.10.0") > AppVersion("1.9.9"))
        XCTAssertTrue(AppVersion("2.0") > AppVersion("1.99.99"))
        XCTAssertEqual(AppVersion("1.0"), AppVersion("v1.0.0"))
        XCTAssertFalse(AppVersion("1.0.0") > AppVersion("1.0.0"))
        XCTAssertFalse(AppVersion("") > AppVersion("0.0.0"))
        XCTAssertTrue(AppVersion("1.2.0-beta") < AppVersion("1.2.1"))
    }

    func testDecodesLatestReleasePayload() throws {
        let json = """
        {
          "tag_name": "v1.2.0",
          "html_url": "https://github.com/ry4nolson/knurlink/releases/tag/v1.2.0",
          "assets": [
            {"name": "knURLink.zip", "browser_download_url": "https://github.com/ry4nolson/knurlink/releases/download/v1.2.0/knURLink.zip"},
            {"name": "knURLink.dmg", "browser_download_url": "https://github.com/ry4nolson/knurlink/releases/download/v1.2.0/knURLink.dmg"}
          ]
        }
        """
        let release = try JSONDecoder().decode(ReleaseInfo.self, from: Data(json.utf8))
        XCTAssertEqual(release.displayVersion, "1.2.0")
        XCTAssertTrue(release.isNewer(than: "1.1.9"))
        XCTAssertFalse(release.isNewer(than: "1.2.0"))
        XCTAssertFalse(release.isNewer(than: "2.0.0"))
        XCTAssertEqual(release.downloadURL.lastPathComponent, "knURLink.dmg")
    }

    func testDownloadFallsBackWhenLinksPointElsewhere() throws {
        let json = """
        {
          "tag_name": "v9.0.0",
          "html_url": "https://example.com/elsewhere",
          "assets": [{"name": "knURLink.dmg", "browser_download_url": "https://example.com/knURLink.dmg"}]
        }
        """
        let release = try JSONDecoder().decode(ReleaseInfo.self, from: Data(json.utf8))
        XCTAssertEqual(release.downloadURL, ReleaseInfo.releasesPage)
    }

    func testDownloadUsesReleasePageWhenThereIsNoDiskImage() throws {
        let json = """
        {"tag_name": "v1.0.1", "html_url": "https://github.com/ry4nolson/knurlink/releases/tag/v1.0.1", "assets": []}
        """
        let release = try JSONDecoder().decode(ReleaseInfo.self, from: Data(json.utf8))
        XCTAssertEqual(release.downloadURL.absoluteString, "https://github.com/ry4nolson/knurlink/releases/tag/v1.0.1")
    }
}
