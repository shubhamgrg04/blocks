import AppKit
import SwiftUI
import BlocksCore

/// Compact wings around a physical notch, or a floating timer pill on other displays.
/// The close button hands the sole entry point back to the menu bar.
struct NotchTimerView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The physical notch height, or the floating pill height.
    var barHeight: CGFloat = 32
    /// Zero selects the floating layout for displays without a physical notch.
    var notchWidth: CGFloat = 0
    /// Sends this session's clock back to the menu bar.
    var dismiss: () -> Void = {}
    /// Opens the session popup beneath the bar.
    var openPopup: () -> Void = {}

    var beginDrag: () -> Void = {}
    var moveDrag: (NSPoint) -> Void = { _ in }
    var endDrag: () -> Void = {}

    /// The wings are measured rather than guessed, because the empty middle has to line up with
    /// the physical notch to the pixel: the panel is positioned from the notch's own edges and
    /// these are the widths that put the button and the clock beside it.
    static let floatingHeight: CGFloat = 24
    static let floatingWidth: CGFloat = 168
    static let outerPadding: CGFloat = 10
    static let innerPadding: CGFloat = 10
    static let clockFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    /// A button's hit area — small, but a whole target rather than a glyph to aim at.
    static let buttonSize: CGFloat = 20

    static func trailingWidth(for clock: String) -> CGFloat {
        ceil((clock as NSString).size(withAttributes: [.font: clockFont]).width)
    }
    /// The whole bar: both wings, their padding, and the notch between them.
    static func totalWidth(clock: String, notchWidth: CGFloat) -> CGFloat {
        if notchWidth == 0 { return floatingWidth }
        let sides = outerPadding * 2 + (notchWidth > 0 ? innerPadding * 2 : innerPadding)
        return sides + buttonSize + notchWidth + buttonSize + 8 + trailingWidth(for: clock)
    }
    /// How far the close button's wing hangs off the left edge of the notch.
    static var leadingWing: CGFloat { outerPadding + buttonSize + innerPadding }

    /// Completion is the ring's checkmark; no frozen zero or duplicate "Done" label.
    var trailing: String {
        if model.state.phase == .idle { return "Ready" }
        return model.state.phase == .finished ? "" : model.clock
    }

    var body: some View {
        Group {
            if notchWidth > 0 { wings } else { floating }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    private var floating: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                SessionGlyph(model: model, size: 16)
                    .accessibilityHidden(true)
                Text(model.state.phase == .finished ? "Done" : trailing)
                    .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(tint)
                    .fixedSize()
                    .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: trailing)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                BarDragArea(label: "Open Blocks, \(label)", open: openPopup,
                            begin: beginDrag, move: moveDrag, end: endDrag)
            }
            .help("Click to open Blocks; drag to move the bar")
            if let hold {
                WingButton(icon: hold.icon, size: 10, help: hold.label, label: hold.label, action: hold.act)
                    .frame(width: Self.buttonSize, height: Self.buttonSize)
            }
            Capsule().fill(.white.opacity(0.16))
                .frame(width: 1, height: 10)
                .allowsHitTesting(false)
            WingButton(icon: "xmark", size: 9, help: "Move to the menu bar", label: "Hide the session bar", action: dismiss)
                .frame(width: Self.buttonSize, height: Self.buttonSize)
        }
        .padding(.horizontal, 10)
        .frame(width: Self.floatingWidth, height: barHeight)
        .background(Capsule().fill(.black))
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1).allowsHitTesting(false))
    }

    private var wings: some View {
        HStack(spacing: 0) {
            WingButton(icon: "xmark", size: 9, help: "Hide this bar — the clock goes back to the menu bar", label: "Hide the session bar", action: dismiss)
                .frame(width: NotchTimerView.buttonSize, height: NotchTimerView.buttonSize)
                .padding(.leading, NotchTimerView.outerPadding)
                .padding(.trailing, NotchTimerView.innerPadding)
            if notchWidth > 0 { Color.clear.frame(width: notchWidth) }
            Group {
                if let hold {
                    WingButton(icon: hold.icon, size: 10, help: hold.label, label: hold.label, action: hold.act)
                } else {
                    SessionGlyph(model: model, size: 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: NotchTimerView.buttonSize, height: NotchTimerView.buttonSize)
            .padding(.leading, notchWidth > 0 ? NotchTimerView.innerPadding : 0)
            .padding(.trailing, 8)
            Text(trailing)
                .contentTransition(reduceMotion ? .identity : .numericText(countsDown: true))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: trailing)
                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .frame(width: NotchTimerView.trailingWidth(for: trailing), alignment: .leading)
                .foregroundStyle(tint)
                .padding(.trailing, NotchTimerView.outerPadding)
                .allowsHitTesting(false)
        }
        .frame(height: barHeight)
        .background {
            Button(action: openPopup) {
                Color.clear.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open Blocks")
            .accessibilityLabel("Open Blocks")
        }
        // Only the bottom corners are rounded, and gently: the top edge is the top of the
        // screen, and the bottom edge continues the curve the notch already has.
        .background {
            if notchWidth > 0 {
                UnevenRoundedRectangle(bottomLeadingRadius: 15, bottomTrailingRadius: 15).fill(.black)
            } else {
                Capsule().fill(.black)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
    /// Holding and letting go of the clock, on the bar rather than only in the menu. Nothing is
    /// asked for and nothing is ended: one click stops the time being counted, the next starts
    /// it again. The phases with no clock to hold — finished, or a machine that is asleep —
    /// offer nothing.
    private var hold: (icon: String, label: String, act: () -> Void)? {
        guard !model.sleeping else { return nil }
        switch model.state.phase {
        case .running: return ("pause.fill", "Pause the timer", { model.hold() })
        case .paused: return ("play.fill", "Resume the timer", { model.resume() })
        default: return nil
        }
    }
    /// The same quiet warning the menu bar gives: orange for the last thirty seconds, dimmed
    /// while the session is held.
    private var tint: Color {
        if model.state.phase == .idle { return Studio.accent }
        if model.state.phase == .paused || model.sleeping { return Studio.amber }
        if model.state.phase == .finished { return Studio.accent }
        return model.state.remaining <= 30 ? Studio.amber : Studio.accent
    }
    private var label: String {
        if model.state.phase == .idle { return "Blocks, ready to start a session" }
        let intent = model.state.block?.intent ?? ""
        if model.state.phase == .finished { return "Blocks, session finished · \(intent)" }
        if model.state.phase == .paused || model.sleeping { return "Blocks, paused, \(model.clock) remaining · \(intent)" }
        return "\(model.clock) left · \(intent)"
    }
}

/// Dim until the pointer finds it, so the bar reads as one black shape at a glance and as a
/// thing with controls as soon as you go looking for them.
private struct WingButton: View {
    let icon: String
    let size: CGFloat
    let help: String
    let label: String
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white.opacity(hovering ? 0.95 : 0.45))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Circle().fill(.white.opacity(hovering ? 0.16 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Studio.tap, value: hovering)
        .help(help)
        .accessibilityLabel(label)
    }
}

/// Track in screen coordinates so moving the window cannot feed back into the drag delta.
/// A short click opens the menu; dragging never also opens it or presses a timer control.
private struct BarDragArea: NSViewRepresentable {
    let label: String
    let open: () -> Void
    let begin: () -> Void
    let move: (NSPoint) -> Void
    let end: () -> Void

    func makeNSView(context: Context) -> BarDragView { BarDragView() }
    func updateNSView(_ view: BarDragView, context: Context) {
        view.open = open; view.begin = begin; view.move = move; view.end = end
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        view.setAccessibilityLabel(label)
        view.setAccessibilityHelp("Click to open Blocks; drag to move the bar")
    }
}

final class BarDragView: NSView {
    var open: () -> Void = {}
    var begin: () -> Void = {}
    var move: (NSPoint) -> Void = { _ in }
    var end: () -> Void = {}
    var pointerLocation: () -> NSPoint = { NSEvent.mouseLocation }
    private var pointerStart: NSPoint?
    private var windowStart = NSPoint.zero
    private var dragging = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        pointerStart = pointerLocation()
        windowStart = window?.frame.origin ?? .zero
        dragging = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let pointerStart else { return }
        let pointer = pointerLocation()
        let dx = pointer.x - pointerStart.x, dy = pointer.y - pointerStart.y
        guard dragging || hypot(dx, dy) >= 4 else { return }
        if !dragging { dragging = true; begin() }
        move(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy))
    }
    override func mouseUp(with event: NSEvent) {
        guard pointerStart != nil else { return }
        pointerStart = nil
        if dragging { dragging = false; end() }
        else { open() }
    }
    override func accessibilityPerformPress() -> Bool { open(); return true }
}
