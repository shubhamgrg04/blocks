import SwiftUI
import AppKit
import Carbon
import BlocksCore

/// Semantic colors keep the compact timer, native fields, and larger windows in one theme.
struct StudioPalette {
    let canvas, surface, raised, island: Color
    let ink, muted, accent, lavender, amber, line, onAccent: Color

    init(_ theme: AppTheme) {
        let values: [UInt32]
        switch theme {
        case .midnight:
            values = [0x07090B, 0x111416, 0x161B1D, 0x000000, 0xF0F0F0, 0xA1A1A1,
                      0xA6D6C4, 0xBAB0E3, 0xE8BD7A, 0x333333, 0x10251E]
        case .ocean:
            values = [0x080B10, 0x11171F, 0x18222C, 0x070A0E, 0xE7F0FA, 0xA0B5CC,
                      0x8DCCEF, 0xB9BAF2, 0xE6C085, 0x2F3C4B, 0x102537]
        case .ember:
            values = [0x0D0A09, 0x191411, 0x231B17, 0x0A0807, 0xF4EBE4, 0xC0ACA0,
                      0xEAAF87, 0xDBA9C0, 0xE6C875, 0x40342D, 0x352116]
        }
        let colors = values.map { Color(nsColor: NSColor(srgbRed: CGFloat(($0 >> 16) & 255) / 255,
                                                        green: CGFloat(($0 >> 8) & 255) / 255,
                                                        blue: CGFloat($0 & 255) / 255, alpha: 1)) }
        canvas = colors[0]; surface = colors[1]; raised = colors[2]; island = colors[3]
        ink = colors[4]; muted = colors[5]; accent = colors[6]; lavender = colors[7]
        amber = colors[8]; line = colors[9]; onAccent = colors[10]
    }
}

private struct StudioPaletteKey: EnvironmentKey {
    static let defaultValue = StudioPalette(.midnight)
}
extension EnvironmentValues {
    var studioPalette: StudioPalette {
        get { self[StudioPaletteKey.self] }
        set { self[StudioPaletteKey.self] = newValue }
    }
}

extension AppTheme {
    var appearance: NSAppearance? { NSAppearance(named: .darkAqua) }
    var colorScheme: ColorScheme { .dark }
}

/// Changing the environment preserves drafts, keyboard focus, and the selected report period.
struct ThemedView<Content: View>: View {
    @ObservedObject var model: AppModel
    let content: Content
    var body: some View {
        let theme = model.state.preferences.theme
        content
            .environment(\.studioPalette, StudioPalette(theme))
            .environment(\.colorScheme, theme.colorScheme)
            .preferredColorScheme(theme.colorScheme)
            .tint(StudioPalette(theme).accent)
    }
}
extension View {
    func themed(model: AppModel) -> ThemedView<Self> { ThemedView(model: model, content: self) }
}

enum Studio {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
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
    @Environment(\.studioPalette) private var palette
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
            .foregroundStyle(primary ? palette.onAccent : palette.ink)
            .background(primary ? palette.accent : palette.surface,
                        in: RoundedRectangle(cornerRadius: compact ? 8 : 12))
            .overlay(RoundedRectangle(cornerRadius: compact ? 8 : 12).strokeBorder(focused ? palette.ink : primary ? .clear : palette.line, lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: compact ? 8 : 12).fill(palette.ink.opacity(hovering && enabled ? (primary ? 0.1 : 0.06) : 0)))
            .opacity(enabled ? (pressed ? 0.85 : 1) : 0.4)
            .animation(Studio.tap, value: pressed)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Small icon-only controls (remove, resolve) get a generous circular hit area and the same
/// hover/press response as full buttons, so they never feel like a target you have to aim for.
struct IconButton: ButtonStyle {
    var tint: Color? = nil
    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(tint: tint, configuration: configuration)
    }
}
private struct IconButtonBody: View {
    @Environment(\.studioPalette) private var palette
    let tint: Color?
    let configuration: ButtonStyle.Configuration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var focused
    @State private var hovering = false
    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(hovering ? palette.ink : (tint ?? palette.muted))
            .frame(width: 28, height: 28)
            .background(Circle().fill(palette.ink.opacity(hovering ? 0.08 : 0)))
            .contentShape(Circle())
            .overlay(Circle().strokeBorder(focused ? palette.ink : .clear, lineWidth: 1))
            .animation(Studio.tap, value: pressed)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Compact rows use a hairline separator without moving their hit targets on hover.
struct StudioRow: ViewModifier {
    @Environment(\.studioPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(hovering ? palette.accent.opacity(0.35) : palette.line.opacity(0.6), lineWidth: 1))
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
            .transition(reduceMotion ? .opacity : Studio.rowTransition)
    }
}
extension View {
    func studioRow() -> some View { modifier(StudioRow()) }
}

struct FocusProgress: View {
    @Environment(\.studioPalette) private var palette
    let seconds: Double
    let targetSeconds: Double
    var height: CGFloat = 12
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var fraction: Double { min(1, max(0, seconds / max(1, targetSeconds))) }
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 4).fill(palette.line.opacity(0.7))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(palette.accent)
                        .frame(width: geometry.size.width * fraction)
                }
        }.frame(height: height)
            .animation(reduceMotion ? nil : Studio.settle, value: fraction)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Daily focus goal")
            .accessibilityValue("\(focusTime(seconds)) of \(focusTime(targetSeconds)) focused today")
    }
}

private struct StudioCanvas: ViewModifier {
    @Environment(\.studioPalette) private var palette
    func body(content: Content) -> some View {
        content.font(.system(size: 13)).foregroundStyle(palette.ink)
            .tint(palette.accent).background(palette.canvas)
    }
}
extension View {
    func studioCanvas() -> some View { modifier(StudioCanvas()) }
}

/// The compact and expanded islands share concentric edges and a faint state-colored rim.
struct IslandSurface: ViewModifier {
    @Environment(\.studioPalette) private var palette
    var tint: Color?
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(palette.island, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(LinearGradient(colors: [(tint ?? palette.accent).opacity(0.30), palette.ink.opacity(0.07)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }
}
extension View {
    func islandSurface(tint: Color? = nil, radius: CGFloat = 22) -> some View {
        modifier(IslandSurface(tint: tint, radius: radius))
    }

    /// A static rim for the two keyboard capture surfaces.
    func captureSurface(tint: Color? = nil) -> some View {
        islandSurface(tint: tint)
    }
}

/// State has both a shape and a color. The ring reports actual progress, not decorative activity.
struct SessionGlyph: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var model: AppModel
    var size: CGFloat = 24
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var held: Bool { model.state.phase == .paused || model.sleeping }
    private var finished: Bool { model.state.phase == .finished }
    private var tint: Color {
        if model.state.phase == .idle { return palette.accent }
        return held || model.state.remaining <= 30 && !finished ? palette.amber : palette.accent
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
