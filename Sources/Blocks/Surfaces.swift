import AppKit
import SwiftUI
import BlocksCore

/// Blocks activates itself when it shows a prompt, so these panels are ordinary key/main
/// windows. A panel that cannot become main hands out its field editor unreliably, which is
/// the difference between a text field that is focused and one that must be clicked.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
final class AmbientWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
final class TakeoverWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class Surfaces {
    private unowned let model: AppModel
    private var promptWindow: NSPanel?
    private var captureWindow: NSPanel?
    private var appBeforePrompt: NSRunningApplication?
    private var reviewWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var takeover: NSWindow?
    private var ambient: [NSWindow] = []
    private var lastPhase: Phase?
    private var screenObserver: NSObjectProtocol?
    init(model: AppModel) {
        self.model = model
        rebuildAmbient()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rebuildAmbient()
                if let screen = NSScreen.main { self?.takeover?.setFrame(screen.frame, display: true) }
            }
        }
    }
    func refresh() {
        let phase = model.state.phase
        if phase != lastPhase {
            lastPhase = phase
            if phase == .checking {
                promptWindow?.orderOut(nil)
                showTakeover()
            } else { takeover?.orderOut(nil) }
        }
        for window in ambient {
            if [.running, .paused].contains(phase) && model.error == nil { window.orderFrontRegardless() }
            else { window.orderOut(nil) }
        }
    }
    func prompt(_ kind: PromptKind) {
        promptWindow?.close()
        // Only a shortcut-summoned prompt interrupts another app; one opened from Blocks's own
        // menu or at a block boundary has nowhere to send you back to.
        if appBeforePrompt == nil, NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            appBeforePrompt = NSWorkspace.shared.frontmostApplication
        }
        let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 516, height: 230), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Blocks"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let hosting = NSHostingView(rootView: PromptView(model: model, kind: kind) { [weak self] in
            self?.promptWindow?.orderOut(nil)
            self?.restorePreviousApp()
        })
        panel.contentView = hosting
        // The intent prompt grows by however many intents are queued, so the panel takes its
        // size from the content rather than a constant that would clip the list.
        panel.setContentSize(hosting.fittingSize)
        panel.center()
        panel.orderFrontRegardless()
        // Keystrokes are delivered to the active app, so a panel from an accessory app is
        // only typeable once Blocks itself is activated.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        promptWindow = panel
    }
    /// The start shortcut means something different in each phase: begin a block, add to the
    /// queue, or get the honesty check out of the way — which is what is actually blocking you.
    func startOrQueue() {
        guard model.error == nil else { return }
        switch model.state.phase {
        case .idle: prompt(.intent)
        case .running, .paused: prompt(.queue)
        case .checking: showTakeover()
        }
    }
    func capture() {
        guard model.error == nil else { return }
        if captureWindow?.isVisible == true { dismissCapture(); return }
        appBeforePrompt = NSWorkspace.shared.frontmostApplication
        let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 516, height: 190), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = "Park a thought"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let hosting = NSHostingView(rootView: PromptView(model: model, kind: .capture) { [weak self] in self?.dismissCapture() })
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        panel.center()
        // Order into the current space before activating: a fullScreenAuxiliary panel that is
        // already on screen keeps Blocks's activation from switching away from a fullscreen space.
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        captureWindow = panel
    }
    /// A prompt summoned by a shortcut has to leave the user in the app it interrupted.
    private func dismissCapture() {
        captureWindow?.orderOut(nil)
        restorePreviousApp()
    }
    private func restorePreviousApp() {
        if let previous = appBeforePrompt, previous.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previous.activate()
        }
        appBeforePrompt = nil
    }
    func showTakeover() {
        guard model.state.phase == .checking, let screen = NSScreen.main else { return }
        if takeover == nil {
            let window = TakeoverWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: TakeoverView(model: model))
            takeover = window
        }
        takeover?.setFrame(screen.frame, display: true)
        NSApp.activate(ignoringOtherApps: true)
        takeover?.makeKeyAndOrderFront(nil)
    }
    /// No longer only history: the live queue and parked list are here too, with everything
    /// finished on a second tab. Named for what it is rather than what it used to be.
    func review() {
        if reviewWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.minSize = NSSize(width: 680, height: 580)
            window.title = "Blocks · Review"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ReviewView(model: model)); window.center()
            reviewWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); reviewWindow?.makeKeyAndOrderFront(nil)
    }
    /// SwiftUI's Settings scene only *orders* its window forward, which is invisible in an
    /// accessory app that is not frontmost. Owning the window lets Blocks activate first, and
    /// guarantees the window is key so the shortcut recorder receives key events.
    func settings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 600), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.titlebarAppearsTransparent = true
            window.title = "Blocks · Settings"; window.isReleasedWhenClosed = false
            let hosting = NSHostingView(rootView: SettingsView(model: model))
            window.contentView = hosting
            window.setContentSize(hosting.fittingSize)
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true); settingsWindow?.makeKeyAndOrderFront(nil)
    }
    private func rebuildAmbient() {
        ambient.forEach { $0.close() }; ambient = []
        for screen in NSScreen.screens {
            let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            let left = screen.auxiliaryTopLeftArea ?? .zero
            let right = screen.auxiliaryTopRightArea ?? .zero
            let notchWidth = right.minX - left.maxX
            let notched = CGDisplayIsBuiltin(displayID) != 0 && screen.safeAreaInsets.top > 0
                && left.width > 0 && right.width > 0 && notchWidth > 0
            // Inset each end to align visually with the flat bottom inside the notch’s curved corners.
            let bottomInset = min(8.0, max(0, notchWidth / 4))
            let frame = notched
                ? NSRect(x: left.maxX + bottomInset, y: screen.frame.maxY - screen.safeAreaInsets.top - 3, width: notchWidth - 2 * bottomInset, height: 3)
                : NSRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.frame.width, height: 3)
            let window = AmbientWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: AmbientView(model: model, notch: notched))
            ambient.append(window)
        }
        refresh()
    }
}

struct AmbientView: View {
    @ObservedObject var model: AppModel
    let notch: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var warning: Bool { model.state.phase == .running && model.state.remaining <= 30 }
    private var fraction: CGFloat { CGFloat(max(0, min(1, model.state.remaining / max(1, model.state.block?.plannedSeconds ?? 1)))) }
    private var color: Color { model.state.phase == .paused || model.sleeping ? .gray : warning ? .orange : Studio.accent }
    var body: some View {
        TimelineView(.animation(minimumInterval: warning && !reduceMotion ? 0.05 : 1, paused: !warning || reduceMotion)) { context in
            let opacity = warning && !reduceMotion ? 0.65 + 0.35 * sin(context.date.timeIntervalSinceReferenceDate * .pi * 2) : 1
            GeometryReader { geometry in
                if notch {
                    ZStack {
                        Capsule().fill(color.opacity(warning ? opacity : 0.2))
                        Capsule().fill(color)
                            .frame(width: geometry.size.width * fraction)
                            .opacity(opacity)
                    }
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: fraction)
                } else {
                    ZStack(alignment: .leading) {
                        Rectangle().fill(color.opacity(warning ? opacity : 0.2))
                        Rectangle().fill(color).frame(width: geometry.size.width * fraction).opacity(opacity)
                    }
                }
            }
        }.accessibilityHidden(true)
    }
}
