import AppKit
import SwiftUI
import BlocksCore

// The strips: Blocks's surfaces in the notch timer's register, per ADR 0005. Both hang from
// under the notch, both are black and borderless, and both are sized to the job and no larger.
// What they share lives at the bottom of this file.

/// Writing a queued task down, in the notch bar's own language.
///
/// Capture is the smallest thing Blocks asks for: one line, typed without looking away from
/// the work, and gone again. So it is a strip rather than a panel — the same black, the same
/// gentle corners and the same restraint as the bar it hangs beneath, carrying nothing but a
/// label, a field and the two keys that end it.
struct CaptureStripView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var model: AppModel
    let close: () -> Void
    @StateObject private var state = PromptState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Wide enough for a sentence, narrow enough to read as a strip rather than a window.
    static let width: CGFloat = 460
    static let height: CGFloat = 44

    private var typed: String { state.text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 15, weight: .medium)).foregroundStyle(palette.lavender)
                .accessibilityHidden(true)
            FocusedTextField(
                placeholder: "Add a task for later", text: $state.text,
                onSubmit: submit, onCancel: close, onMove: { _ in false },
                textColor: NSColor(palette.ink),
                placeholderColor: NSColor(palette.muted),
                font: .systemFont(ofSize: 13, weight: .medium)
            ).frame(height: 20)
            // The one key that matters is the one that is currently live: escape while the
            // field is empty, return as soon as there is something to keep.
            KeyHint(text: typed.isEmpty ? "esc" : "↵")
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : Studio.tap, value: typed.isEmpty)
        }
        .padding(.horizontal, 18)
        .frame(width: CaptureStripView.width, height: CaptureStripView.height)
        .captureSurface(tint: palette.lavender)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Add to To do")
    }

    private func submit() {
        guard !typed.isEmpty else { return }
        model.enqueue(typed)
        if model.error == nil { close() }
    }
}

/// A key named the way the keyboard names it: small, dim, and framed just enough to read as a
/// key rather than as a word in the sentence being typed.
struct KeyHint: View {
    @Environment(\.studioPalette) private var palette
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(palette.ink.opacity(0.65))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(palette.ink.opacity(0.08)))
            .accessibilityHidden(true)
    }
}

