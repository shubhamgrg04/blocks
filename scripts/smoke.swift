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
        precondition(NSApp.windows.contains { $0 is NSPanel && $0.isVisible && $0.frame.width == RunningStripView.width })
        precondition(reopened.state.block?.intent == "Session to protect")
        precondition(reopened.state.phase == .running)
        reopened.surfaces.start()

        // Capture is the one thing a session accepts being told, and it arrives as the strip:
        // borderless, exactly the strip's size, and tucked under the top of the screen rather
        // than centred on it.
        reopened.surfaces.capture()
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
        guard let bare = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible && $0.frame.width == StartStripView.width }) else {
            preconditionFailure("the start shortcut opened no strip")
        }
        precondition(bare.styleMask.contains(.borderless) && !bare.styleMask.contains(.titled))
        precondition(bare.frame.height == StartStripView.height(rows: reopened.state.distractions.count))
        let top = bare.frame.maxY
        // The shortcut toggles: pressing it again puts the strip away rather than reopening it.
        reopened.surfaces.start()
        precondition(!bare.isVisible)
        reopened.capture("One more to offer")
        reopened.surfaces.start()
        precondition(bare.frame.height == StartStripView.height(rows: reopened.state.distractions.count))
        // It grows downward: the edge it hangs from does not move as the list changes.
        precondition(bare.frame.maxY == top)

        // Starting on one takes it off the live list and into the archive, where it can be
        // restored — the list's second exit, not a deletion.
        let offered = reopened.state.distractions[0]
        let liveBefore = reopened.state.distractions.count
        reopened.start(offered.text, project: "Verification", minutes: 45, resolving: offered.id)
        precondition(reopened.state.block?.intent == offered.text)
        precondition(reopened.state.block?.plannedSeconds == 2700)
        precondition(reopened.state.distractions.count == liveBefore - 1)
        precondition(reopened.archivedDistractions.contains { $0.item.id == offered.id && $0.disposition == "resolved" })
        // A length chosen for one session is not a change to how Blocks works.
        precondition(reopened.state.preferences.blockMinutes == 50)

        // The start shortcut mid-session no longer does nothing: it asks about the session that
        // is already running, in a strip of its own.
        reopened.surfaces.start()
        guard let running = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible && $0.frame.width == RunningStripView.width }) else {
            preconditionFailure("the start shortcut opened no strip mid-session")
        }
        precondition(running.frame.height == RunningStripView.height(reasoning: false))
        precondition(running.frame.maxY == top)
        reopened.surfaces.start()
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
        print("PASS: app persistence, one task per session, a quiet boundary with an extension, one saved default length, a start shortcut that asks about the session it would interrupt, and three strips under the notch")
    }
}
