import AppKit
import Carbon
import KnurlinkCore
import os
import SwiftUI

private struct IncomingLink {
    let url: URL
    let source: String?
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = AppModel()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
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
        installStatusItem()
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
        pendingLinks.append(contentsOf: urls
            .filter { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
            .map { IncomingLink(url: $0, source: source) })
        processNextURL()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }

    private func processNextURL() {
        guard picker == nil, !pendingLinks.isEmpty else { return }
        let link = pendingLinks.removeFirst()
        let url = link.url
        model.refresh()

        if let option = model.routedOption(for: url, source: link.source) {
            Launcher.open(url, with: option)
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
            if let result {
                if let domain = result.rememberedDomain {
                    self.model.setRule(domain: domain, target: result.option.target)
                }
                Launcher.open(url, with: result.option)
            }
            self.processNextURL()
        }
        picker = controller
        controller.show()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "knURLink")
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit knURLink", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
            window.title = "knURLink"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        model.refresh()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