/// Starting a session, in the same black line as capture.
///
/// The old start prompt was a 520pt centred panel with a heading, a row of project pills, a
/// hint line and two buttons. Everything it did is here, and none of the room it took: the
/// field is the whole of the top line, the two decisions that are allowed to be made at the
/// start moment sit on one footer row as chips. Recent work comes first, followed by the
/// queue, with rows you can arrow into. With neither history nor a queue it is two lines tall.
///
/// The footer is deliberately the *bottom* of the strip. A decision you may ignore belongs
/// below the thing you came to do, not in front of it.
struct StartStripView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var model: AppModel
    let close: () -> Void
    /// The strip changes height as the list filters, and the panel is told rather than asked:
    /// the row count is known here, so the window never has to guess at a fitting size.
    var resize: (CGFloat) -> Void = { _ in }
    @StateObject private var state = PromptState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// This session's length, or nil for whatever Settings says. Never written back.
    @State private var minutes: Int?
    /// The field borrows itself to name a new project rather than opening a second surface —
    /// one field, one caret, one place to look.
    @State private var naming = false
    @State private var stashedIntent = ""
    /// Bumped whenever the caret has to be taken back from a menu. Used as the field's identity,
    /// so SwiftUI rebuilds it and `viewDidMoveToWindow` claims focus again.
    @State private var caretToken = 0

    static let width: CGFloat = 460
    static let headerHeight: CGFloat = 44
    static let footerHeight: CGFloat = 38
    static let rowHeight: CGFloat = 30
    /// Show recent work and the beginning of the queue; scroll longer lists.
    static let visibleRows = 7
    static func height(rows: Int, sections: Int = 0) -> CGFloat {
        let list = rows == 0 ? 0 : CGFloat(min(rows, visibleRows)) * rowHeight + CGFloat(sections) * 22 + 12
        return headerHeight + list + footerHeight
    }

    static func initialHeight(model: AppModel) -> CGFloat {
        height(rows: model.recentTasks.count + model.pendingTasks.count + (model.state.phase == .finished ? 1 : 0),
               sections: (model.recentTasks.isEmpty ? 0 : 1) + (model.pendingTasks.isEmpty ? 0 : 1))
    }
    private var recent: [FocusTask] {
        guard !naming else { return [] }
        return model.recentTasks.filter { typed.isEmpty || $0.title.localizedCaseInsensitiveContains(typed) }
    }
    private var sectionCount: Int { (recent.isEmpty ? 0 : 1) + (suggestions.isEmpty ? 0 : 1) }
    private var listHeight: CGFloat { Self.height(rows: rowCount, sections: sectionCount) }
    private var suggestionCount: Int { recent.count + suggestions.count }

    private var typed: String { state.text.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// The queued tasks captured along the way, narrowed as you type. Naming a project hides
    /// them: the field means something else for those few seconds and the list would be lying.
    private var suggestions: [QueuedTask] {
        guard !naming else { return [] }
        return model.pendingTasks.filter { typed.isEmpty || $0.title.localizedCaseInsensitiveContains(typed) }
    }
    // Index -1 is the extension, followed by recent work and then queued tasks.
    private var offersExtension: Bool { model.state.phase == .finished && typed.isEmpty && !naming }
    private var rowCount: Int { suggestionCount + (offersExtension ? 1 : 0) }
    private var firstRow: Int { offersExtension ? -1 : 0 }
    private var length: Int { minutes ?? model.state.preferences.blockMinutes }
    /// Most recently worked in first, which is nearly always the one wanted, with anything else
    /// behind it and no duplicates.
    private var projectChoices: [String] {
        var seen = Set<String>()
        return (model.recentProjects + model.projects).filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    private var selectedQueuedIndex: Int? {
        guard !naming, let index = state.highlighted,
              suggestions.indices.contains(index - recent.count) else { return nil }
        return index - recent.count
    }
    private var canSubmit: Bool { state.highlighted != nil || !typed.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            if rowCount > 0 { list }
            footer
        }
        .frame(width: StartStripView.width, height: listHeight)
        .captureSurface()
        .onAppear {
            state.highlighted = offersExtension ? -1 : nil
            resize(listHeight)
        }
        .onChange(of: listHeight) { resize(listHeight) }
        .onChange(of: suggestionCount) {
            if let index = state.highlighted, index >= suggestionCount { state.highlighted = nil }
        }
        .onChange(of: offersExtension) { state.highlighted = offersExtension ? -1 : nil }
        .onChange(of: state.text) { state.highlighted = offersExtension ? -1 : nil }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Start a session")
    }

    @ViewBuilder private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: naming ? "tag.fill" : "scope")
                .font(.system(size: 16, weight: .medium)).foregroundStyle(palette.accent)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace)).accessibilityHidden(true)
            FocusedTextField(
                placeholder: naming ? "Name it" : "What will you work on?", text: $state.text,
                onSubmit: submit, onCancel: cancel, onMove: move, onDelete: deleteSelectedTask,
                textColor: NSColor(palette.ink),
                placeholderColor: NSColor(palette.muted),
                font: .systemFont(ofSize: 13, weight: .medium)
            )
            .frame(height: 20)
            // A new identity on every mode switch and after every menu, so the caret comes
            // back to the field without anyone having to click it.
            .id("\(naming)-\(caretToken)")
        }
        .padding(.horizontal, 18)
        .frame(height: StartStripView.headerHeight)
    }

    /// Captured queued tasks, offered back at the one moment they might be what you do next.
    /// Starting one moves it from To do into its focus session.
    @ViewBuilder private var list: some View {
        VStack(spacing: 0) {
            Divider().overlay(palette.ink.opacity(0.1))
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(spacing: 0) {
                        if offersExtension {
                            OptionRow(icon: "plus.circle", title: "Extend by \(model.state.preferences.blockMinutes) minutes",
                                      selected: state.highlighted == -1, height: Self.rowHeight) {
                                state.highlighted = -1
                                submit()
                            }.id(-1)
                        }
                        if !recent.isEmpty {
                            sectionLabel("Recent")
                            ForEach(Array(recent.enumerated()), id: \.element.id) { index, item in
                                OptionRow(icon: "clock.arrow.circlepath", title: item.title,
                                          selected: state.highlighted == index, height: Self.rowHeight) {
                                    state.highlighted = index
                                    submit()
                                }.id(index)
                            }
                        }
                        if !suggestions.isEmpty {
                            sectionLabel("Queue")
                            ForEach(Array(suggestions.enumerated()), id: \.element.id) { offset, item in
                                let index = recent.count + offset
                                QueuedTaskRow(item: item, selected: state.highlighted == index) {
                                    state.highlighted = index
                                    submit()
                                }.id(index)
                            }
                        }
                    }.padding(.horizontal, 6).padding(.vertical, 6)
                }
                .frame(height: listHeight - StartStripView.headerHeight - StartStripView.footerHeight)
                .onChange(of: state.highlighted) {
                    guard let index = state.highlighted else { return }
                    withAnimation(reduceMotion ? nil : Studio.tap) { scroller.scrollTo(index, anchor: nil) }
                }
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .semibold))
            .foregroundStyle(palette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(height: 22)
    }

    /// The two decisions allowed at the start moment, and the key that ends it.
    @ViewBuilder private var footer: some View {
        HStack(spacing: 8) {
            lengthChip
            projectChip
            Spacer(minLength: 0)
            if rowCount > 0 {
                Text("↑↓").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.muted.opacity(0.8))
            }
            if selectedQueuedIndex != nil { KeyHint(text: "⌫") }
            KeyHint(text: canSubmit ? "↵" : "esc")
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : Studio.tap, value: canSubmit)
        }
        // The same 14 as the header, so the first chip's edge sits under the waiting dot.
        .padding(.horizontal, 18)
        .frame(height: StartStripView.footerHeight)
        .overlay(alignment: .top) { Divider().overlay(palette.ink.opacity(0.08)) }
    }

    /// The length is already decided — Settings decided it — so this chip states it rather than
    /// asking. Overriding it marks the chip, because a session that is not the usual length is
    /// worth being able to see at a glance.
    @ViewBuilder private var lengthChip: some View {
        Menu {
            Button {
                minutes = nil; caretToken += 1
            } label: { Text("Default · \(model.state.preferences.blockMinutes) min") }
            Divider()
            ForEach([15, 25, 45, 60, 90], id: \.self) { option in
                Button { minutes = option; caretToken += 1 } label: {
                    Label("\(option) min", systemImage: length == option ? "checkmark" : "circle.fill")
                }
            }
            Divider()
            Button("Change the default in Settings…") { close(); model.surfaces.settings() }
        } label: {
            DarkChip(icon: "timer", text: "\(length)m", lit: minutes != nil)
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .help("How long this session runs. The default lives in Settings.")
        .accessibilityLabel("Session length, \(length) minutes")
    }

    @ViewBuilder private var projectChip: some View {
        Menu {
            Button { state.project = ""; caretToken += 1 } label: { Text("No project") }
            if !projectChoices.isEmpty {
                Divider()
                ForEach(projectChoices, id: \.self) { name in
                    Button { state.project = name; caretToken += 1 } label: {
                        Label(name, systemImage: state.project == name ? "checkmark" : "circle.fill")
                    }
                }
            }
            Divider()
            Button("New project…") { beginNaming() }
        } label: {
            DarkChip(icon: state.project.isEmpty ? "tag" : nil,
                     dot: state.project.isEmpty ? nil : state.project,
                     text: state.project.isEmpty ? "Project" : state.project,
                     lit: !state.project.isEmpty)
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .accessibilityLabel(state.project.isEmpty ? "Assign a project" : "Project: \(state.project)")
    }

    private func beginNaming() {
        stashedIntent = state.text
        state.text = ""
        state.highlighted = nil
        naming = true
    }
    private func endNaming(keeping name: String?) {
        if let name, !name.isEmpty { state.project = name }
        state.text = stashedIntent
        naming = false
    }
    /// Escape backs out of naming a project before it closes the strip, so the field being
    /// borrowed is never a trap.
    private func cancel() {
        if naming { endNaming(keeping: nil); return }
        close()
    }
    /// Returns true when the keystroke belongs to the list rather than the field. Up at the top
    /// of the list returns the caret to the text, so it is never stranded in the suggestions.
    private func move(_ delta: Int) -> Bool {
        guard !naming, rowCount > 0 else { return false }
        switch (state.highlighted, delta > 0) {
        case (nil, true): state.highlighted = firstRow
        case (nil, false): return false
        case (let current?, true): state.highlighted = min(current + 1, suggestionCount - 1)
        case (let current?, false) where current == firstRow: state.highlighted = nil
        case (let current?, false): state.highlighted = current - 1
        }
        return true
    }
    /// Delete acts on a queue row only while keyboard navigation has selected it.
    /// Keep the next (or previous last) queue row selected for repeated deletion.
    private func deleteSelectedTask() -> Bool {
        guard let index = selectedQueuedIndex else { return false }
        model.removeQueuedTask(suggestions[index].id)
        if model.error == nil {
            state.highlighted = suggestions.isEmpty ? nil : recent.count + min(index, suggestions.count - 1)
        }
        return true
    }

    private func submit() {
        if naming { endNaming(keeping: typed); return }
        if offersExtension, state.highlighted == -1 {
            model.extend(minutes: model.state.preferences.blockMinutes)
            if model.error == nil { close() }
            return
        }
        if let index = state.highlighted, recent.indices.contains(index) {
            let chosen = recent[index]
            model.start(chosen.title, project: state.project.isEmpty ? chosen.project : state.project, minutes: minutes)
            if model.error == nil { close() }
            return
        }
        if let index = state.highlighted, suggestions.indices.contains(index - recent.count) {
            let chosen = suggestions[index - recent.count]
            model.start(chosen.title, project: state.project, minutes: minutes, queuedID: chosen.id)
            if model.error == nil { close() }
            return
        }
        guard !typed.isEmpty else { return }
        model.start(typed, project: state.project, minutes: minutes)
        if model.error == nil { close() }
    }
}

/// One captured queued task, offered as something to do rather than something to dismiss.
private struct QueuedTaskRow: View {
    @Environment(\.studioPalette) private var palette
    let item: QueuedTask
    let selected: Bool
    let choose: () -> Void
    @State private var hovering = false
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(palette.ink.opacity(selected ? 0.9 : 0.6))
                .frame(width: 12)
            Text(item.title)
                .font(.system(size: 12.5))
                .foregroundStyle(palette.ink.opacity(selected ? 1 : 0.8))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(item.createdAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                .font(.system(size: 10)).foregroundStyle(palette.muted)
        }
        .padding(.horizontal, 8)
        .frame(height: StartStripView.rowHeight)
        .background(RoundedRectangle(cornerRadius: 7)
            .fill(selected ? palette.accent.opacity(0.14) : palette.ink.opacity(hovering ? 0.06 : 0)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: choose)
        .accessibilityLabel("Start a session on \u{201C}\(item.title)\u{201D}")
    }
}

/// A chip in the strips' register: the same shape as the app's light chips, drawn in white on
/// black and dim until it carries a choice. `lit` is what tells a default apart from a decision.
struct DarkChip: View {
    @Environment(\.studioPalette) private var palette
    var icon: String?
    var dot: String?
    let text: String
    var lit = false
    @State private var hovering = false
    var body: some View {
        HStack(spacing: 5) {
            if let dot { ProjectDot(name: dot, size: 7) }
            if let icon { Image(systemName: icon).font(.system(size: 9, weight: .semibold)) }
            Text(text).lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(lit ? palette.accent : palette.muted)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(palette.ink.opacity(lit ? 0.14 : hovering ? 0.08 : 0)))
        .overlay(Capsule().strokeBorder(palette.ink.opacity(lit ? 0 : 0.16), lineWidth: 1))
        .contentShape(Capsule())
        .onHover { hovering = $0 }
        .animation(Studio.tap, value: hovering)
        .animation(Studio.tap, value: lit)
    }
}

/// The running session's keyboard action list: complete, pause/resume, extend, notch visibility,
/// and abandon. Destructive work stays last and asks for an optional reason.
struct RunningStripView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var model: AppModel
    let close: () -> Void
    var resize: (CGFloat) -> Void = { _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlighted: Int
    /// True once Abandon has been chosen and the strip is waiting for the optional reason.
    @State private var reasoning: Bool
    @State private var reason = ""

    /// `reasoning` is only ever passed by the design previews, which need to draw the second
    /// state without a keystroke. The same shape `ReviewView` uses for its opening tab.
    init(model: AppModel, close: @escaping () -> Void, resize: @escaping (CGFloat) -> Void = { _ in }, reasoning: Bool = false) {
        self.model = model
        self.close = close
        self.resize = resize
        _reasoning = State(initialValue: reasoning)
        _highlighted = State(initialValue: reasoning ? Action.abandon.rawValue : Action.complete.rawValue)
    }

    static let width: CGFloat = 460
    static let headerHeight: CGFloat = 44
    private enum Action: Int, CaseIterable { case complete, pause, extend, notch, abandon }
    static let optionHeight: CGFloat = 34
    static let reasonHeight: CGFloat = 40
    static let footerHeight: CGFloat = 38
    static func height(reasoning: Bool) -> CGFloat {
        headerHeight + optionHeight * CGFloat(Action.allCases.count) + 12 + (reasoning ? reasonHeight : 0) + footerHeight
    }

    private var held: Bool { model.state.phase == .paused || model.sleeping }
    private var options: [(icon: String, title: String)] {
        [("checkmark.circle", "Mark task complete"),
         held ? ("play.fill", "Resume the timer") : ("pause.fill", "Pause the timer"),
         ("plus.circle", "Extend by \(Engine.extendMinutes) minutes"),
         (model.notchBarShowing ? "rectangle.topthird.inset.filled" : "menubar.rectangle",
          model.notchBarShowing ? "Hide notch bar" : "Show notch bar"),
         ("xmark", "Abandon this session")]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            list
            if reasoning { reasonField }
            footer
        }
        .frame(width: RunningStripView.width, height: RunningStripView.height(reasoning: reasoning))
        .islandSurface()
        .onAppear { resize(RunningStripView.height(reasoning: reasoning)) }
        .onChange(of: reasoning) { resize(RunningStripView.height(reasoning: reasoning)) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("This session")
    }

    /// What is about to be paused or ended, and how much of it is left. A destructive choice
    /// should never have to be made from memory.
    @ViewBuilder private var header: some View {
        HStack(spacing: 11) {
            SessionGlyph(model: model)
            Text(model.state.block?.intent ?? "")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.ink.opacity(0.85)).lineLimit(1)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(model.clock) left")
                    .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(held ? palette.amber : palette.accent)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.clock)
                Text("\(model.totalSessionTime) total").font(.system(size: 10)).foregroundStyle(palette.muted)
            }.fixedSize().accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 18)
        .frame(height: RunningStripView.headerHeight)
    }

    @ViewBuilder private var list: some View {
        VStack(spacing: 0) {
            Divider().overlay(palette.ink.opacity(0.1))
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    // Abandon stays lit while its reason field is open, so the field below
                    // plainly belongs to it rather than floating under unrelated actions.
                    OptionRow(icon: option.icon, title: option.title,
                              selected: highlighted == index) {
                        highlighted = index
                        choose()
                    }
                }
            }.padding(.horizontal, 6).padding(.vertical, 6)
            // The keys live on the list while there is no field to hold them. Only one of the
            // two is ever in the window, so whichever appears claims focus as it arrives.
            if !reasoning {
                KeyCatcher(onKey: key).frame(width: 0, height: 0).id("options")
            }
        }
    }

    /// Optional, and it says so. Return with nothing typed abandons exactly as Return with a
    /// sentence does; escape goes back to the actions rather than closing the strip.
    @ViewBuilder private var reasonField: some View {
        HStack(spacing: 11) {
            // Indented to the option text above it, so it reads as belonging to Abandon.
            Color.clear.frame(width: 18, height: 1)
            FocusedTextField(
                placeholder: "Reason (optional) — Return to abandon", text: $reason,
                onSubmit: abandon, onCancel: { reasoning = false }, onMove: { _ in false },
                textColor: NSColor(palette.ink),
                placeholderColor: NSColor(palette.muted),
                font: .systemFont(ofSize: 13, weight: .medium)
            ).frame(height: 20).id("reason")
        }
        .padding(.horizontal, 18)
        .frame(height: RunningStripView.reasonHeight)
        .overlay(alignment: .top) { Divider().overlay(palette.ink.opacity(0.08)) }
    }

    @ViewBuilder private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: reasoning ? "arrow.uturn.backward" : "keyboard")
                .font(.system(size: 11)).foregroundStyle(palette.muted)
                .accessibilityHidden(true)
            KeyHint(text: "esc")
            Spacer(minLength: 0)
            if !reasoning {
                Text("↑↓").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.muted.opacity(0.8))
            }
            KeyHint(text: "↵")
        }
        .padding(.horizontal, 18)
        .frame(height: RunningStripView.footerHeight)
        .overlay(alignment: .top) { Divider().overlay(palette.ink.opacity(0.08)) }
    }

    /// Arrow keys, Return and Escape while the options have the keyboard. Every other key is
    /// swallowed rather than passed on, so a strip this size never answers a keystroke with a beep.
    private func key(_ code: UInt16) -> Bool {
        switch code {
        case 126: highlighted = max(0, highlighted - 1)                       // up
        case 125: highlighted = min(options.count - 1, highlighted + 1)       // down
        case 36, 76: choose()                                                 // return, enter
        case 53: close()                                                      // escape
        default: break
        }
        return true
    }
    private func choose() {
        guard let action = Action(rawValue: highlighted) else { return }
        switch action {
        case .complete:
            model.completeTask()
            if model.error == nil { close() }
        case .pause:
            held ? model.resume() : model.hold()
            if model.error == nil { close() }
        case .extend:
            model.extendTimer()
            if model.error == nil { close() }
        case .notch:
            model.toggleNotchBar()
            close()
        case .abandon:
            reason = ""
            reasoning = true
        }
    }
    private func abandon() {
        model.abandon(reason)
        if model.error == nil { close() }
    }
}

