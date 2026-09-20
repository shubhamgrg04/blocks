import AppKit
import SwiftUI
import BlocksCore
import QuartzCore

/// Focus loss is not guaranteed when clicking the desktop, another menu-bar item, or a
/// nonactivating window. Observe mouse-down directly while a transient popup is presented.
@MainActor
final class PopupClickAway {
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var deactivateObserver: NSObjectProtocol?
    private var windows: () -> [NSWindow] = { [] }
    private var dismiss: (() -> Void)?

    func start(windows: @escaping () -> [NSWindow], dismiss: @escaping () -> Void) {
        stop()
        self.windows = windows
        self.dismiss = dismiss
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            MainActor.assumeIsolated { self?.handleLocalClick(event) }
            return event // The outside click still reaches the control the user chose.
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleExternalClick() }
        }
        deactivateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleExternalClick() }
        }
    }
    func handleLocalClick(_ event: NSEvent) {
        let roots = windows()
        var target = event.window
        // A menu opened by this interaction handles its own outside-click dismissal.
        if target?.level == .popUpMenu { return }
        while let window = target {
            if roots.contains(where: { $0 === window }) { return }
            target = window.parent
        }
        handleExternalClick()
    }
    func handleExternalClick() { dismiss?() }
    func stop() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let deactivateObserver { NotificationCenter.default.removeObserver(deactivateObserver) }
        localMonitor = nil
        globalMonitor = nil
        deactivateObserver = nil
        windows = { [] }
        dismiss = nil
    }
    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let deactivateObserver { NotificationCenter.default.removeObserver(deactivateObserver) }
    }
}

