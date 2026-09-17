import AppKit
import SwiftUI
import BlocksCore

/// The menu bar clock: the remaining time of the running block, and — since the ambient bar
/// was removed — the only visual warning channel Blocks has left. See ADR 0003.
///
/// Blocks owns the `NSStatusItem` rather than handing SwiftUI a `MenuBarExtra` label, because
/// the title has to be a value assigned on every tick. A SwiftUI label in the status bar is
/// rendered once as a template image: it drops the text, does not reliably re-render when the
/// model changes, and strips the colour the warning depends on.
@MainActor
final class StatusItem: NSObject {
    private unowned let model: AppModel
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let content: NSHostingController<MenuView>

    init(model: AppModel) {
        self.model = model
        content = NSHostingController(rootView: MenuView(model: model))
        super.init()
        popover.behavior = .transient
        popover.contentViewController = content
        item.button?.target = self
        item.button?.action = #selector(toggle)
        item.button?.imagePosition = .imageLeading
        refresh()
    }

    /// Three states, three shapes: the wordless icon when nothing is running, bare digits while
    /// a block runs, and the pause glyph returning beside greyed digits when it is paused. The
    /// icon coming back *is* the paused signal, so a frozen number never reads as a live one.
    func refresh() {
        guard let button = item.button else { return }
        let phase = model.state.phase
        let running = [.running, .paused].contains(phase) && model.error == nil
        guard running else {
            button.image = BlocksBrand.menuIcon
            button.attributedTitle = NSAttributedString(string: "")
            button.setAccessibilityLabel("Blocks")
            return
        }
        let paused = phase == .paused || model.sleeping
        let warning = phase == .running && !model.sleeping && model.state.remaining <= 30
        button.image = paused ? NSImage(systemSymbolName: "pause.fill", accessibilityDescription: nil) : nil
        button.attributedTitle = NSAttributedString(string: model.clock, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            .foregroundColor: paused ? NSColor.secondaryLabelColor : warning ? NSColor.systemOrange : NSColor.labelColor
        ])
        button.setAccessibilityLabel(paused ? "Blocks, paused, \(model.clock) remaining" : "Blocks, \(model.clock) remaining")
    }

    /// A prompt or the honesty check takes over the screen; the popover must not stay behind it.
    func dismiss() { popover.performClose(nil) }

    @objc private func toggle() {
        if popover.isShown { popover.performClose(nil); return }
        guard let button = item.button else { return }
        // The popover's content grows with the queue and the parked list, so it is measured
        // each time it opens rather than pinned to a constant that would clip the lists.
        content.view.layoutSubtreeIfNeeded()
        popover.contentSize = content.view.fittingSize
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }
}