/// A session action, drawn as a row rather than a button: this is a list being arrowed
/// through, and a row that looked like a button would invite the pointer it does not need.
private struct OptionRow: View {
    @Environment(\.studioPalette) private var palette
    let icon: String
    let title: String
    let selected: Bool
    var height: CGFloat = RunningStripView.optionHeight
    let choose: () -> Void
    @State private var hovering = false
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(palette.ink.opacity(selected ? 0.9 : 0.4))
                .frame(width: 12)
            Text(title)
                .font(.system(size: 12.5, weight: selected ? .medium : .regular))
                .foregroundStyle(palette.ink.opacity(selected ? 1 : 0.75))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: 7)
            .fill(selected ? palette.accent.opacity(0.14) : palette.ink.opacity(hovering ? 0.06 : 0)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: choose)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(title)
    }
}

/// A strip with a list and no field still has to own the keyboard. This is the smallest thing
/// that can: an invisible view that claims first responder the moment it enters the window —
/// the same moment `PromptTextField` uses, and for the same reason — and hands key codes back.
struct KeyCatcher: NSViewRepresentable {
    let onKey: (UInt16) -> Bool
    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onKey = onKey
        return view
    }
    func updateNSView(_ view: KeyCatcherView, context: Context) { view.onKey = onKey }
}

final class KeyCatcherView: NSView {
    var onKey: (UInt16) -> Bool = { _ in false }
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window === window else { return }
            window.makeFirstResponder(self)
        }
    }
    /// Unhandled keys are dropped rather than passed to `super`, which would answer them with
    /// the system beep. A two-line strip has nothing to say about the letter you typed.
    override func keyDown(with event: NSEvent) { _ = onKey(event.keyCode) }
}
