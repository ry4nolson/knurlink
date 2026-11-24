import AppKit
import Carbon
import Combine
import KnurlinkCore
import os
import SwiftUI

private struct IncomingLink {
    let url: URL
    let source: String?
    let forcesPicker: Bool
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem?
    private let updater = UpdateChecker()
    private let router = SettingsRouter()
    private var settingsWindow: NSWindow?
    private var expectsActivation = false
    private var settingsParkedBelow: Int?
    private var settingsIsParked = false
    private var updateMenuItem: NSMenuItem?
    private var updateObserver: AnyCancellable?
    private var updateTimer: Timer?
    private var picker: PickerController?
    private let logger = Logger(subsystem: "dev.knurlink.Knurlink", category: "routing")
    private var pendingLinks: [IncomingLink] = []
    private var hasReceivedURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:replyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        installStatusItem()
        scheduleUpdateChecks()
        let launchEvent = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = launchEvent?.eventID == AEEventID(kAEOpenApplication)
            && launchEvent?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem)
        guard !launchedAtLogin else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.hasReceivedURL else { return }
            self.showSettings()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        enqueue(urls, source: nil)
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string)
        else {
            logger.error("Received a link event without a usable URL")
            return
        }
        let senderPID = event.attributeDescriptor(forKeyword: AEKeyword(keySenderPIDAttr))?.int32Value
        let source = senderPID.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }
        logger.notice("Link received from \(source ?? "unknown", privacy: .public)")
        enqueue([url], source: source)
    }

    private func enqueue(_ urls: [URL], source: String?) {
        hasReceivedURL = true
        let forcesPicker = NSEvent.modifierFlags.contains(.option)
        pendingLinks.append(contentsOf: urls
            .filter { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
            .map { IncomingLink(url: $0, source: source, forcesPicker: forcesPicker) })
        processNextURL()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        defer { expectsActivation = false }
        guard !expectsActivation,
              let window = settingsWindow,
              window.isVisible,
              !isClickingInside(window)
        else { return }
        settingsParkedBelow = windowNumber(inFrontOf: window)
        settingsIsParked = true
        window.orderOut(nil)
    }

    func applicationDidResignActive(_ notification: Notification) {
        guard settingsIsParked, let window = settingsWindow else { return }
        settingsIsParked = false
        if let above = settingsParkedBelow {
            window.order(.below, relativeTo: above)
        } else {
            window.orderFront(nil)
        }
    }

    private func isClickingInside(_ window: NSWindow) -> Bool {
        NSEvent.pressedMouseButtons != 0 && window.frame.contains(NSEvent.mouseLocation)
    }

    private func windowNumber(inFrontOf window: NSWindow) -> Int? {
        let options: CGWindowListOption = [.optionOnScreenAboveWindow, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, CGWindowID(window.windowNumber)) as? [[String: Any]] else { return nil }
        return windows
            .last { ($0[kCGWindowLayer as String] as? Int) == 0 }
            .flatMap { $0[kCGWindowNumber as String] as? Int }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === settingsWindow { settingsWindow = nil }
    }

    private func processNextURL() {
        guard picker == nil, !pendingLinks.isEmpty else { return }
        let link = pendingLinks.removeFirst()
        let url = link.url
        defer { model.refreshAppsInBackground() }

        if !link.forcesPicker, let route = model.route(for: url, source: link.source) {
            Launcher.open(url, with: route.option, privately: route.privately)
            processNextURL()
            return
        }

        let options = model.visibleOptions
        guard !options.isEmpty else {
            pendingLinks.removeAll()
            showSettings()
            return
        }

        let controller = PickerController(
            url: url,
            options: options,
            suggestedDomain: url.host.map(DomainMatcher.suggestedDomain(forHost:))
        ) { [weak self] result in
            guard let self else { return }
            self.picker = nil
            if result == nil, self.pendingLinks.isEmpty {
                NSApp.deactivate()
            }
            if let result {
                if let domain = result.rememberedDomain {
                    self.model.setRule(domain: domain, target: result.option.target, privately: result.privately)
                }
                Launcher.open(url, with: result.option, privately: result.privately)
            }
            self.processNextURL()
        }
        picker = controller
        controller.show()
    }

    private func installMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quit knURLink", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let mainMenu = NSMenu()
        for menu in [appMenu, editMenu] {
            let item = NSMenuItem()
            item.submenu = menu
            mainMenu.addItem(item)
        }
        NSApp.mainMenu = mainMenu
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "knURLink")
        let menu = NSMenu()
        let update = menu.addItem(withTitle: "", action: #selector(openUpdate), keyEquivalent: "")
        update.target = self
        update.isHidden = true
        updateMenuItem = update
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "About knURLink", action: #selector(showAbout), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit knURLink", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    private func scheduleUpdateChecks() {
        updateObserver = updater.$state.sink { [weak self] state in
            guard let item = self?.updateMenuItem else { return }
            if case let .available(release) = state {
                item.title = "Update to \(release.displayVersion)…"
                item.isHidden = false
            } else {
                item.isHidden = true
            }
        }
        checkForUpdatesIfEnabled()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForUpdatesIfEnabled() }
        }
    }

    private func checkForUpdatesIfEnabled() {
        guard model.config.checksForUpdates else { return }
        Task { await updater.check() }
    }

    @objc private func openUpdate() {
        guard let release = updater.availableRelease else { return }
        NSWorkspace.shared.open(release.downloadURL)
    }

    @objc private func showAbout() {
        router.section = .about
        showSettings()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: model, updater: updater, router: router))
            hosting.sceneBridgingOptions = [.toolbars, .title]
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setContentSize(NSSize(width: 1000, height: 640))
            window.center()
            window.setFrameAutosaveName("Settings")
            settingsWindow = window
        }
        model.refresh()
        settingsIsParked = false
        expectsActivation = !NSApp.isActive
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
