import AppKit
import SwiftUI
import BlocksCore

/// The session clock as two wings either side of the notch.
///
/// The bar is exactly as tall as the physical notch and sits flush with the top of the screen,
/// so its top and bottom edges are the notch's own edges: what grows during a session is the
/// notch's width, never its height. The middle is left empty because the hardware is there —
/// a close button and a hold/resume button go in the left wing and the time left in the right,
/// which is all that fits at that height and all a glance needs. Non-activating, so clicking a
/// button never takes the keyboard away from the work it is timing. While it is up the menu bar carries no
/// digits; one clock at a time, and closing the bar hands the clock back to the menu bar.
struct NotchTimerView: View {
    @ObservedObject var model: AppModel
    /// The height of the bar: the notch's own height, or the menu bar's on a screen without one.
    var barHeight: CGFloat = 32
    /// The gap left for the notch itself. Zero on a screen that has none, where the two wings
    /// join into one short bar.
    var notchWidth: CGFloat = 0
    /// Sends this session's clock back to the menu bar.
    var dismiss: () -> Void = {}

    /// The wings are measured rather than guessed, because the empty middle has to line up with
    /// the physical notch to the pixel: the panel is positioned from the notch's own edges and
    /// these are the widths that put the button and the clock beside it.
    static let outerPadding: CGFloat = 10
    static let innerPadding: CGFloat = 10
    static let clockFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
    /// A button's hit area — small, but a whole target rather than a glyph to aim at.
    static let buttonSize: CGFloat = 20
    /// The two buttons sit close enough to read as one cluster and far enough not to be misaimed.
    static let buttonGap: CGFloat = 4

    static func trailingWidth(for clock: String) -> CGFloat {
        ceil((clock as NSString).size(withAttributes: [.font: clockFont]).width)
    }
    /// The whole bar: both wings, their padding, and the notch between them.
    static func totalWidth(clock: String, notchWidth: CGFloat) -> CGFloat {
        let sides = outerPadding * 2 + (notchWidth > 0 ? innerPadding * 2 : innerPadding)
        return sides + leadingButtons + notchWidth + trailingWidth(for: clock)
    }
    /// Both buttons and the gap between them. The pause/resume button keeps its place even in
    /// the phases that have nothing to toggle, so the bar never shifts sideways under the
    /// pointer that is reaching for it.
    static var leadingButtons: CGFloat { buttonSize * 2 + buttonGap }
    /// How far the bar hangs off the left edge of the notch.
    static var leadingWing: CGFloat { outerPadding + leadingButtons + innerPadding }

    /// "Done" at the boundary, where a frozen 00:00 would read as a clock that had stopped
    /// working rather than as a session waiting to be extended.
    var trailing: String { model.state.phase == .finished ? "Done" : model.clock }

    var body: some View {
        HStack(spacing: 0) {
            WingButton(icon: "xmark", size: 9, help: "Hide this bar — the clock goes back to the menu bar", label: "Hide the session bar", action: dismiss)
                .frame(width: NotchTimerView.buttonSize, height: NotchTimerView.buttonSize)
                .padding(.leading, NotchTimerView.outerPadding)
            Group {
                if let hold {
                    WingButton(icon: hold.icon, size: 10, help: hold.label, label: hold.label, action: hold.act)
                } else {
                    Color.clear
                }
            }
            .frame(width: NotchTimerView.buttonSize, height: NotchTimerView.buttonSize)
            .padding(.leading, NotchTimerView.buttonGap)
            .padding(.trailing, NotchTimerView.innerPadding)
            if notchWidth > 0 { Color.clear.frame(width: notchWidth) }
            Text(trailing)
                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .frame(width: NotchTimerView.trailingWidth(for: trailing), alignment: .leading)
                .foregroundStyle(tint)
                .padding(.leading, NotchTimerView.innerPadding)
                .padding(.trailing, NotchTimerView.outerPadding)
        }
        .frame(height: barHeight)
        // Only the bottom corners are rounded, and gently: the top edge is the top of the
        // screen, and the bottom edge continues the curve the notch already has.
        .background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 9, bottomTrailingRadius: 9))
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
        if model.state.phase == .paused || model.sleeping { return .white.opacity(0.5) }
        if model.state.phase == .finished { return Color(red: 0.65, green: 0.83, blue: 0.58) }
        return model.state.remaining <= 30 ? .orange : .white
    }
    private var label: String {
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
