import SwiftUI
import AppKit
import Carbon

enum Studio {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
    // The same neutral register as the notch and command strips.
    static let canvas = Color(red: 0.027, green: 0.035, blue: 0.043)
    static let surface = Color(red: 0.065, green: 0.078, blue: 0.086)
    static let ink = Color(white: 0.94)
    static let accent = Color(red: 0.65, green: 0.84, blue: 0.77)
    static let lavender = Color(red: 0.73, green: 0.69, blue: 0.89)
    static let amber = Color(red: 0.91, green: 0.74, blue: 0.48)
    static let raised = Color(red: 0.085, green: 0.105, blue: 0.113)
    static let muted = Color(white: 0.63)
    static let line = Color(white: 0.20)
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
    /// Secondary text — timestamps, hints, counts. One step below body, never smaller.
    static let small: Font = .system(size: 12)
    static let smallMedium: Font = .system(size: 12, weight: .medium)

    /// The one timing every interaction in Blocks shares: quick enough to feel like a response
    /// to the click rather than a scene change, soft enough not to look mechanical.
    static let tap: Animation = .spring(duration: 0.22, bounce: 0.25)
    static let settle: Animation = .spring(duration: 0.4, bounce: 0.15)
    /// Rows enter from the direction a new thought comes from and fade out where they were.
    static let rowTransition: AnyTransition = .asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: .top)),
        removal: .opacity.combined(with: .scale(scale: 0.94)))

    /// The symbols for a recorded shortcut, in the order macOS prints them.
    static func shortcut(code: UInt32, modifiers: UInt32) -> String {
        (modifiers & UInt32(controlKey) != 0 ? "⌃" : "") + (modifiers & UInt32(optionKey) != 0 ? "⌥" : "")
            + (modifiers & UInt32(shiftKey) != 0 ? "⇧" : "") + (modifiers & UInt32(cmdKey) != 0 ? "⌘" : "")
            + (RecorderButton.keyNames[code] ?? "Key \(code)")
    }
}

/// Quiet controls share the strips’ contrast, with separate hover and keyboard focus states.
struct StudioButton: ButtonStyle {
    var primary = false
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        StudioButtonBody(primary: primary, compact: compact, configuration: configuration)
    }
}
private struct StudioButtonBody: View {
    let primary: Bool
    let compact: Bool
    let configuration: ButtonStyle.Configuration
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var focused
    @State private var hovering = false
    var body: some View {
        let pressed = configuration.isPressed
        configuration.label.font(.system(size: compact ? 12 : 13, weight: .semibold, design: .default))
            .padding(.horizontal, compact ? 8 : 12).padding(.vertical, compact ? 5 : 8)
            .foregroundStyle(primary ? Color.black : Studio.ink)
            .background(primary ? Studio.accent : Studio.surface,
                        in: RoundedRectangle(cornerRadius: compact ? 8 : 12))
            .overlay(RoundedRectangle(cornerRadius: compact ? 8 : 12).strokeBorder(focused ? Studio.ink : primary ? .clear : Studio.line, lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: compact ? 8 : 12).fill(.white.opacity(hovering && enabled ? (primary ? 0.1 : 0.06) : 0)))
            .opacity(enabled ? (pressed ? 0.85 : 1) : 0.4)
            .animation(Studio.tap, value: pressed)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Small icon-only controls (remove, resolve) get a generous circular hit area and the same
/// hover/press response as full buttons, so they never feel like a target you have to aim for.
struct IconButton: ButtonStyle {
    var tint: Color = Studio.muted
    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(tint: tint, configuration: configuration)
    }
}
private struct IconButtonBody: View {
    let tint: Color
    let configuration: ButtonStyle.Configuration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var focused
    @State private var hovering = false
    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(hovering ? Studio.ink : tint)
            .frame(width: 28, height: 28)
            .background(Circle().fill(Studio.ink.opacity(hovering ? 0.08 : 0)))
            .contentShape(Circle())
            .overlay(Circle().strokeBorder(focused ? Studio.ink : .clear, lineWidth: 1))
            .animation(Studio.tap, value: pressed)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Compact rows use a hairline separator without moving their hit targets on hover.
struct StudioRow: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Studio.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(hovering ? Studio.accent.opacity(0.35) : Studio.line.opacity(0.6), lineWidth: 1))
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
            .transition(reduceMotion ? .opacity : Studio.rowTransition)
    }
}
extension View {
    func studioRow() -> some View { modifier(StudioRow()) }
}

struct FocusProgress: View {
    let seconds: Double
    let targetSeconds: Double
    var height: CGFloat = 12
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var fraction: Double { min(1, max(0, seconds / max(1, targetSeconds))) }
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 4).fill(Studio.line.opacity(0.7))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Studio.accent)
                        .frame(width: geometry.size.width * fraction)
                }
        }.frame(height: height)
            .animation(reduceMotion ? nil : Studio.settle, value: fraction)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Daily focus goal")
            .accessibilityValue("\(focusTime(seconds)) of \(focusTime(targetSeconds)) focused today")
    }
}

extension View {
    func studioCanvas() -> some View {
        self.font(.system(size: 13)).foregroundStyle(Studio.ink).tint(Studio.accent).background(Studio.canvas).preferredColorScheme(.dark)
    }
}

/// The compact and expanded islands share concentric edges and a faint state-colored rim.
struct IslandSurface: ViewModifier {
    var tint: Color
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(Color.black, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [tint.opacity(0.30), .white.opacity(0.07)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }
}
extension View {
    func islandSurface(tint: Color = Studio.accent, radius: CGFloat = 22) -> some View {
        modifier(IslandSurface(tint: tint, radius: radius))
    }
}

/// State has both a shape and a color. The ring reports actual progress, not decorative activity.
struct SessionGlyph: View {
    @ObservedObject var model: AppModel
    var size: CGFloat = 24
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var held: Bool { model.state.phase == .paused || model.sleeping }
    private var finished: Bool { model.state.phase == .finished }
    private var tint: Color {
        if model.state.phase == .idle { return Studio.accent }
        return held || model.state.remaining <= 30 && !finished ? Studio.amber : Studio.accent
    }
    private var progress: Double {
        guard let block = model.state.block, block.plannedSeconds > 0 else { return 0 }
        return min(1, max(0, 1 - Double(model.state.remaining) / Double(block.plannedSeconds)))
    }
    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: 2)
            Circle().trim(from: 0, to: finished ? 1 : progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: finished ? "checkmark" : held ? "pause.fill" : "timer")
                .font(.system(size: size * 0.40, weight: .semibold))
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
        }.foregroundStyle(tint).frame(width: size, height: size)
            .phaseAnimator([1.0, 1.22, 1.0], trigger: finished) { content, scale in
                content.scaleEffect(finished && !reduceMotion ? scale : 1)
            } animation: { _ in reduceMotion ? nil : .spring(duration: 0.35) }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: progress)
            .animation(reduceMotion ? nil : Studio.tap, value: held)
            .accessibilityLabel(model.state.phase == .idle ? "Ready to focus" : finished ? "Session complete" : held ? "Timer paused" : "Focus in progress")
    }
}
