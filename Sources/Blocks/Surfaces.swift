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
/// Blocks is an accessory app and the notch bar never activates it, so a click arriving while
/// Blocks is in the background would otherwise be spent activating the window instead of
/// reaching the close button. The bar's one control has to answer the first click.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    required init(rootView: Content) { super.init(rootView: rootView) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

@MainActor
final class Surfaces {
    private unowned let model: AppModel
    private var promptWindow: NSPanel?
    private var captureWindow: NSPanel?
    private var appBeforePrompt: NSRunningApplication?
    private var reviewWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var notchTimer: NSPanel?
    private var notchScreen: NSScreen?
    private var status: StatusItem!
    private var screenObserver: NSObjectProtocol?
    init(model: AppModel) {
        self.model = model
        status = StatusItem(model: model)
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.notchScreen = nil
                self?.refreshNotchTimer()
            }
        }
    }
    func refresh() {
        refreshNotchTimer()
        status.refresh()
    }
    /// True while the black bar is on screen, so the menu bar knows to keep its digits to
    /// itself: the clock is shown in one place at a time, never both.
    private(set) var notchTimerShowing = false
    private func refreshNotchTimer() {
        guard let screen = notchScreen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let inset = screen.safeAreaInsets.top
        // Closing the bar is a dismissal of this bar, not a change of setting: the clock falls
        // back to the menu bar for the rest of this session, and the menu keeps a way to call
        // the bar back for as long as the session is running.
        guard model.notchBarShowing, [.running, .paused, .finished].contains(model.state.phase), !model.sleeping, model.error == nil else {
            notchTimer?.orderOut(nil); notchScreen = nil; notchTimerShowing = false; return
        }
        notchScreen = screen
        notchTimerShowing = true
        // The notch's own bounds, taken from the areas AppKit leaves either side of it. The bar
        // is built around them so its empty middle lands on the hardware rather than near it.
        let notch: (left: CGFloat, right: CGFloat)?
        if inset > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, right.minX > left.maxX {
            notch = (left.maxX, right.minX)
        } else {
            notch = nil
        }
        let notchWidth = notch.map { $0.right - $0.left } ?? 0
        // Exactly the notch's height, so the bar's edges are the notch's edges. A screen without
        // a notch has no such height to borrow, so the bar takes the menu bar's instead and
        // covers it cleanly.
        let height = inset > 0 ? inset : max(24, screen.frame.maxY - screen.visibleFrame.maxY)
        let view = NotchTimerView(model: model, barHeight: height, notchWidth: notchWidth) { [weak model] in
            model?.setNotchBar(false)
        }
        let width = min(screen.frame.width, NotchTimerView.totalWidth(clock: view.trailing, notchWidth: notchWidth))
        if notchTimer == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.level = .statusBar; panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            // The close button is the one thing on the bar that answers the pointer; everything
            // behind it is the menu bar the bar is already covering, so nothing is lost by the
            // panel taking the clicks. It still never activates Blocks or takes the keyboard.
            panel.ignoresMouseEvents = false
            panel.isReleasedWhenClosed = false
            notchTimer = panel
        }
        // Flush with the physical top of the screen, above the menu bar rather than below it:
        // the panel sits at `.statusBar`, one level up from the menu bar, so the bar and the
        // notch meet with nothing between them. Horizontally it hangs off the notch's left edge
        // by exactly the left wing, which is what keeps the gap over the hardware while the two
        // wings are different widths.
        let x = notch.map { $0.left - NotchTimerView.leadingWing } ?? (screen.frame.midX - width / 2)
        let frame = NSRect(x: x, y: screen.frame.maxY - height, width: width, height: height)
        if notchTimer?.frame != frame || notchTimer?.isVisible == false {
            notchTimer?.contentView = FirstMouseHostingView(rootView: view)
            notchTimer?.setFrame(frame, display: true)
        }
        notchTimer?.orderFrontRegardless()
    }
    func prompt(_ kind: PromptKind) {
        promptWindow?.close()
        status.dismiss()
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
    /// The start shortcut begins a session while idle, or queues work during a session. A
    /// session still holding its offer to extend is written by the act of starting the next one.
    func startOrQueue() {
        guard model.error == nil else { return }
        switch model.state.phase {
        case .idle, .finished: prompt(.intent)
        case .running, .paused: prompt(.queue)
        case .checking: break // Legacy checkpoints are completed during migration.
        }
    }
    func capture() {
        guard model.error == nil else { return }
        if captureWindow?.isVisible == true { dismissCapture(); return }
        status.dismiss()
        appBeforePrompt = NSWorkspace.shared.frontmostApplication
        let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 516, height: 190), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = "Capture a distraction"
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
    /// Reports, reusable tasks, and archived thoughts share one review window.
    func review() {
        status.dismiss()
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
        status.dismiss()
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
}
