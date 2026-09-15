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
    static let canvas = adaptive(0xF6F7FC, 0x202235)
    static let surface = adaptive(0xFFFFFF, 0x2B2E45)
    static let ink = adaptive(0x242744, 0xF3F2FC)
    static let accent = adaptive(0x4149DB, 0xB5B8FF)
    static let lilac = adaptive(0xE8E5FF, 0x3C3B63)
    static let peach = adaptive(0xFFE2D3, 0x564038)
    static let muted = adaptive(0x656980, 0xB6B9D1)
    static let line = adaptive(0xDDDFF0, 0x464961)
    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
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

/// Buttons answer the pointer twice: a lift on hover says "this is clickable", a small sink on
/// press says "that registered". Both are skipped when the user has asked for reduced motion.
struct StudioButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        StudioButtonBody(primary: primary, configuration: configuration)
    }
}
private struct StudioButtonBody: View {
    let primary: Bool
    let configuration: ButtonStyle.Configuration
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    var body: some View {
        let pressed = configuration.isPressed
        configuration.label.font(.system(size: 13, weight: .semibold, design: .rounded))
            .padding(.horizontal, 16).padding(.vertical, 11)
            .foregroundStyle(primary ? Color.white : Studio.ink)
            .background(primary ? Color(red: 0.255, green: 0.286, blue: 0.86) : Studio.surface,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(primary ? .clear : Studio.line, lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(hovering && enabled ? (primary ? 0.1 : 0.4) : 0)))
            .shadow(color: Studio.accent.opacity(primary && hovering && enabled ? 0.28 : 0), radius: 10, y: 4)
            .scaleEffect(reduceMotion ? 1 : pressed ? 0.965 : hovering && enabled ? 1.015 : 1)
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
    @State private var hovering = false
    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(hovering ? Studio.ink : tint)
            .frame(width: 28, height: 28)
            .background(Circle().fill(Studio.ink.opacity(hovering ? 0.08 : 0)))
            .contentShape(Circle())
            .scaleEffect(reduceMotion ? 1 : pressed ? 0.85 : hovering ? 1.08 : 1)
            .animation(Studio.tap, value: pressed)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
    }
}

/// A list row that reads as one clickable object: roomy padding, a surface that brightens
/// under the pointer, and a gentle settle when it appears or leaves.
struct StudioRow: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Studio.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(hovering ? Studio.accent.opacity(0.35) : Studio.line.opacity(0.6), lineWidth: 1))
            .shadow(color: Studio.ink.opacity(hovering ? 0.08 : 0.03), radius: hovering ? 8 : 2, y: hovering ? 3 : 1)
            .scaleEffect(reduceMotion || !hovering ? 1 : 1.01)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
            .transition(reduceMotion ? .opacity : Studio.rowTransition)
    }
}
extension View {
    func studioRow() -> some View { modifier(StudioRow()) }
}

struct BlockProgress: View {
    let completed: Int
    let target: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: min(target, 12)), spacing: 5) {
            ForEach(0..<target, id: \.self) { index in
                let filled = index < completed
                RoundedRectangle(cornerRadius: 4)
                    .fill(filled ? Studio.accent : Studio.line.opacity(0.7)).frame(height: 12)
                    .scaleEffect(filled || reduceMotion ? 1 : 0.9)
                    // Each newly filled cell pops a beat after the one before it.
                    .animation(Studio.settle.delay(filled ? Double(index) * 0.04 : 0), value: completed)
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(completed) of \(target) blocks completed today")
    }
}

extension View {
    func studioCanvas() -> some View {
        self.font(.system(size: 13)).foregroundStyle(Studio.ink).tint(Studio.accent).background(Studio.canvas)
    }
}
