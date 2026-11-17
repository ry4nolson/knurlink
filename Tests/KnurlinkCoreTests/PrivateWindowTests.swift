import XCTest
@testable import KnurlinkCore

final class PrivateWindowTests: XCTestCase {
    func testLaunchArgumentsPerBrowserFamily() {
        XCTAssertEqual(PrivateWindow.argument(forBundleID: "com.google.Chrome"), "--incognito")
        XCTAssertEqual(PrivateWindow.argument(forBundleID: "com.microsoft.edgemac"), "--inprivate")
        XCTAssertEqual(PrivateWindow.argument(forBundleID: "org.mozilla.firefox"), "-private-window")
        XCTAssertNil(PrivateWindow.argument(forBundleID: "com.apple.Safari"))
    }

    func testSafariSupportsPrivateWindowsWithoutALaunchArgument() {
        XCTAssertTrue(PrivateWindow.isSupported(bundleID: "com.apple.Safari"))
        XCTAssertTrue(PrivateWindow.isSupported(bundleID: "com.apple.SafariTechnologyPreview"))
        XCTAssertTrue(PrivateWindow.isSupported(bundleID: "com.brave.Browser"))
        XCTAssertFalse(PrivateWindow.isSupported(bundleID: "company.thebrowser.Browser"))
    }
}
