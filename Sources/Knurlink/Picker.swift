import AppKit
import SwiftUI

struct PickerResult {
    let option: BrowserOption
    let rememberedDomain: String?
    let privately: Bool
}

final class PickerState: ObservableObject {
    let url: URL
    let options: [BrowserOption]
    let suggestedDomain: String?
    @Published var selection = 0
    @Published var remember = false
    @Published var wantsPrivate = NSEvent.modifierFlags.contains(.shift)

    init(url: URL, options: [BrowserOption], suggestedDomain: String?) {
        self.url = url
        self.options = options
        self.suggestedDomain = suggestedDomain
    }
}

enum PickerLayout {
    static let bubbleDiameter: CGFloat = 84
    static let bubbleSpacing: CGFloat = 104
    static let minimumRadius: CGFloat = 140
    static let margin: CGFloat = 16

    static func radius(for count: Int) -> CGFloat {
        max(minimumRadius, CGFloat(count) * bubbleSpacing / (2 * .pi))
    }

    static func side(for count: Int) -> CGFloat {
        2 * (radius(for: count) + bubbleDiameter / 2 + margin)
    }

    static func hubDiameter(for count: Int) -> CGFloat {
        min(220, 2 * radius(for: count) - bubbleDiameter - 28)
    }

    static func offset(for index: Int, of count: Int, radius: CGFloat) -> CGSize {
        let angle = -CGFloat.pi / 2 + 2 * .pi * CGFloat(index) / CGFloat(max(count, 1))
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }
}

struct PickerView: View {
    @ObservedObject var state: PickerState
    let choose: (Int) -> Void
    let cancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    private var count: Int { state.options.count }

    var body: some View {
        ZStack {
            ForEach(Array(state.options.enumerated()), id: \.element.id) { index, option in
                let offset = PickerLayout.offset(
                    for: index,
                    of: count,
                    radius: expanded ? PickerLayout.radius(for: count) : 0
                )
                PickerBubble(
                    option: option,
                    index: index,
                    isSelected: index == state.selection,
                    wantsPrivate: state.wantsPrivate
                )
                    .offset(offset)
                    .opacity(expanded ? 1 : 0)
                    .onTapGesture { choose(index) }
                    .onHover { hovering in
                        if hovering { state.selection = index }
                    }
            }
            hub
        }
        .frame(width: PickerLayout.side(for: count), height: PickerLayout.side(for: count))
        .onAppear {
            guard !reduceMotion else {
                expanded = true
                return
            }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                expanded = true
            }
        }
    }

    @ViewBuilder
    private var selectionCaption: some View {
        let option = state.options[state.selection]
        if state.wantsPrivate, option.supportsPrivateWindow {
            Label("\(option.title), private", systemImage: "eyeglasses")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } else {
            Text(option.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var hub: some View {
        let diameter = PickerLayout.hubDiameter(for: count)
        return VStack(spacing: 6) {
            Text(state.url.host ?? state.url.absoluteString)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            selectionCaption
            if let domain = state.suggestedDomain {
                Toggle("Always for \(domain)", isOn: $state.remember)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel")
        }
        .padding(.horizontal, 18)
        .frame(width: diameter, height: diameter)
        .background(
            Circle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 3)
        )
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.1)))
    }
}

private struct PickerBubble: View {
    let option: BrowserOption
    let index: Int
    let isSelected: Bool
    let wantsPrivate: Bool

    private var showsPrivate: Bool { wantsPrivate && option.supportsPrivateWindow }

    var body: some View {
        VStack(spacing: 2) {
            Image(nsImage: option.app.icon)
                .resizable()
                .frame(width: 38, height: 38)
            Text(option.profile?.name ?? option.app.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 10)
        }
        .frame(width: PickerLayout.bubbleDiameter, height: PickerLayout.bubbleDiameter)
        .background(
            Circle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        )
        .overlay(
            Circle().strokeBorder(
                isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                lineWidth: isSelected ? 3 : 1
            )
        )
        .overlay(alignment: .topTrailing) {
            if index < 9 {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(isSelected ? Color.accentColor : Color.gray))
                    .offset(x: -4, y: 4)
            }
        }
        .overlay(alignment: .bottom) {
            if showsPrivate {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 14)
                    .background(Capsule().fill(Color.accentColor))
                    .offset(y: 5)
            }
        }
        .opacity(wantsPrivate && !option.supportsPrivateWindow ? 0.4 : 1)
        .scaleEffect(isSelected ? 1.1 : 1)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsPrivate ? "\(option.title), private window" : option.title)
        .accessibilityAddTraits(.isButton)
    }
}

private final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class PickerController {
    private enum Key {
        static let escape: UInt16 = 53
        static let returnKey: UInt16 = 36
        static let enter: UInt16 = 76
        static let down: UInt16 = 125
        static let up: UInt16 = 126
    }

    private let state: PickerState
    private let completion: (PickerResult?) -> Void
    private var panel: PickerPanel?
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    init(url: URL, options: [BrowserOption], suggestedDomain: String?, completion: @escaping (PickerResult?) -> Void) {
        state = PickerState(url: url, options: options, suggestedDomain: suggestedDomain)
        self.completion = completion
    }

    func show() {
        let hosting = NSHostingController(rootView: PickerView(
            state: state,
            choose: { [weak self] index in self?.finish(choosing: index) },
            cancel: { [weak self] in self?.finish(choosing: nil) }
        ))
        let panel = PickerPanel(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentViewController = hosting
        let side = PickerLayout.side(for: state.options.count)
        panel.setContentSize(NSSize(width: side, height: side))
        position(panel)
        self.panel = panel

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.state.wantsPrivate = event.modifierFlags.contains(.shift)
            return event
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.finish(choosing: nil)
            }
        }
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else {
            panel.center()
            return
        }
        let size = panel.frame.size
        let x = min(max(mouse.x - size.width / 2, visible.minX), visible.maxX - size.width)
        let y = min(max(mouse.y - size.height / 2, visible.minY), visible.maxY - size.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func handle(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case Key.escape:
            finish(choosing: nil)
        case Key.returnKey, Key.enter:
            finish(choosing: state.selection)
        case Key.down:
            state.selection = min(state.selection + 1, state.options.count - 1)
        case Key.up:
            state.selection = max(state.selection - 1, 0)
        default:
            guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  let characters = event.characters(byApplyingModifiers: [])?.lowercased()
            else { return false }
            if characters == "a", state.suggestedDomain != nil {
                state.remember.toggle()
            } else if let number = Int(characters), (1...min(9, state.options.count)).contains(number) {
                finish(choosing: number - 1)
            } else {
                return false
            }
        }
        return true
    }

    private func finish(choosing index: Int?) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        if let flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
        }
        flagsMonitor = nil
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
        resignObserver = nil
        guard let panel else { return }
        self.panel = nil
        panel.close()
        guard let index, state.options.indices.contains(index) else {
            completion(nil)
            return
        }
        let option = state.options[index]
        completion(PickerResult(
            option: option,
            rememberedDomain: state.remember ? state.suggestedDomain : nil,
            privately: NSEvent.modifierFlags.contains(.shift) && option.supportsPrivateWindow
        ))
    }
}
