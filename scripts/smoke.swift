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
        print("PASS: app persistence, one task per session, a quiet boundary with an extension, and one saved default length")
    }
}
