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
    /// Visibility handoffs cannot leave a fading bar beside the restored menu item.
    func hideImmediately(_ window: NSWindow?) {
        revision += 1
        presented = false
        window?.ignoresMouseEvents = true
        window?.orderOut(nil)
    }
    func move(_ window: NSWindow, frame: NSRect) {
        targetFrame = frame
        window.setFrame(frame, display: true)
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
/// reaching its controls. The bar has to answer the first click.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    required init(rootView: Content) { super.init(rootView: rootView) }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
}

/// Store proportional positions per display so resolution and arrangement changes keep
/// the whole bar reachable. No saved position means flush with the top, centered.
final class FloatingBarPlacement {
    private let defaults: UserDefaults?
    private var positions: [String: [Double]]
    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        positions = defaults?.dictionary(forKey: "floatingBarPositions") as? [String: [Double]] ?? [:]
    }
    static func clamped(_ frame: NSRect, to screen: NSRect) -> NSRect {
        var frame = frame
        frame.origin.x = min(max(frame.minX, screen.minX), max(screen.minX, screen.maxX - frame.width))
        frame.origin.y = min(max(frame.minY, screen.minY), max(screen.minY, screen.maxY - frame.height))
        return frame
    }
    func frame(display: String, screen: NSRect, size: NSSize) -> NSRect {
        let position = positions[display] ?? [0.5, 1]
        let x = position.count == 2 && position[0].isFinite ? position[0] : 0.5
        let y = position.count == 2 && position[1].isFinite ? position[1] : 1
        return Self.clamped(NSRect(x: screen.minX + max(0, screen.width - size.width) * x,
                                   y: screen.minY + max(0, screen.height - size.height) * y,
                                   width: size.width, height: size.height), to: screen)
    }
    func save(frame: NSRect, display: String, screen: NSRect) {
        let frame = Self.clamped(frame, to: screen)
        positions[display] = [(frame.minX - screen.minX) / max(1, screen.width - frame.width),
                              (frame.minY - screen.minY) / max(1, screen.height - frame.height)]
        defaults?.set(positions, forKey: "floatingBarPositions")
    }
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
    private var draggingBar = false
    private let floatingPlacement = FloatingBarPlacement(
        defaults: ProcessInfo.processInfo.environment["BLOCKS_TEST_DATA_DIRECTORY"] == nil ? .standard : nil)
    static func menuBarHeight(on screen: NSScreen) -> CGFloat {
        max(NSStatusBar.system.thickness, screen.frame.maxY - screen.visibleFrame.maxY)
    }
    private func displayKey(_ screen: NSScreen) -> String {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "main"
    }
    private var status: StatusItem!
    private var screenObserver: NSObjectProtocol?
    init(model: AppModel) {
        self.model = model
        status = StatusItem(model: model)
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.notchScreen = nil
                self?.refresh()
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
                    self.promptMotion.presented ? self.promptWindow : nil,
                    self.notchTimerShowing ? self.notchTimer : nil].compactMap { $0 }
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
    /// The bar and menu item are mutually exclusive entry points to the same popup.
    private(set) var notchTimerShowing = false
    var menuItemShowing: Bool { status.isVisible }
    private func refreshNotchTimer() {
        guard !draggingBar else { return }
        guard let screen = notchScreen ?? NSScreen.main ?? NSScreen.screens.first else {
            hideNotchTimer()
            return
        }
        let inset = screen.safeAreaInsets.top
        // Closing the bar is a dismissal of this bar, not a change of setting: the clock falls
        // back to the menu bar for the rest of this session, and the menu keeps a way to call
        // the bar back for as long as the session is running.
        guard model.notchBarShowing else {
            hideNotchTimer(); return
        }
        notchScreen = screen
        notchTimerShowing = true
        status.setVisible(false)
        // The notch's own bounds, taken from the areas AppKit leaves either side of it. The bar
        // is built around them so its empty middle lands on the hardware rather than near it.
        let notch: (left: CGFloat, right: CGFloat)?
        if inset > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, right.minX > left.maxX {
            notch = (left.maxX, right.minX)
        } else {
            notch = nil
        }
        let notchWidth = notch.map { $0.right - $0.left } ?? 0
        let height = notch != nil ? inset : Self.menuBarHeight(on: screen)
        let view = NotchTimerView(model: model, barHeight: height, notchWidth: notchWidth,
                                  dismiss: { [weak model] in model?.setNotchBar(false) },
                                  openPopup: { [weak self] in self?.openMenuFromBar() },
                                  beginDrag: { [weak self] in self?.beginMovingBar() },
                                  moveDrag: { [weak self] point in self?.moveBar(to: point) },
                                  endDrag: { [weak self] in self?.finishMovingBar() })
        let width = min(screen.frame.width, NotchTimerView.totalWidth(clock: view.trailing, notchWidth: notchWidth))
        if notchTimer == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.level = .statusBar; panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            // Controls answer directly; the rest of the bar opens the session popup.
            // Only opening the popup activates Blocks to accept keyboard input.
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
        let frame = notch != nil
            ? NSRect(x: x, y: screen.frame.maxY - height, width: width, height: height)
            : floatingPlacement.frame(display: displayKey(screen), screen: screen.frame,
                                      size: NSSize(width: width, height: height))
        notchTimer?.hasShadow = notch == nil
        if notchMotion.targetFrame != frame || !notchMotion.presented {
            status.dismiss()
            if let hosting = notchTimer?.contentView as? FirstMouseHostingView<NotchTimerView> {
                hosting.rootView = view
            } else {
                notchTimer?.contentView = FirstMouseHostingView(rootView: view)
            }
        }
        if let notchTimer { notchMotion.show(notchTimer, frame: frame) }
    }
    private func beginMovingBar() {
        draggingBar = true
        status.dismiss()
        dismissPopupsAfterFocusLoss()
    }
    private func moveBar(to origin: NSPoint) {
        guard draggingBar, let panel = notchTimer, let screen = notchScreen else { return }
        let frame = FloatingBarPlacement.clamped(NSRect(origin: origin, size: panel.frame.size), to: screen.frame)
        notchMotion.move(panel, frame: frame)
    }
    private func finishMovingBar() {
        if let panel = notchTimer, let screen = notchScreen {
            floatingPlacement.save(frame: panel.frame, display: displayKey(screen), screen: screen.frame)
        }
        draggingBar = false
        refresh()
    }
    private func hideNotchTimer() {
        if notchTimerShowing { status.dismiss() }
        notchMotion.hideImmediately(notchTimer)
        notchScreen = nil
        notchTimerShowing = false
        status.setVisible(true)
    }
    private func openMenuFromBar() {
        guard notchTimerShowing, let anchor = notchTimer?.contentView else { return }
        dismissPopupsAfterFocusLoss()
        status.toggle(relativeTo: anchor)
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
            showStrip(.start, height: StartStripView.height(rows: model.pendingTasks.count + (model.state.phase == .finished ? 1 : 0))) { model, close, resize in
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
        let frame = stripFrame(size: NSSize(width: stripMotion.targetFrame.width, height: height))
        stripMotion.resize(panel, frame: frame)
        // A borderless panel's shadow is computed from what it drew at its old size.
        panel.invalidateShadow()
    }
    /// Directly under the notch, on the screen the bar is on: the strip reads as something the
    /// bar dropped down rather than as a window that happens to be near the top. The gap it
    /// leaves clears the visible bar, including a bar moved by the user.
    /// With no bar showing, it falls back to the area directly below the menu bar.
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
        let anchor = notchTimerShowing ? notchMotion.targetFrame
            : NSRect(x: centre, y: screen.frame.maxY - barHeight, width: 0, height: barHeight)
        let below = anchor.minY - gap - size.height
        let y = below >= screen.visibleFrame.minY ? below : anchor.maxY + gap
        return FloatingBarPlacement.clamped(
            NSRect(x: (anchor.midX - size.width / 2).rounded(), y: y, width: size.width, height: size.height),
            to: screen.visibleFrame)
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
