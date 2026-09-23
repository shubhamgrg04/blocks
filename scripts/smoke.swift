import AppKit
import BlocksCore
import SwiftUI

@MainActor final class SilentCompletionAudio: CompletionAudioPlaying {
    var played: [CompletionSound] = []
    var stops = 0
    func play(_ option: CompletionSound) { played.append(option) }
    func stop() { stops += 1 }
}

/// Uses only BLOCKS_TEST_DATA_DIRECTORY; never opens or changes the owner's data.
@main enum Smoke {
    @MainActor static func checkThemes() throws {
        let model = AppModel(completionAudio: SilentCompletionAudio())
        model.start("Session survives appearance changes")
        let sessionID = model.state.block?.id
        let remaining = model.state.remaining
        func field(in view: NSView) -> PromptTextField? {
            if let field = view as? PromptTextField { return field }
            return view.subviews.lazy.compactMap { field(in: $0) }.first
        }
        let capture = NSHostingView(rootView: CaptureStripView(model: model, close: {}).themed(model: model))
        let start = NSHostingView(rootView: StartStripView(model: model, close: {}).themed(model: model))
        let hosts: [NSView] = [capture, start]
        let windows = hosts.map { host in
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 82),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            return window
        }
        defer { for window in windows { window.contentView = nil; window.close() } }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        let fields = hosts.map { field(in: $0)! }
        for input in fields {
            input.stringValue = "Keep this draft"
            (input.delegate as! FocusedTextField.Coordinator).controlTextDidChange(
                Notification(name: NSControl.textDidChangeNotification, object: input))
        }
        for theme in AppTheme.allCases + [.ocean, .midnight] {
            var prefs = model.state.preferences
            prefs.theme = theme
            model.setPreferences(prefs)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
            let palette = StudioPalette(theme)
            for (host, input) in zip(hosts, fields) {
                precondition(field(in: host) === input, "Theme changes must preserve field identity")
                precondition(input.stringValue == "Keep this draft")
                precondition(input.textColor == NSColor(palette.ink), "Native text must update with the theme")
                let placeholder = input.placeholderAttributedString!
                precondition(placeholder.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor == NSColor(palette.muted))
            }
            precondition(model.state.block?.id == sessionID && model.state.remaining == remaining)
            precondition(model.error == nil)
            precondition(AppModel().state.preferences.theme == theme, "Theme must survive relaunch")
        }
        (fields[0].delegate as! FocusedTextField.Coordinator).submit(fields[0])
        precondition(model.pendingTasks.contains { $0.title == "Keep this draft" })
        precondition(model.state.block?.id == sessionID)
        print("PASS: live theme switching preserves both popup drafts and the session, updates native text and placeholders, persists, and still submits correctly")
    }

    @MainActor static func main() throws {
        precondition(ProcessInfo.processInfo.environment["BLOCKS_TEST_DATA_DIRECTORY"] != nil)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        if ProcessInfo.processInfo.environment["BLOCKS_THEME_CHECKS_ONLY"] == "1" {
            try checkThemes()
            return
        }
        // Decode every actual tone through the playback API without making the test audible.
        var toneData = Set<Data>()
        for option in CompletionSound.allCases {
            let data = option.wavData()
            guard let sound = NSSound(data: data) else { preconditionFailure("Invalid WAV: \(option)") }
            precondition(sound.duration > 0.2 && sound.duration < 1.2)
            precondition(toneData.insert(data).inserted)
            let pcm = Array(data.dropFirst(44))
            let samples = stride(from: 0, to: pcm.count, by: 2).map {
                Int(Int16(bitPattern: UInt16(pcm[$0]) | UInt16(pcm[$0 + 1]) << 8))
            }
            precondition(samples.first == 0 && samples.last == 0)
            precondition(samples.map { abs($0) }.max()! < 11_000)
        }
        // Default geometry and remembered placement survive display resizing/rearrangement.
        let placementSuite = "Blocks-placement-smoke-" + UUID().uuidString
        let placementDefaults = UserDefaults(suiteName: placementSuite)!
        defer { placementDefaults.removePersistentDomain(forName: placementSuite) }
        let placement = FloatingBarPlacement(defaults: placementDefaults)
        let display = NSRect(x: -1920, y: 100, width: 1920, height: 1080)
        let barSize = NSSize(width: 320, height: 24)
        let initial = placement.frame(display: "external", screen: display, size: barSize)
        precondition(initial.midX == display.midX && initial.maxY == display.maxY)
        let chosen = initial.offsetBy(dx: -140, dy: -250)
        placement.save(frame: chosen, display: "external", screen: display)
        let restored = FloatingBarPlacement(defaults: placementDefaults)
        precondition(restored.frame(display: "external", screen: display, size: barSize) == chosen)
        let smaller = NSRect(x: 0, y: -800, width: 1280, height: 800)
        precondition(smaller.contains(restored.frame(display: "external", screen: smaller, size: barSize)))
        precondition(restored.frame(display: "different", screen: display, size: barSize) == initial)
        precondition(FloatingBarPlacement.clamped(chosen.offsetBy(dx: 9999, dy: -9999), to: display).maxX == display.maxX)

        // Exercise the real mouse handlers without moving the user's pointer.
        let dragView = BarDragView(frame: NSRect(origin: .zero, size: barSize))
        var pointer = NSPoint(x: 100, y: 100)
        var opened = 0, began = 0, ended = 0
        var movedTo: NSPoint?
        dragView.pointerLocation = { pointer }
        dragView.open = { opened += 1 }
        dragView.begin = { began += 1 }
        dragView.move = { movedTo = $0 }
        dragView.end = { ended += 1 }
        let click = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1)!
        dragView.mouseDown(with: click)
        pointer.x += 2
        dragView.mouseDragged(with: click)
        dragView.mouseUp(with: click)
        precondition(opened == 1 && began == 0 && movedTo == nil)
        dragView.mouseDown(with: click)
        pointer.x += 80; pointer.y -= 140
        dragView.mouseDragged(with: click)
        dragView.mouseUp(with: click)
        precondition(opened == 1 && began == 1 && ended == 1)
        precondition(movedTo == NSPoint(x: 80, y: -140))

        let audio = SilentCompletionAudio()
        let model = AppModel(completionAudio: audio)
        precondition(model.error == nil)
        model.surfaces = Surfaces(model: model)
        model.surfaces.refresh()
        precondition(model.state.phase == .idle)
        precondition(model.surfaces.notchTimerShowing && !model.surfaces.menuItemShowing)
        precondition(NotchTimerView(model: model).trailing.isEmpty)
        precondition(NotchTimerView.totalWidth(clock: "", notchWidth: 0) == 32)
        precondition(NotchTimerView.totalWidth(clock: "", notchWidth: 190) == 222)
        precondition(NotchTimerView.totalWidth(clock: "25:00", notchWidth: 0) == 168)
        precondition(model.recentTasks.isEmpty)
        model.setNotchBar(false)
        precondition(!model.surfaces.notchTimerShowing && model.surfaces.menuItemShowing)
        model.toggleNotchBar()
        precondition(model.surfaces.notchTimerShowing && !model.surfaces.menuItemShowing)
        var visibilityPrefs = model.state.preferences
        visibilityPrefs.notchTimerMode = .menuBar
        model.setPreferences(visibilityPrefs)
        precondition(!model.surfaces.notchTimerShowing && model.surfaces.menuItemShowing)
        visibilityPrefs.notchTimerMode = .bar
        model.setPreferences(visibilityPrefs)
        precondition(model.surfaces.notchTimerShowing && !model.surfaces.menuItemShowing)
        model.sleeping = true
        model.surfaces.refresh()
        precondition(model.surfaces.notchTimerShowing && !model.surfaces.menuItemShowing)
        model.sleeping = false
        model.setNotchBar(false)
        model.start("Smoke task", project: "Verification")
        precondition(model.surfaces.notchTimerShowing && !model.surfaces.menuItemShowing)
        // Switching entry points is immediate, including when a show animation is in flight.
        model.setNotchBar(true)
        precondition(model.surfaces.notchTimerShowing && !model.surfaces.menuItemShowing)
        model.setNotchBar(false)
        precondition(!model.surfaces.notchTimerShowing && model.surfaces.menuItemShowing)
        precondition(!NSApp.windows.contains { $0 is NSPanel && $0.isVisible })
        model.setNotchBar(true)
        precondition(model.surfaces.notchTimerShowing && !model.surfaces.menuItemShowing)
        model.hold()
        precondition(model.surfaces.notchTimerShowing && !model.surfaces.menuItemShowing)
        model.resume()
        let id = model.state.block!.taskID!
        model.change { _ = $0.tick(seconds: 1500, now: Date()) }
        // The boundary offers to extend instead of writing the session, and offers it quietly:
        // no panel appears and nothing takes the keyboard.
        precondition(model.state.phase == .finished && model.history.isEmpty)
        precondition(model.surfaces.notchTimerShowing && !model.surfaces.menuItemShowing)
        print("Windows at the boundary:", NSApp.windows.map { "\(type(of: $0)) visible=\($0.isVisible) canBecomeKey=\($0.canBecomeKey)" })
        // The notch timer stays on screen to carry the offer; what must never appear is a panel
        // that can take the keyboard.
        precondition(NSApp.windows.filter { $0 is NSPanel && $0.isVisible }.allSatisfy { !$0.canBecomeKey })
        precondition(NSApp.keyWindow == nil)
        precondition(audio.played == [.softBell])
        precondition(NotchTimerView(model: model).trailing == "+25m")
        model.change { _ = $0.tick(seconds: 1, now: Date()) }
        precondition(audio.played.count == 1)
        // Extending reopens the same record and rearms the notification.
        model.extend()
        precondition(audio.stops > 0)
        precondition(model.state.phase == .running && model.state.block?.id != nil)
        precondition(model.state.block!.plannedSeconds == 3000 && model.state.block!.taskID == id)
        model.change { _ = $0.tick(seconds: 120, now: Date()) }
        model.abandon("Smoke completed")
        precondition(model.history.count == 1 && model.state.tasks.count == 1)
        precondition(model.surfaces.notchTimerShowing && !model.surfaces.menuItemShowing)
        // A second start on the same words is a second task, never a second session.
        model.start("Smoke task", project: "Verification")
        precondition(model.state.tasks.count == 2 && model.state.block!.taskID != id)
        model.abandon("Second task recorded")
        let reopened = AppModel()
        precondition(reopened.history.count == 2 && reopened.state.tasks[0].id == id)
        precondition(reopened.history.allSatisfy { $0.project == "Verification" })
        // Sessions take their length from the one default, and a changed default sticks.
        precondition(reopened.state.preferences.blockMinutes == 25)
        reopened.start("Default length check")
        precondition(reopened.state.block!.plannedSeconds == 1500)
        reopened.abandon("Length checked")
        var prefs = reopened.state.preferences
        prefs.blockMinutes = 50
        reopened.setPreferences(prefs)
        reopened.start("New default check")
        precondition(reopened.state.block!.plannedSeconds == 3000)
        reopened.abandon("Length checked")
        precondition(AppModel().state.preferences.blockMinutes == 50)

        // The start shortcut mid-session asks about the session already running rather than
        // starting a second one: the strip that opens is the running one, and nothing has begun.
        reopened.surfaces = Surfaces(model: reopened)
        reopened.start("Session to protect")
        reopened.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(NSApp.windows.contains { $0 is NSPanel && $0.isVisible && $0.frame.width == RunningStripView.width })
        precondition(reopened.state.block?.intent == "Session to protect")
        precondition(reopened.state.phase == .running)
        reopened.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))

        // Capture is the one thing a session accepts being told, and it arrives as the strip:
        // borderless, exactly the strip's size, and tucked under the top of the screen rather
        // than centred on it.
        reopened.surfaces.capture()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        guard let strip = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible && $0.frame.width == CaptureStripView.width }) else {
            preconditionFailure("the capture shortcut opened no strip")
        }
        precondition(strip.styleMask.contains(.borderless) && !strip.styleMask.contains(.titled))
        precondition(strip.frame.height == CaptureStripView.height)
        if let screen = NSScreen.main {
            let barHeight = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : max(24, screen.frame.maxY - screen.visibleFrame.maxY)
            let barBottom = reopened.surfaces.notchTimerShowing && screen.safeAreaInsets.top == 0
                ? screen.frame.maxY - Surfaces.menuBarHeight(on: screen)
                : screen.frame.maxY - barHeight
            precondition(abs(strip.frame.maxY - (barBottom - 8)) < 1)
        }
        reopened.enqueue("Smoke queued task")
        precondition(reopened.state.queuedTasks.last?.title == "Smoke queued task")
        reopened.abandon("Smoke completed")

        // Recent work precedes the queue, and the panel measures both sections.
        precondition(!reopened.recentTasks.isEmpty && reopened.recentTasks.count <= 3)
        precondition(reopened.recentTasks.map(\.lastUsedAt) == reopened.recentTasks.map(\.lastUsedAt).sorted(by: >))
        reopened.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        guard let bare = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible && $0.frame.width == StartStripView.width }) else {
            preconditionFailure("the start shortcut opened no strip")
        }
        precondition(bare.styleMask.contains(.borderless) && !bare.styleMask.contains(.titled))
        precondition(bare.frame.height == StartStripView.initialHeight(model: reopened))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        let top = bare.frame.maxY
        // The shortcut toggles: pressing it again puts the strip away rather than reopening it.
        reopened.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(!bare.isVisible)
        reopened.enqueue("One more to offer")
        reopened.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(bare.frame.height == StartStripView.initialHeight(model: reopened))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        // It grows downward: the edge it hangs from does not move as the list changes.
        precondition(bare.frame.maxY == top)

        // Starting a queued task consumes it and preserves its identity in the session.
        let offered = reopened.state.queuedTasks[0]
        let liveBefore = reopened.state.queuedTasks.count
        reopened.start(offered.title, project: "Verification", minutes: 45, queuedID: offered.id)
        precondition(reopened.state.block?.intent == offered.title)
        precondition(reopened.state.block?.plannedSeconds == 2700)
        precondition(reopened.state.queuedTasks.count == liveBefore - 1)
        precondition(!reopened.pendingTasks.contains { $0.id == offered.id })
        precondition(reopened.state.block?.taskID == offered.id)
        // A length chosen for one session is not a change to how Blocks works.
        precondition(reopened.state.preferences.blockMinutes == 50)

        // The start shortcut mid-session no longer does nothing: it asks about the session that
        // is already running, in a strip of its own.
        reopened.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        guard let running = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible && $0.frame.width == RunningStripView.width }) else {
            preconditionFailure("the start shortcut opened no strip mid-session")
        }
        precondition(running.frame.height == RunningStripView.height(reasoning: false))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        if reopened.surfaces.notchTimerShowing,
           let bar = NSApp.windows.first(where: { $0.isVisible && $0.styleMask.contains(.nonactivatingPanel) }) {
            precondition(abs(running.frame.maxY - (bar.frame.minY - 8)) < 1)
        } else {
            precondition(running.frame.maxY == top)
        }
        // Exercise the actual popup keyboard handler: third row extends, fourth toggles
        // the notch. Neither action creates another session or changes the current task.
        guard let keys = running.firstResponder as? KeyCatcherView else {
            preconditionFailure("running popup did not focus its keyboard handler")
        }
        let plannedBefore = reopened.state.block!.plannedSeconds
        let popupSessionID = reopened.state.block!.id
        _ = keys.onKey(125)
        _ = keys.onKey(125)
        _ = keys.onKey(36)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(reopened.state.block!.plannedSeconds == plannedBefore + 1500)
        precondition(reopened.state.block!.id == popupSessionID)
        precondition(AppModel().state.block!.plannedSeconds == plannedBefore + 1500)
        precondition(!running.isVisible)
        for _ in 0..<2 {
            reopened.surfaces.start()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
            guard let toggleKeys = running.firstResponder as? KeyCatcherView else {
                preconditionFailure("reopened popup did not focus its keyboard handler")
            }
            let wasShowing = reopened.notchBarShowing
            _ = toggleKeys.onKey(125)
            _ = toggleKeys.onKey(125)
            _ = toggleKeys.onKey(125)
            _ = toggleKeys.onKey(36)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
            precondition(reopened.notchBarShowing != wasShowing)
            precondition(!running.isVisible)
        }
        reopened.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        reopened.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(!running.isVisible)

        // Pausing from it is a hold: the clock stops, nothing is asked for, and the session's
        // one reasoned pause is still unspent.
        reopened.hold()
        precondition(reopened.state.phase == .paused)
        precondition(reopened.state.block?.pauseUsed == false)
        reopened.resume()
        precondition(reopened.state.phase == .running)

        // Abandoning from it takes an optional reason: Return on an empty field ends the
        // session and writes a record with nothing beside it.
        let before = reopened.history.count
        reopened.abandon("")
        precondition(reopened.state.phase == .idle)
        precondition(reopened.history.count == before + 1)
        precondition(reopened.history.last?.outcome == .abandoned)
        precondition(reopened.history.last?.reason == nil)
        // Return completes the first popup option in both active states, saving once.
        for paused in [false, true] {
            reopened.start("Complete from popup")
            reopened.change { _ = $0.tick(seconds: 420, now: Date()) }
            if paused { reopened.hold() }
            let count = reopened.history.count
            reopened.surfaces.start()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
            guard let completeKeys = running.firstResponder as? KeyCatcherView else {
                preconditionFailure("completion popup did not focus its keyboard handler")
            }
            _ = completeKeys.onKey(36)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
            precondition(reopened.state.phase == .idle)
            precondition(reopened.history.count == count + 1)
            precondition(reopened.history.last?.outcome == .completed)
            precondition(reopened.history.last!.focusDuration >= 420 && reopened.history.last!.focusDuration < 425)
            // AppKit may complete orderOut after the fade has reached zero, especially
            // when restoring the status item. Wait for completion within a bounded deadline.
            let dismissalDeadline = Date(timeIntervalSinceNow: 1)
            while running.isVisible && Date() < dismissalDeadline {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
            }
            precondition(!running.isVisible)
        }
        // Clicking another app dismisses transient input without submitting it. Coming
        // back to Blocks must not resurrect the hidden popup; the shortcut opens it anew.
        reopened.surfaces.capture()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        guard let capturePopup = NSApp.windows.first(where: { ($0 as? KeyPanel)?.acceptingInput == true && $0.isVisible }) else {
            preconditionFailure("capture popup missing")
        }
        let capturedBeforeDismissal = reopened.state.queuedTasks.count
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(!capturePopup.isVisible)
        precondition(reopened.state.queuedTasks.count == capturedBeforeDismissal)
        reopened.surfaces.capture()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(capturePopup.isVisible)
        reopened.surfaces.capture()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))

        reopened.surfaces.prompt(.abandon)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        guard let reasonPopup = NSApp.windows.first(where: { ($0 as? KeyPanel)?.acceptingInput == true && $0.isVisible }) else {
            preconditionFailure("reason popup missing")
        }
        let historyBeforeDismissal = reopened.history.count
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(!reasonPopup.isVisible)
        precondition(reopened.history.count == historyBeforeDismissal)
        // A click with no window must dismiss even if Blocks never loses activation.
        reopened.surfaces.capture()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        let outsideClick = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
            modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 1)!
        NSApp.sendEvent(outsideClick)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(!capturePopup.isVisible)
        precondition(reopened.state.queuedTasks.count == capturedBeforeDismissal)

        // Child popovers and native menus remain usable. Unrelated windows dismiss;
        // stopping the monitor removes its callback as well as its event subscriptions.
        let clickMonitor = PopupClickAway()
        let parent = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let child = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 50),
                             styleMask: [.borderless], backing: .buffered, defer: false)
        parent.addChildWindow(child, ordered: .above)
        var dismissals = 0
        clickMonitor.start(windows: { [parent] }, dismiss: { dismissals += 1 })
        func mouseDown(in window: NSWindow) -> NSEvent {
            NSEvent.mouseEvent(with: .rightMouseDown, location: NSPoint(x: 10, y: 10),
                modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil,
                eventNumber: 2, clickCount: 1, pressure: 1)!
        }
        clickMonitor.handleLocalClick(mouseDown(in: parent))
        clickMonitor.handleLocalClick(mouseDown(in: child))
        precondition(dismissals == 0)
        parent.removeChildWindow(child)
        clickMonitor.handleLocalClick(mouseDown(in: child))
        precondition(dismissals == 1)
        child.level = .popUpMenu
        clickMonitor.handleLocalClick(mouseDown(in: child))
        precondition(dismissals == 1)
        clickMonitor.handleExternalClick()
        precondition(dismissals == 2)
        clickMonitor.stop()
        clickMonitor.handleExternalClick()
        precondition(dismissals == 2)
        parent.orderOut(nil); child.orderOut(nil)

        // Completed To do items persist and can be reopened without creating timer history.
        reopened.enqueue("Complete and relaunch")
        let completedID = reopened.state.queuedTasks.last!.id
        reopened.setQueuedTaskCompleted(completedID, completed: true)
        precondition(AppModel().state.queuedTasks.first { $0.id == completedID }?.completed == true)
        reopened.setQueuedTaskCompleted(completedID, completed: false)
        precondition(AppModel().pendingTasks.contains { $0.id == completedID })

        // The popup delete action removes only its row and survives reopening.
        reopened.enqueue("Delete from the popup")
        let deleteID = reopened.pendingTasks.last!.id
        let keepIDs = Set(reopened.state.queuedTasks.filter { $0.id != deleteID }.map(\.id))
        let historyBeforeDelete = reopened.history.count
        reopened.removeQueuedTask(deleteID)
        precondition(Set(reopened.state.queuedTasks.map(\.id)) == keepIDs)
        precondition(Set(AppModel().state.queuedTasks.map(\.id)) == keepIDs)
        precondition(reopened.history.count == historyBeforeDelete)

        // An in-flight exit cannot win over a rapid reopen, and exits stop accepting input.
        let animatedPanel = KeyPanel(contentRect: NSRect(x: 50, y: 50, width: 240, height: 80),
                                     styleMask: [.borderless], backing: .buffered, defer: false)
        animatedPanel.isReleasedWhenClosed = false
        let motion = IslandMotion(reducedMotion: { false })
        let motionFrame = animatedPanel.frame
        motion.show(animatedPanel, frame: motionFrame)
        motion.hide(animatedPanel)
        precondition(!animatedPanel.acceptingInput && animatedPanel.ignoresMouseEvents)
        motion.show(animatedPanel, frame: motionFrame)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
        precondition(animatedPanel.isVisible && animatedPanel.acceptingInput)
        precondition(animatedPanel.alphaValue == 1 && animatedPanel.frame == motionFrame)
        motion.hide(animatedPanel)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(!animatedPanel.isVisible)
        // Reduce Motion is a fade: no displacement at either end.
        let quietMotion = IslandMotion(reducedMotion: { true })
        quietMotion.show(animatedPanel, frame: motionFrame)
        precondition(animatedPanel.frame == motionFrame)
        quietMotion.hide(animatedPanel)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
        precondition(!animatedPanel.isVisible && animatedPanel.frame == motionFrame)
        var audioPrefs = model.state.preferences
        audioPrefs.completionSound = .warmChime
        model.setPreferences(audioPrefs)
        model.start("Notification rearming")
        model.change { _ = $0.tick(seconds: 1500, now: Date()) }
        precondition(audio.played == [.softBell, .warmChime])
        model.extend()
        model.change { _ = $0.tick(seconds: 1500, now: Date()) }
        precondition(audio.played == [.softBell, .warmChime, .warmChime])
        audioPrefs.soundNotificationEnabled = false
        model.setPreferences(audioPrefs)
        model.extend()
        model.change { _ = $0.tick(seconds: 1500, now: Date()) }
        precondition(audio.played.count == 3)
        let restoredAudio = AppModel(completionAudio: SilentCompletionAudio())
        precondition(!restoredAudio.state.preferences.soundNotificationEnabled)
        precondition(restoredAudio.state.preferences.completionSound == .warmChime)
        model.abandon("Notification checks")
        // The finished start popup defaults to extending, even with an empty queue.
        func startField() -> NSTextField {
            func find(_ view: NSView) -> NSTextField? {
                if let field = view as? NSTextField, field.delegate is FocusedTextField.Coordinator { return field }
                return view.subviews.lazy.compactMap { find($0) }.first
            }
            let popup = NSApp.windows.first { ($0 as? KeyPanel)?.acceptingInput == true && $0.isVisible }!
            return find(popup.contentView!)!
        }
        for duration in [25, 50] {
            var defaults = model.state.preferences
            defaults.blockMinutes = duration
            model.setPreferences(defaults)
            model.start("Continue this session", minutes: 1)
            let sessionID = model.state.block!.id
            model.change { _ = $0.tick(seconds: 60, now: Date()) }
            model.surfaces.start()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
            let field = startField()
            let coordinator = field.delegate as! FocusedTextField.Coordinator
            coordinator.submit(field)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
            precondition(model.state.phase == .running && model.state.block!.id == sessionID)
            precondition(model.state.remaining == Double(duration * 60))
            model.abandon("Extension popup checked")
        }
        model.enqueue("Pick the queued task")
        let queuedID = model.pendingTasks.first!.id
        model.start("Finish before selecting", minutes: 1)
        model.change { _ = $0.tick(seconds: 60, now: Date()) }
        model.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        let queueField = startField()
        let queueCoordinator = queueField.delegate as! FocusedTextField.Coordinator
        // Extension is initially selected; arrow through recent work to reach the queue.
        for _ in 0...model.recentTasks.count {
            precondition(queueCoordinator.parent.onMove(1))
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        queueCoordinator.submit(queueField)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(model.state.block?.taskID == queuedID)
        model.abandon("Queue navigation checked")

        let recentChoice = model.recentTasks[0]
        let queuedBeforeRecent = model.pendingTasks.map(\.id)
        model.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        let recentField = startField()
        let recentCoordinator = recentField.delegate as! FocusedTextField.Coordinator
        precondition(recentCoordinator.parent.onMove(1))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        recentCoordinator.submit(recentField)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(model.state.phase == .running)
        precondition(model.state.block?.intent == recentChoice.title)
        precondition(model.state.block?.project == recentChoice.project)
        precondition(model.pendingTasks.map(\.id) == queuedBeforeRecent)
        model.abandon("Recent navigation checked")

        model.enqueue("Delete smoke first")
        model.enqueue("Delete smoke second")
        let deletionIDs = model.pendingTasks.filter { $0.title.hasPrefix("Delete smoke") }.map(\.id)
        let tasksBeforeKeyboardDelete = model.state.tasks
        model.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        let deleteField = startField()
        let deleteCoordinator = deleteField.delegate as! FocusedTextField.Coordinator
        let editor = deleteField.currentEditor() as! NSTextView
        // Without a selected queue row, Delete belongs to normal text editing.
        precondition(!deleteCoordinator.control(deleteField, textView: editor,
                                                doCommandBy: #selector(NSResponder.deleteBackward(_:))))
        precondition(deleteCoordinator.parent.onMove(1))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        // Recent work must not be deleted.
        precondition(!deleteCoordinator.control(deleteField, textView: editor,
                                                doCommandBy: #selector(NSResponder.deleteBackward(_:))))
        deleteField.stringValue = "Delete smoke"
        deleteCoordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: deleteField))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        precondition(deleteCoordinator.parent.onMove(1))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        for command in [#selector(NSResponder.deleteBackward(_:)), #selector(NSResponder.deleteForward(_:))] {
            precondition(deleteCoordinator.control(deleteField, textView: editor, doCommandBy: command))
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
        }
        precondition(!model.pendingTasks.contains { deletionIDs.contains($0.id) })
        precondition(model.pendingTasks.map(\.id) == queuedBeforeRecent)
        precondition(model.state.tasks == tasksBeforeKeyboardDelete)
        precondition(deleteField.stringValue == "Delete smoke")
        precondition(!deleteCoordinator.control(deleteField, textView: editor,
                                                doCommandBy: #selector(NSResponder.deleteBackward(_:))))
        model.surfaces.start()

        model.start("Finish before typing", minutes: 1)
        model.change { _ = $0.tick(seconds: 60, now: Date()) }
        model.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        let typedField = startField()
        let typedCoordinator = typedField.delegate as! FocusedTextField.Coordinator
        typedField.stringValue = "A different task"
        typedCoordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: typedField))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        typedCoordinator.submit(typedField)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(model.state.block?.intent == "A different task")
        model.abandon("Typed task checked")

        // Expiring the offer while its popup is open must not leave a stale default action.
        model.start("Expiring offer", minutes: 1)
        model.change { _ = $0.tick(seconds: 60, now: Date()) }
        model.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        model.change { _ = $0.tick(seconds: 0, now: Date().addingTimeInterval(Engine.extendWindow + 1)) }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        let expiredField = startField()
        (expiredField.delegate as! FocusedTextField.Coordinator).submit(expiredField)
        precondition(model.state.phase == .idle)
        model.surfaces.start()
        print("PASS: app persistence, one task per session, a quiet boundary with an extension, one saved default length, a start shortcut that asks about the session it would interrupt, three strips under the notch, animated dismissal, rapid reopening, and Reduce Motion")
    }
}
