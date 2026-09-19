import AppKit
import BlocksCore

/// Uses only BLOCKS_TEST_DATA_DIRECTORY; never opens or changes the owner's data.
@main enum Smoke {
    @MainActor static func main() throws {
        precondition(ProcessInfo.processInfo.environment["BLOCKS_TEST_DATA_DIRECTORY"] != nil)
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let model = AppModel()
        precondition(model.error == nil)
        model.surfaces = Surfaces(model: model)
        model.start("Smoke task", project: "Verification")
        let id = model.state.block!.taskID!
        model.change { _ = $0.tick(seconds: 1500, now: Date()) }
        // The boundary offers to extend instead of writing the session, and offers it quietly:
        // no panel appears and nothing takes the keyboard.
        precondition(model.state.phase == .finished && model.history.isEmpty)
        print("Windows at the boundary:", NSApp.windows.map { "\(type(of: $0)) visible=\($0.isVisible) canBecomeKey=\($0.canBecomeKey)" })
        // The notch timer stays on screen to carry the offer; what must never appear is a panel
        // that can take the keyboard.
        precondition(NSApp.windows.filter { $0 is NSPanel && $0.isVisible }.allSatisfy { !$0.canBecomeKey })
        precondition(NSApp.keyWindow == nil)
        // Extending reopens the same record rather than starting a second session.
        model.extend()
        precondition(model.state.phase == .running && model.state.block?.id != nil)
        precondition(model.state.block!.plannedSeconds == 3000 && model.state.block!.taskID == id)
        model.change { _ = $0.tick(seconds: 120, now: Date()) }
        model.abandon("Smoke completed")
        precondition(model.history.count == 1 && model.state.tasks.count == 1)
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
            precondition(strip.frame.maxY <= screen.frame.maxY - barHeight)
            precondition(strip.frame.maxY > screen.frame.maxY - barHeight - 20)
        }
        reopened.capture("Smoke distraction")
        precondition(reopened.state.distractions.last?.text == "Smoke distraction")
        reopened.abandon("Smoke completed")

        // The start strip is the same black line, and it grows by exactly the distractions it
        // has to offer: two lines tall with nothing captured, taller once there is a list.
        reopened.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        guard let bare = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible && $0.frame.width == StartStripView.width }) else {
            preconditionFailure("the start shortcut opened no strip")
        }
        precondition(bare.styleMask.contains(.borderless) && !bare.styleMask.contains(.titled))
        precondition(bare.frame.height == StartStripView.height(rows: reopened.state.distractions.count))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        let top = bare.frame.maxY
        // The shortcut toggles: pressing it again puts the strip away rather than reopening it.
        reopened.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(!bare.isVisible)
        reopened.capture("One more to offer")
        reopened.surfaces.start()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(bare.frame.height == StartStripView.height(rows: reopened.state.distractions.count))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        // It grows downward: the edge it hangs from does not move as the list changes.
        precondition(bare.frame.maxY == top)

        // Starting on one takes it off the live list and into the archive, where it can be
        // restored — the list's second exit, not a deletion.
        let offered = reopened.state.distractions[0]
        let liveBefore = reopened.state.distractions.count
        reopened.start(offered.text, project: "Verification", minutes: 45, resolving: offered.id)
        precondition(reopened.state.block?.intent == offered.text)
        precondition(reopened.state.block?.plannedSeconds == 2700)
        precondition(reopened.state.distractions.count == liveBefore)
        precondition(reopened.state.distractions.first { $0.id == offered.id }?.resolved == true)
        precondition(!reopened.activeDistractions.contains { $0.id == offered.id })
        precondition(reopened.archivedDistractions.contains { $0.item.id == offered.id && $0.disposition == "resolved" })
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
        precondition(running.frame.maxY == top)
        // Exercise the actual popup keyboard handler: second row extends, third toggles
        // the notch. Neither action creates another session or changes the current task.
        guard let keys = running.firstResponder as? KeyCatcherView else {
            preconditionFailure("running popup did not focus its keyboard handler")
        }
        let plannedBefore = reopened.state.block!.plannedSeconds
        let popupSessionID = reopened.state.block!.id
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
        // Clicking another app dismisses transient input without submitting it. Coming
        // back to Blocks must not resurrect the hidden popup; the shortcut opens it anew.
        reopened.surfaces.capture()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        guard let capturePopup = NSApp.windows.first(where: { ($0 as? KeyPanel)?.acceptingInput == true && $0.isVisible }) else {
            preconditionFailure("capture popup missing")
        }
        let capturedBeforeDismissal = reopened.state.distractions.count
        NotificationCenter.default.post(name: NSApplication.didResignActiveNotification, object: NSApp)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
        precondition(!capturePopup.isVisible)
        precondition(reopened.state.distractions.count == capturedBeforeDismissal)
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
        precondition(reopened.state.distractions.count == capturedBeforeDismissal)

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

        // Resolution survives relaunch and expires from the list after 24 hours offline.
        reopened.capture("Resolve and relaunch")
        let resolvedID = reopened.state.distractions.last!.id
        reopened.resolve(resolvedID)
        precondition(AppModel().state.distractions.first { $0.id == resolvedID }?.resolved == true)
        reopened.change { engine in
            let index = engine.state.distractions.firstIndex { $0.id == resolvedID }!
            engine.state.distractions[index].resolvedAt = Date().addingTimeInterval(-86_401)
        }
        precondition(!AppModel().state.distractions.contains { $0.id == resolvedID })

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
        print("PASS: app persistence, one task per session, a quiet boundary with an extension, one saved default length, a start shortcut that asks about the session it would interrupt, three strips under the notch, animated dismissal, rapid reopening, and Reduce Motion")
    }
}
