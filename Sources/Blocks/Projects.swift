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
        guard !name.isEmpty, name != ProjectIndex.untagged else { return Color(nsColor: .secondaryLabelColor) }
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
    @Environment(\.studioPalette) private var palette
    let name: String
    var body: some View {
        HStack(spacing: 6) {
            ProjectDot(name: name)
            Text(name.isEmpty ? ProjectIndex.untagged : name).lineLimit(1)
        }.font(Studio.small).foregroundStyle(palette.muted)
    }
}

/// One control for assigning a project, wherever the assigning happens: a row
/// in the session timeline. The start strip draws its own in the strips' dark register. It reads as a chip rather than a form field, so
/// it can sit at the end of a line without claiming one of its own.
struct ProjectPicker: View {
    @Environment(\.studioPalette) private var palette
    @Binding var selection: String
    let projects: [String]
    /// A chip with no project yet shows a tag outline instead of a filled dot, so an untagged
    /// row reads as an invitation rather than as a project called "none".
    var placeholder = "Project"
    @State private var naming = false
    @FocusState private var nameFocused: Bool
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
            .foregroundStyle(selection.isEmpty ? palette.muted : palette.ink)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(chipFill, in: Capsule())
            .overlay(Capsule().strokeBorder(selection.isEmpty ? palette.line : .clear, lineWidth: 1))
        }
        // `.borderlessButton` flattens a custom label down to its text, which would drop the
        // dot and the chip's fill; the button style keeps the label as drawn.
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .onHover { hovering = $0 }
        .animation(Studio.tap, value: selection)
        .popover(isPresented: $naming, arrowEdge: .bottom) {
            HStack(spacing: 8) {
                TextField("Project name", text: $draft).textFieldStyle(.plain).frame(width: 160).focused($nameFocused).onSubmit(commit)
                Button("Add", action: commit).buttonStyle(StudioButton(primary: true)).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(12).studioCanvas().onAppear { nameFocused = true }.onExitCommand { naming = false }
        }
        .accessibilityLabel(selection.isEmpty ? "Assign a project" : "Project: \(selection)")
    }
    private var chipFill: Color {
        if selection.isEmpty { return hovering ? palette.ink.opacity(0.05) : .clear }
        return Projects.color(selection).opacity(hovering ? 0.32 : 0.2)
    }
    private func commit() {
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        selection = name
        naming = false
    }
}
