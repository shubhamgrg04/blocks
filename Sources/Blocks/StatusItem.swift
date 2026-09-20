import AppKit
import SwiftUI
import BlocksCore

/// The menu bar clock mirrors remaining session time and the quiet 30-second warning.
///
/// Blocks owns the `NSStatusItem` rather than handing SwiftUI a `MenuBarExtra` label, because
/// the title has to be a value assigned on every tick. A SwiftUI label in the status bar is
/// rendered once as a template image: it drops the text, does not reliably re-render when the
/// model changes, and strips the colour the warning depends on.
@MainActor
final class StatusItem: NSObject, NSPopoverDelegate {
    private unowned let model: AppModel
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let clickAway = PopupClickAway()
    private let timerIcon: NSImage = {
        let image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Blocks timer")!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .medium))!
        image.isTemplate = true
        return image
    }()
    private let content: NSHostingController<MenuView>

    init(model: AppModel) {
        self.model = model
        content = NSHostingController(rootView: MenuView(model: model))
        super.init()
        popover.behavior = .transient
        popover.delegate = self
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = content
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.imagePosition = .imageLeading
        refresh()
    }

    /// Four states, four shapes: the wordless icon when nothing is running, bare digits while a
    /// block runs, the pause glyph beside greyed digits when it is paused, and a checkmark with
    /// "Done" while the finished session can still be extended. The icon coming back *is* the
    /// signal, so a frozen number never reads as a live one.
    ///
    /// The digits step aside while the notch bar is showing them instead. "Done" does not: the
    /// boundary is a state that wants an answer rather than a second ticking clock.
    func refresh() {
        guard let button = item.button else { return }
        let phase = model.state.phase
        if phase == .finished, model.error == nil {
            button.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil)
            button.attributedTitle = NSAttributedString(string: "Done", attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
            ])
            let minutes = Int(Engine.extendWindow / 60)
            button.setAccessibilityLabel("Blocks, session finished. Extend it within \(minutes) minutes or it saves itself.")
            return
        }
        let running = [.running, .paused].contains(phase) && model.error == nil
        guard running else {
            button.image = timerIcon
            button.attributedTitle = NSAttributedString(string: "")
            button.setAccessibilityLabel("Blocks")
            return
        }
        let paused = phase == .paused || model.sleeping
        let warning = phase == .running && !model.sleeping && model.state.remaining <= 30
        // The notch bar is a clock too, and two of them counting down in one glance is noise.
        // Whenever it is up the digits live there and the menu bar keeps only its icon — the
        // pause glyph if the session is held, so that signal survives either way.
        if model.surfaces?.notchTimerShowing == true {
            button.image = paused ? NSImage(systemSymbolName: "pause.fill", accessibilityDescription: nil) : timerIcon
            button.attributedTitle = NSAttributedString(string: "")
            button.setAccessibilityLabel(paused ? "Blocks, paused, \(model.clock) remaining" : "Blocks, \(model.clock) remaining")
            return
        }
        button.image = paused ? NSImage(systemSymbolName: "pause.fill", accessibilityDescription: nil) : nil
        button.attributedTitle = NSAttributedString(string: model.clock, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: paused ? NSColor.secondaryLabelColor : warning ? NSColor.systemOrange : NSColor.labelColor
        ])
        button.setAccessibilityLabel(paused ? "Blocks, paused, \(model.clock) remaining" : "Blocks, \(model.clock) remaining")
    }

    /// Explicitly opened prompts and windows dismiss the transient popover.
    func dismiss() {
        clickAway.stop()
        popover.performClose(nil)
    }
    func popoverWillClose(_ notification: Notification) { clickAway.stop() }


    @objc private func toggle() {
        if popover.isShown { dismiss(); return }
        guard let button = item.button else { return }
        // The popover's content grows with the task queue, so it is measured each time it
        // opens rather than pinned to a constant that would clip it.
        content.view.layoutSubtreeIfNeeded()
        popover.contentSize = content.view.fittingSize
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        clickAway.start(windows: { [weak self] in
            guard let self else { return [] }
            // The anchor button retains its normal toggle behavior on a second click.
            return [self.content.view.window, self.item.button?.window].compactMap { $0 }
        }, dismiss: { [weak self] in self?.dismiss() })
    }
}
