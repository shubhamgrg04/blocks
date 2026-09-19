import SwiftUI
import BlocksCore

/// Projects are the quiet layer of Blocks: a session is about one task, and the tag is only
/// there so the weeks add up into something readable later. Everything here is therefore small
/// — a dot, a chip, a row of pills — and never asks for a decision before a session can start.
enum Projects {
    /// Colour follows the name, not its position in a list, so a project keeps the same colour
    /// as others come and go and the bars in a report mean the same thing week to week.
    private static let palette: [Color] = [
        Studio.adaptive(0x256C68, 0xA4D4C9), // the brand teal, first in line
        Studio.adaptive(0x3C6C9C, 0x9CC2E8),
        Studio.adaptive(0xA06636, 0xE3B184),
        Studio.adaptive(0x7A4E86, 0xCBA6D8),
        Studio.adaptive(0xA34C5B, 0xE7A3AD),
        Studio.adaptive(0x5B7A3A, 0xB6D191),
        Studio.adaptive(0x2F7A86, 0x9AD2DC),
        Studio.adaptive(0x8A6A2F, 0xD9C286)
    ]
    /// Swift's own hashing is seeded per process, so a project would change colour on every
    /// launch. djb2 over the scalars is stable across launches and machines.
    private static func preferred(_ name: String) -> Int {
        var hash: UInt64 = 5381
        for scalar in name.lowercased().unicodeScalars { hash = hash &* 33 &+ UInt64(scalar.value) }
        return Int(hash % UInt64(palette.count))
    }
    @MainActor private static var assigned: [String: Int] = [:]
    /// Two projects landing on the same hue would make a stacked bar unreadable, so the live
    /// set is laid out once: each name takes the colour it prefers, and a name that finds its
    /// colour taken walks to the next free one. The result depends on the set of projects, not
    /// on the order they were created, so it is the same on every launch and moves only when a
    /// project is added or renamed into a collision.
    @MainActor static func register(_ names: [String]) {
        var taken = Set<Int>()
        var map: [String: Int] = [:]
        for name in names.sorted() {
            var slot = preferred(name)
            var tries = 0
            while taken.contains(slot), tries < palette.count { slot = (slot + 1) % palette.count; tries += 1 }
            taken.insert(slot); map[name] = slot
        }
        assigned = map
    }
    @MainActor static func color(_ name: String) -> Color {
        guard !name.isEmpty, name != ProjectIndex.untagged else { return Studio.muted.opacity(0.55) }
        return palette[assigned[name] ?? preferred(name)]
    }
}

/// The smallest possible statement that a session belongs somewhere.
struct ProjectDot: View {
    let name: String
    var size: CGFloat = 7
    var body: some View {
        Circle().fill(Projects.color(name)).frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A read-only tag: dot, name, nothing else. Used wherever a session or task is being shown
/// rather than edited.
struct ProjectTag: View {
    let name: String
    var body: some View {
        HStack(spacing: 6) {
            ProjectDot(name: name)
            Text(name.isEmpty ? ProjectIndex.untagged : name).lineLimit(1)
        }.font(Studio.small).foregroundStyle(Studio.muted)
    }
}

/// One control for assigning a project, wherever the assigning happens: the start prompt, the
/// task shelf, a row in the session timeline. It reads as a chip rather than a form field, so
/// it can sit at the end of a line without claiming one of its own.
struct ProjectPicker: View {
    @Binding var selection: String
    let projects: [String]
    /// A chip with no project yet shows a tag outline instead of a filled dot, so an untagged
    /// row reads as an invitation rather than as a project called "none".
    var placeholder = "Project"
    @State private var naming = false
    @State private var draft = ""
    @State private var hovering = false
    var body: some View {
        Menu {
            Button { selection = "" } label: { Text("No project") }
            if !projects.isEmpty {
                Divider()
                ForEach(projects, id: \.self) { name in
                    Button { selection = name } label: { Label(name, systemImage: selection == name ? "checkmark" : "circle.fill") }
                }
            }
            Divider()
            Button("New project…") { draft = ""; naming = true }
        } label: {
            HStack(spacing: 6) {
                if selection.isEmpty {
                    Image(systemName: "tag").font(.system(size: 10))
                } else {
                    ProjectDot(name: selection, size: 8)
                }
                Text(selection.isEmpty ? placeholder : selection).lineLimit(1)
            }
            .font(Studio.smallMedium)
            .foregroundStyle(selection.isEmpty ? Studio.muted : Studio.ink)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(chipFill, in: Capsule())
            .overlay(Capsule().strokeBorder(selection.isEmpty ? Studio.line : .clear, lineWidth: 1))
        }
        // `.borderlessButton` flattens a custom label down to its text, which would drop the
        // dot and the chip's fill; the button style keeps the label as drawn.
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .onHover { hovering = $0 }
        .animation(Studio.tap, value: selection)
        .popover(isPresented: $naming, arrowEdge: .bottom) {
            HStack(spacing: 8) {
                TextField("Project name", text: $draft).textFieldStyle(.plain).frame(width: 160).onSubmit(commit)
                Button("Add", action: commit).buttonStyle(StudioButton(primary: true)).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(12).studioCanvas()
        }
        .accessibilityLabel(selection.isEmpty ? "Assign a project" : "Project: \(selection)")
    }
    private var chipFill: Color {
        if selection.isEmpty { return hovering ? Studio.ink.opacity(0.05) : .clear }
        return Projects.color(selection).opacity(hovering ? 0.32 : 0.2)
    }
    private func commit() {
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        selection = name
        naming = false
    }
}

/// The start prompt's version: the projects worked in most recently are offered as pills, so
/// the common case — this session belongs where the last few did — is one click and no menu.
/// Everything else falls back to the same picker used elsewhere.
struct ProjectPills: View {
    @Binding var selection: String
    let recent: [String]
    let all: [String]
    /// Three is as many as fit beside the picker without the row competing with the intent
    /// field above it. A pill already chosen is kept in view even if it has aged out.
    private var offered: [String] {
        var names = Array(recent.prefix(3))
        if !selection.isEmpty, !names.contains(selection) { names = [selection] + names.prefix(2) }
        return names
    }
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(offered.enumerated()), id: \.element) { index, name in
                Button { selection = selection == name ? "" : name } label: { Text(name).lineLimit(1) }
                    .buttonStyle(ProjectPill(name: name, selected: selection == name))
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                    .help("⌘\(index + 1) — tag this session \(name)")
            }
            ProjectPicker(selection: $selection, projects: all, placeholder: offered.isEmpty ? "Project" : "More")
            Spacer(minLength: 0)
        }
    }
}

/// A pill is the same chip as the picker, in a form that toggles rather than opens.
private struct ProjectPill: ButtonStyle {
    let name: String
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View { ProjectPillBody(name: name, selected: selected, configuration: configuration) }
}
private struct ProjectPillBody: View {
    let name: String
    let selected: Bool
    let configuration: ButtonStyle.Configuration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    var body: some View {
        HStack(spacing: 6) {
            ProjectDot(name: name, size: 7).opacity(selected ? 1 : 0.45)
            configuration.label
        }
        .font(Studio.smallMedium)
        .foregroundStyle(selected ? Studio.ink : Studio.muted)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Projects.color(name).opacity(selected ? 0.22 : hovering ? 0.1 : 0), in: Capsule())
        .overlay(Capsule().strokeBorder(selected ? Projects.color(name).opacity(0.5) : Studio.line, lineWidth: 1))
        .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.96 : 1)
        .animation(Studio.tap, value: selected)
        .animation(Studio.tap, value: hovering)
        .onHover { hovering = $0 }
    }
}
