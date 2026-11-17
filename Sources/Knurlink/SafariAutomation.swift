import AppKit
import ApplicationServices
import KnurlinkCore
import os

enum SafariAutomationError: LocalizedError {
    case notTrusted
    case notRunning
    case profileMissing(String)
    case windowDidNotOpen
    case addressFieldUnavailable

    var errorDescription: String? {
        switch self {
        case .notTrusted: "knURLink needs Accessibility access to open Safari profiles."
        case .notRunning: "Safari didn't start in time."
        case let .profileMissing(name): "Safari has no profile named \(name)."
        case .windowDidNotOpen: "Safari didn't open a new window."
        case .addressFieldUnavailable: "Couldn't reach Safari's address field."
        }
    }
}

enum SafariAutomation {
    private static let logger = Logger(subsystem: "dev.knurlink.Knurlink", category: "safari")
    private static let queue = DispatchQueue(label: "dev.knurlink.Knurlink.safari")
    private static let cacheKey = "SafariProfileNames"
    private static let returnKeyCode: CGKeyCode = 36

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    static func profiles(for bundleID: String) -> [BrowserProfile] {
        guard SafariProfileMenu.supportsProfiles(bundleID: bundleID) else { return [] }
        let names: [String]
        if let live = liveProfileNames(for: bundleID) {
            names = live
            var cache = UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: [String]] ?? [:]
            if cache[bundleID] != live {
                cache[bundleID] = live
                UserDefaults.standard.set(cache, forKey: cacheKey)
            }
        } else {
            names = (UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: [String]])?[bundleID] ?? []
        }
        return names.map { BrowserProfile(directory: $0, name: $0, pictureURL: nil) }
    }

    static func open(_ url: URL, inProfile name: String, app: BrowserApp, completion: @escaping (Error?) -> Void) {
        queue.async {
            do {
                try openSynchronously(url, inProfile: name, app: app)
                completion(nil)
            } catch {
                logger.error("Safari profile open failed: \(error.localizedDescription, privacy: .public)")
                completion(error)
            }
        }
    }

    private static func liveProfileNames(for bundleID: String) -> [String]? {
        guard isTrusted, let running = runningApp(bundleID) else { return nil }
        let element = applicationElement(for: running)
        let items = fileMenuItems(of: element)
        guard !items.isEmpty else { return nil }
        return SafariProfileMenu.profileNames(fromMenuTitles: items.compactMap { string($0, kAXTitleAttribute) })
    }

    private static func openSynchronously(_ url: URL, inProfile name: String, app: BrowserApp) throws {
        guard isTrusted else { throw SafariAutomationError.notTrusted }
        let running = try launchIfNeeded(app)
        let element = applicationElement(for: running)
        let title = SafariProfileMenu.menuTitle(forProfile: name)

        let profileItem = try waitFor(timeout: 10, failure: SafariAutomationError.profileMissing(name)) {
            fileMenuItems(of: element).first { string($0, kAXTitleAttribute) == title }
        }
        let existingWindows = windows(of: element)
        guard AXUIElementPerformAction(profileItem, kAXPressAction as CFString) == .success else {
            throw SafariAutomationError.profileMissing(name)
        }
        let window = try waitFor(timeout: 5, failure: SafariAutomationError.windowDidNotOpen) {
            windows(of: element).first { candidate in !existingWindows.contains { CFEqual($0, candidate) } }
        }

        DispatchQueue.main.sync { _ = running.activate() }
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)

        if let openLocation = fileMenuItems(of: element).first(where: isOpenLocation) {
            AXUIElementPerformAction(openLocation, kAXPressAction as CFString)
        }
        let field = try waitFor(timeout: 3, failure: SafariAutomationError.addressFieldUnavailable) {
            focusedTextField(of: element, in: window)
        }
        guard AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, url.absoluteString as CFString) == .success else {
            throw SafariAutomationError.addressFieldUnavailable
        }
        pressReturn(in: running.processIdentifier)
    }

    private static func launchIfNeeded(_ app: BrowserApp) throws -> NSRunningApplication {
        if let running = runningApp(app.bundleID) { return running }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration)
        return try waitFor(timeout: 10, failure: SafariAutomationError.notRunning) {
            runningApp(app.bundleID).flatMap { $0.isFinishedLaunching ? $0 : nil }
        }
    }

    private static func runningApp(_ bundleID: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first { !$0.isTerminated }
    }

    private static func applicationElement(for app: NSRunningApplication) -> AXUIElement {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.5)
        return element
    }

    private static func fileMenuItems(of app: AXUIElement) -> [AXUIElement] {
        guard let menuBar = element(app, kAXMenuBarAttribute) else { return [] }
        let barItems = children(of: menuBar)
        guard barItems.count > 2, let fileMenu = children(of: barItems[2]).first else { return [] }
        return children(of: fileMenu).flatMap { item in
            [item] + children(of: item).flatMap { children(of: $0) }
        }
    }

    private static func isOpenLocation(_ item: AXUIElement) -> Bool {
        let commandKey = string(item, kAXMenuItemCmdCharAttribute)?.uppercased()
        let modifiers = number(item, kAXMenuItemCmdModifiersAttribute) ?? -1
        return commandKey == "L" && modifiers == 0
    }

    private static func focusedTextField(of app: AXUIElement, in window: AXUIElement) -> AXUIElement? {
        guard let focused = element(app, kAXFocusedUIElementAttribute),
              string(focused, kAXRoleAttribute) == kAXTextFieldRole,
              let owner = element(focused, kAXWindowAttribute),
              CFEqual(owner, window)
        else { return nil }
        return focused
    }

    private static func pressReturn(in pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            CGEvent(keyboardEventSource: source, virtualKey: returnKeyCode, keyDown: isDown)?.postToPid(pid)
        }
    }

    private static func windows(of app: AXUIElement) -> [AXUIElement] {
        attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    private static func number(_ element: AXUIElement, _ name: String) -> Int? {
        (attribute(element, name) as? NSNumber)?.intValue
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func waitFor<T>(timeout: TimeInterval, failure: Error, _ probe: () -> T?) throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let value = probe() { return value }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date() < deadline
        throw failure
    }
}