/// Blocks activates itself when it shows a prompt, so these panels are ordinary key/main
/// windows. A panel that cannot become main hands out its field editor unreliably, which is
/// the difference between a text field that is focused and one that must be clicked.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    var onFocusLost: (() -> Void)?
    var acceptingInput = true
    private var focusRevision = 0
    override func becomeKey() {
        focusRevision += 1
        super.becomeKey()
    }
    override func sendEvent(_ event: NSEvent) {
        guard acceptingInput else { return }
        super.sendEvent(event)
    }

    override func resignKey() {
        super.resignKey()
        let resignRevision = focusRevision
        // Allow AppKit to finish choosing the next key window. A child popover belongs
        // to this interaction; opening it must not dismiss the parent popup.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.focusRevision == resignRevision, self.acceptingInput, self.isVisible, !self.isKeyWindow else { return }
            var next = NSApp.keyWindow
            if next == nil && NSApp.isActive { return } // Native menu tracking.
            while let window = next {
                if window === self { return }
                next = window.parent
            }
            self.onFocusLost?()
        }
    }
}
/// Window-level motion includes dismissal, which SwiftUI's onDisappear cannot animate
/// once AppKit has removed the panel. Revisions prevent an old exit hiding a reopened island.
@MainActor
final class IslandMotion {
    private(set) var presented = false
    private(set) var targetFrame = NSRect.zero
    private var revision = 0
    private weak var currentWindow: NSWindow?
    private let reducedMotion: () -> Bool
    init(reducedMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) {
        self.reducedMotion = reducedMotion
    }
    func show(_ window: NSWindow, frame: NSRect) {
        guard currentWindow !== window || !presented || targetFrame != frame else { return }
        currentWindow = window
        revision += 1
        presented = true
        targetFrame = frame
        window.ignoresMouseEvents = false
        (window as? KeyPanel)?.acceptingInput = true
        let reduced = reducedMotion()
        if !window.isVisible {
            window.alphaValue = 0
            window.setFrame(reduced ? frame : frame.offsetBy(dx: 0, dy: 8), display: false)
        }
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduced ? 0.12 : 0.28
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
            window.animator().alphaValue = 1
            window.animator().setFrame(frame, display: true)
        }
    }
    func hide(_ window: NSWindow?) {
        guard let window, presented else { return }
        revision += 1
        let closingRevision = revision
        presented = false
        // An exiting island must not intercept a click or submit another Return.
        window.ignoresMouseEvents = true
        (window as? KeyPanel)?.acceptingInput = false
        let reduced = reducedMotion()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduced ? 0.10 : 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = 0
            if !reduced { window.animator().setFrame(targetFrame.offsetBy(dx: 0, dy: 6), display: true) }
        } completionHandler: { [weak self, weak window] in
            MainActor.assumeIsolated {
                guard let self, let window, self.revision == closingRevision, !self.presented else { return }
                window.orderOut(nil)
                window.alphaValue = 1
                window.setFrame(self.targetFrame, display: false)
            }
        }
    }
    func resize(_ window: NSWindow, frame: NSRect) {
        targetFrame = frame
        // Keep the top attached to the notch; only the lower edge expands.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reducedMotion() ? 0 : 0.22
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)
            window.animator().setFrame(frame, display: true)
        }
    }
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
    private let popupClickAway = PopupClickAway()
    private let promptMotion = IslandMotion()
    private let stripMotion = IslandMotion()
    private let notchMotion = IslandMotion()
    /// Both strips share one panel: they are never wanted at once, and one window means one
    /// place that knows where a strip goes and how it is dismissed.
    private var stripWindow: NSPanel?
    private var stripKind: StripKind?
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
    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }
    private func watchPopupClicks() {
        popupClickAway.start(windows: { [weak self] in
            guard let self else { return [] }
            return [self.stripMotion.presented ? self.stripWindow : nil,
                    self.promptMotion.presented ? self.promptWindow : nil].compactMap { $0 }
        }, dismiss: { [weak self] in self?.dismissPopupsAfterFocusLoss() })
    }
    /// Clicking away belongs to the newly chosen app/window. Never reactivate the app
    /// that originally summoned the popup, and never submit its unfinished input.
    private func dismissPopupsAfterFocusLoss() {
        popupClickAway.stop()
        appBeforePrompt = nil
        stripKind = nil
        stripMotion.hide(stripWindow)
        promptMotion.hide(promptWindow)
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
            notchMotion.hide(notchTimer); notchScreen = nil; notchTimerShowing = false; return
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
        if notchMotion.targetFrame != frame || !notchMotion.presented {
            notchTimer?.contentView = FirstMouseHostingView(rootView: view)
        }
        if let notchTimer { notchMotion.show(notchTimer, frame: frame) }
    }
    func prompt(_ kind: PromptKind) {
        promptWindow?.close()
        // A strip left open under a prompt would be two things asking at once. Dismissing it
        // first also hands the previous app back, so the prompt records the right one to return
        // to when it closes.
        if stripMotion.presented { dismissStrip() }
        status.dismiss()
        // Only a shortcut-summoned prompt interrupts another app; one opened from Blocks's own
        // menu or at a block boundary has nowhere to send you back to.
        if appBeforePrompt == nil, NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            appBeforePrompt = NSWorkspace.shared.frontmostApplication
        }
        let panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: 516, height: 230), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.onFocusLost = { [weak self] in self?.dismissPopupsAfterFocusLoss() }
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.title = "Blocks"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isReleasedWhenClosed = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let hosting = NSHostingView(rootView: PromptView(model: model, kind: kind) { [weak self] in
            self?.popupClickAway.stop()
            self?.promptMotion.hide(self?.promptWindow)
            self?.restorePreviousApp()
        })
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        panel.center()
        promptMotion.show(panel, frame: panel.frame)
        // Keystrokes are delivered to the active app, so a panel from an accessory app is
        // only typeable once Blocks itself is activated.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        promptWindow = panel
        watchPopupClicks()
    }
    /// The start shortcut opens the start strip when there is nothing to interrupt, and asks
    /// about the running session when there is. Reaching for "start something" mid-session is
    /// the moment the session stopped being the thing you were doing; the strip offers the two
    /// honest answers to that and does not offer a third. A session still holding its offer to
    /// extend is written by the act of starting the next one.
    func start() {
        guard model.error == nil else { return }
        switch model.state.phase {
        case .idle, .finished:
            if stripKind == .start, stripMotion.presented { dismissStrip(); return }
            showStrip(.start, height: StartStripView.height(rows: model.pendingTasks.count)) { model, close, resize in
                AnyView(StartStripView(model: model, close: close, resize: resize))
            }
        case .running, .paused:
            if stripKind == .running, stripMotion.presented { dismissStrip(); return }
            showStrip(.running, height: RunningStripView.height(reasoning: false)) { model, close, resize in
                AnyView(RunningStripView(model: model, close: close, resize: resize))
            }
        case .checking: break // Legacy checkpoints are completed during migration.
        }
    }
    /// Capturing is a strip under the notch bar rather than a panel in the middle of the
    /// screen. Writing a queued task down is meant to cost a couple of seconds and leave the
    /// work where it was, so it borrows the bar's own language — black, borderless, one line —
    /// and appears where the bar already has the eye.
    func capture() {
        guard model.error == nil else { return }
        if stripKind == .capture, stripMotion.presented { dismissStrip(); return }
        showStrip(.capture, height: CaptureStripView.height) { model, close, _ in
            AnyView(CaptureStripView(model: model, close: close))
        }
    }
    private enum StripKind { case start, capture, running }
    /// One way in for both strips: dismiss whatever is showing, hang the panel under the notch,
    /// and activate — a strip has to be typed into, which is the one way it differs from the
    /// bar above it.
    private func showStrip(_ kind: StripKind, height: CGFloat,
                           content: (AppModel, @escaping () -> Void, @escaping (CGFloat) -> Void) -> AnyView) {
        promptMotion.hide(promptWindow)
        status.dismiss()
        appBeforePrompt = NSWorkspace.shared.frontmostApplication
        let size = NSSize(width: StartStripView.width, height: height)
        let panel = stripWindow ?? {
            let fresh = KeyPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            fresh.onFocusLost = { [weak self] in self?.dismissPopupsAfterFocusLoss() }
            fresh.isOpaque = false
            fresh.backgroundColor = .clear
            // The shadow is what separates a black strip from a black desktop behind it.
            fresh.hasShadow = true
            fresh.hidesOnDeactivate = false
            fresh.isReleasedWhenClosed = false
            fresh.level = .screenSaver
            fresh.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            stripWindow = fresh
            return fresh
        }()
        stripKind = kind
        // Only the callbacks the panel outlives are weak; the builder itself runs right here.
        panel.contentView = NSHostingView(rootView: content(
            model,
            { [weak self] in self?.dismissStrip() },
            { [weak self] wanted in self?.resizeStrip(to: wanted) }))
        let frame = stripFrame(size: size)
        // Order into the current space before activating: a fullScreenAuxiliary panel that is
        // already on screen keeps Blocks's activation from switching away from a fullscreen space.
        stripMotion.show(panel, frame: frame)
        watchPopupClicks()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
    /// The start strip grows and shrinks as its list filters. It grows *downward*: the top edge
    /// is where it hangs from the notch, and a strip that moved up the screen as you typed
    /// would be a strip you had to follow.
    private func resizeStrip(to height: CGFloat) {
        guard let panel = stripWindow, stripMotion.presented, stripMotion.targetFrame.height != height else { return }
        var frame = stripMotion.targetFrame
        frame.origin.y = frame.maxY - height
        frame.size.height = height
        stripMotion.resize(panel, frame: frame)
        // A borderless panel's shadow is computed from what it drew at its old size.
        panel.invalidateShadow()
    }
    /// Directly under the notch, on the screen the bar is on: the strip reads as something the
    /// bar dropped down rather than as a window that happens to be near the top. The gap it
    /// leaves is the bar's height whether or not the bar is actually showing, so the shortcut
    /// puts the strip in the same place every time.
    private func stripFrame(size: NSSize) -> NSRect {
        guard let screen = notchScreen ?? NSScreen.main ?? NSScreen.screens.first else {
            return NSRect(origin: .zero, size: size)
        }
        let inset = screen.safeAreaInsets.top
        let barHeight = inset > 0 ? inset : max(24, screen.frame.maxY - screen.visibleFrame.maxY)
        let centre: CGFloat
        if inset > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, right.minX > left.maxX {
            centre = (left.maxX + right.minX) / 2
        } else {
            centre = screen.frame.midX
        }
        let gap: CGFloat = 8
        return NSRect(x: (centre - size.width / 2).rounded(),
                      y: screen.frame.maxY - barHeight - gap - size.height,
                      width: size.width, height: size.height)
    }
    /// A strip summoned by a shortcut has to leave the user in the app it interrupted.
    private func dismissStrip() {
        popupClickAway.stop()
        stripMotion.hide(stripWindow)
        stripKind = nil
        restorePreviousApp()
    }
    private func restorePreviousApp() {
        if let previous = appBeforePrompt, previous.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previous.activate()
        }
        appBeforePrompt = nil
    }
    /// Reports and To do share one review window.
    func review() {
        status.dismiss()
        if reviewWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = .black
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
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = .black
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
