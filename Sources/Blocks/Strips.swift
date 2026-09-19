import AppKit
import SwiftUI
import BlocksCore

// The strips: Blocks's surfaces in the notch timer's register, per ADR 0005. Both hang from
// under the notch, both are black and borderless, and both are sized to the job and no larger.
// What they share lives at the bottom of this file.

/// Writing a distraction down, in the notch bar's own language.
///
/// Capture is the smallest thing Blocks asks for: one line, typed without looking away from
/// the work, and gone again. So it is a strip rather than a panel — the same black, the same
/// gentle corners and the same restraint as the bar it hangs beneath, carrying nothing but a
/// label, a field and the two keys that end it. Nothing here is decorative: a distraction
/// arrives mid-thought and the surface that catches it should not be another thing to read.
struct CaptureStripView: View {
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
            WaitingDot(animated: !reduceMotion)
            Text("DISTRACTION")
                .font(.system(size: 9, weight: .bold)).tracking(1.1)
                .foregroundStyle(.white.opacity(0.45))
            FocusedTextField(
                placeholder: "What pulled at you?", text: $state.text,
                onSubmit: submit, onCancel: close, onMove: { _ in false },
                textColor: .white,
                placeholderColor: NSColor.white.withAlphaComponent(0.3),
                font: .systemFont(ofSize: 13, weight: .medium)
            ).frame(height: 20)
            // The one key that matters is the one that is currently live: escape while the
            // field is empty, return as soon as there is something to keep.
            KeyHint(text: typed.isEmpty ? "esc" : "return")
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : Studio.tap, value: typed.isEmpty)
        }
        .padding(.horizontal, 14)
        .frame(width: CaptureStripView.width, height: CaptureStripView.height)
        .background(.black, in: RoundedRectangle(cornerRadius: 11))
        // A hairline so the strip keeps its edges against a black window behind it.
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Capture a distraction")
    }

    private func submit() {
        guard !typed.isEmpty else { return }
        model.capture(typed)
        if model.error == nil { close() }
    }
}

/// The strip is waiting, and says so without words: a slow pulse, the visual equivalent of a
/// held breath. It is the only moving thing on the strip, and it stops moving for anyone who
/// has asked motion to stop.
struct WaitingDot: View {
    let animated: Bool
    @State private var lit = false
    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 5, height: 5)
            .opacity(animated ? (lit ? 0.95 : 0.3) : 0.6)
            .animation(animated ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : nil, value: lit)
            .onAppear { lit = true }
            .accessibilityHidden(true)
    }
}

/// A key named the way the keyboard names it: small, dim, and framed just enough to read as a
/// key rather than as a word in the sentence being typed.
struct KeyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.4))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.08)))
            .accessibilityHidden(true)
    }
}

/// Starting a session, in the same black line as capture.
///
/// The old start prompt was a 520pt centred panel with a heading, a row of project pills, a
/// hint line and two buttons. Everything it did is here, and none of the room it took: the
/// field is the whole of the top line, the two decisions that are allowed to be made at the
/// start moment sit on one footer row as chips, and the distractions captured along the way
/// are offered underneath as rows you can arrow into. It grows only as far as the list, and
/// with nothing captured it is two lines tall.
///
/// The footer is deliberately the *bottom* of the strip. A decision you may ignore belongs
/// below the thing you came to do, not in front of it.
struct StartStripView: View {
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
    /// Four rows is as far as it grows; the rest is scrolled to, by wheel or by arrowing past
    /// the bottom. A list that grew without limit would stop being a strip.
    static let visibleRows = 4
    static func height(rows: Int) -> CGFloat {
        let list = rows == 0 ? 0 : CGFloat(min(rows, visibleRows)) * rowHeight + 12
        return headerHeight + list + footerHeight
    }

    private var typed: String { state.text.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// The distractions captured along the way, narrowed as you type. Naming a project hides
    /// them: the field means something else for those few seconds and the list would be lying.
    private var suggestions: [Distraction] {
        guard !naming else { return [] }
        return model.state.distractions.filter { typed.isEmpty || $0.text.localizedCaseInsensitiveContains(typed) }
    }
    private var length: Int { minutes ?? model.state.preferences.blockMinutes }
    /// Most recently worked in first, which is nearly always the one wanted, with anything else
    /// behind it and no duplicates.
    private var projectChoices: [String] {
        var seen = Set<String>()
        return (model.recentProjects + model.projects).filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    private var canSubmit: Bool { state.highlighted != nil || !typed.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            if !suggestions.isEmpty { list }
            footer
        }
        .frame(width: StartStripView.width, height: StartStripView.height(rows: suggestions.count))
        .background(.black, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .onAppear { resize(StartStripView.height(rows: suggestions.count)) }
        .onChange(of: suggestions.count) { resize(StartStripView.height(rows: suggestions.count)) }
        .onChange(of: state.text) { state.highlighted = nil }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Start a session")
    }

    @ViewBuilder private var header: some View {
        HStack(spacing: 11) {
            WaitingDot(animated: !reduceMotion)
            Text(naming ? "NEW PROJECT" : "FOCUS")
                .font(.system(size: 9, weight: .bold)).tracking(1.1)
                .foregroundStyle(.white.opacity(0.45))
                .contentTransition(.opacity)
            FocusedTextField(
                placeholder: naming ? "Name it" : "What will you work on?", text: $state.text,
                onSubmit: submit, onCancel: cancel, onMove: move,
                textColor: .white,
                placeholderColor: NSColor.white.withAlphaComponent(0.3),
                font: .systemFont(ofSize: 13, weight: .medium)
            )
            .frame(height: 20)
            // A new identity on every mode switch and after every menu, so the caret comes
            // back to the field without anyone having to click it.
            .id("\(naming)-\(caretToken)")
        }
        .padding(.horizontal, 14)
        .frame(height: StartStripView.headerHeight)
    }

    /// Captured distractions, offered back at the one moment they might be what you do next.
    /// Starting one is the list's second exit; the first is resolving it.
    @ViewBuilder private var list: some View {
        VStack(spacing: 0) {
            Divider().overlay(.white.opacity(0.1))
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, item in
                            DistractionRow(item: item, selected: state.highlighted == index) {
                                state.highlighted = index
                                submit()
                            }.id(index)
                        }
                    }.padding(.horizontal, 6).padding(.vertical, 6)
                }
                .frame(height: StartStripView.height(rows: suggestions.count) - StartStripView.headerHeight - StartStripView.footerHeight)
                .onChange(of: state.highlighted) {
                    guard let index = state.highlighted else { return }
                    withAnimation(reduceMotion ? nil : Studio.tap) { scroller.scrollTo(index, anchor: nil) }
                }
            }
        }
    }

    /// The two decisions allowed at the start moment, and the key that ends it.
    @ViewBuilder private var footer: some View {
        HStack(spacing: 8) {
            lengthChip
            projectChip
            Spacer(minLength: 0)
            if !suggestions.isEmpty {
                Text("↑↓").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            }
            KeyHint(text: canSubmit ? "return" : "esc")
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : Studio.tap, value: canSubmit)
        }
        // The same 14 as the header, so the first chip's edge sits under the waiting dot.
        .padding(.horizontal, 14)
        .frame(height: StartStripView.footerHeight)
        .overlay(alignment: .top) { Divider().overlay(.white.opacity(0.08)) }
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
        guard !naming, !suggestions.isEmpty else { return false }
        switch (state.highlighted, delta > 0) {
        case (nil, true): state.highlighted = 0
        case (nil, false): return false
        case (let current?, true): state.highlighted = min(current + 1, suggestions.count - 1)
        case (0, false): state.highlighted = nil
        case (let current?, false): state.highlighted = current - 1
        }
        return true
    }
    private func submit() {
        if naming { endNaming(keeping: typed); return }
        if let index = state.highlighted, suggestions.indices.contains(index) {
            let chosen = suggestions[index]
            model.start(chosen.text, project: state.project, minutes: minutes, resolving: chosen.id)
            if model.error == nil { close() }
            return
        }
        guard !typed.isEmpty else { return }
        model.start(typed, project: state.project, minutes: minutes)
        if model.error == nil { close() }
    }
}

/// One captured distraction, offered as something to do rather than something to dismiss.
private struct DistractionRow: View {
    let item: Distraction
    let selected: Bool
    let choose: () -> Void
    @State private var hovering = false
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(selected ? 0.7 : 0.3))
                .frame(width: 12)
            Text(item.text)
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(selected ? 1 : 0.8))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(item.at, format: .dateTime.weekday(.abbreviated).hour().minute())
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 8)
        .frame(height: StartStripView.rowHeight)
        .background(RoundedRectangle(cornerRadius: 7)
            .fill(.white.opacity(selected ? 0.14 : hovering ? 0.06 : 0)))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: choose)
        .accessibilityLabel("Start a session on \u{201C}\(item.text)\u{201D}")
    }
}

/// A chip in the strips' register: the same shape as the app's light chips, drawn in white on
/// black and dim until it carries a choice. `lit` is what tells a default apart from a decision.
struct DarkChip: View {
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
        .foregroundStyle(.white.opacity(lit ? 0.92 : 0.45))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(lit ? 0.14 : hovering ? 0.08 : 0)))
        .overlay(Capsule().strokeBorder(.white.opacity(lit ? 0 : 0.16), lineWidth: 1))
        .contentShape(Capsule())
        .onHover { hovering = $0 }
        .animation(Studio.tap, value: hovering)
        .animation(Studio.tap, value: lit)
    }
}

/// The start shortcut, pressed while a session is already running.
///
/// It used to do nothing at all — [ADR 0004](../../docs/adr/0004-remove-the-queue.md) took the
/// queue away and left the shortcut silent mid-session. Silence was right about *queueing* and
/// wrong about the key: the moment you reach for "start something" during a session is the
/// moment the session is no longer the thing you are doing, and the two honest answers to that
/// are to stop the clock or to end it. So the shortcut asks which, in two lines.
///
/// Starting another session is deliberately not one of the answers. Abandon returns Blocks to
/// idle, where the shortcut opens the start strip as usual — one keystroke further, and past an
/// explicit ending rather than through it.
struct RunningStripView: View {
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
        _highlighted = State(initialValue: reasoning ? 1 : 0)
    }

    static let width: CGFloat = 460
    static let headerHeight: CGFloat = 44
    static let optionHeight: CGFloat = 34
    static let reasonHeight: CGFloat = 40
    static let footerHeight: CGFloat = 38
    static func height(reasoning: Bool) -> CGFloat {
        headerHeight + optionHeight * 2 + 12 + (reasoning ? reasonHeight : 0) + footerHeight
    }

    private var held: Bool { model.state.phase == .paused || model.sleeping }
    private var options: [(icon: String, title: String)] {
        [held ? ("play.fill", "Resume the timer") : ("pause.fill", "Pause the timer"),
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
        .background(.black, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .onAppear { resize(RunningStripView.height(reasoning: reasoning)) }
        .onChange(of: reasoning) { resize(RunningStripView.height(reasoning: reasoning)) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("This session")
    }

    /// What is about to be paused or ended, and how much of it is left. A destructive choice
    /// should never have to be made from memory.
    @ViewBuilder private var header: some View {
        HStack(spacing: 11) {
            WaitingDot(animated: !reduceMotion)
            Text(held ? "PAUSED" : "RUNNING")
                .font(.system(size: 9, weight: .bold)).tracking(1.1)
                .foregroundStyle(.white.opacity(0.45))
                .contentTransition(.opacity)
            Text(model.state.block?.intent ?? "")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85)).lineLimit(1)
            Spacer(minLength: 8)
            Text(model.clock)
                .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                .foregroundStyle(.white.opacity(held ? 0.5 : 0.9))
        }
        .padding(.horizontal, 14)
        .frame(height: RunningStripView.headerHeight)
    }

    @ViewBuilder private var list: some View {
        VStack(spacing: 0) {
            Divider().overlay(.white.opacity(0.1))
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    // Abandon stays lit while its reason field is open, so the field below
                    // plainly belongs to it rather than floating under both rows.
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
    /// sentence does; escape goes back to the two options rather than closing the strip.
    @ViewBuilder private var reasonField: some View {
        HStack(spacing: 11) {
            // Indented to the option text above it, so it reads as belonging to Abandon.
            Color.clear.frame(width: 18, height: 1)
            FocusedTextField(
                placeholder: "Reason (optional) — Return to abandon", text: $reason,
                onSubmit: abandon, onCancel: { reasoning = false }, onMove: { _ in false },
                textColor: .white,
                placeholderColor: NSColor.white.withAlphaComponent(0.3),
                font: .systemFont(ofSize: 13, weight: .medium)
            ).frame(height: 20).id("reason")
        }
        .padding(.horizontal, 14)
        .frame(height: RunningStripView.reasonHeight)
        .overlay(alignment: .top) { Divider().overlay(.white.opacity(0.08)) }
    }

    @ViewBuilder private var footer: some View {
        HStack(spacing: 8) {
            Text(reasoning ? "Return abandons it. Escape goes back." : "This session is still running.")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                .contentTransition(.opacity)
            Spacer(minLength: 0)
            if !reasoning {
                Text("↑↓").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.25))
            }
            KeyHint(text: "return")
        }
        .padding(.horizontal, 14)
        .frame(height: RunningStripView.footerHeight)
        .overlay(alignment: .top) { Divider().overlay(.white.opacity(0.08)) }
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
        if highlighted == 0 {
            held ? model.resume() : model.hold()
            close()
            return
        }
        // Abandon asks before it acts, and what it asks for is optional.
        reason = ""
        reasoning = true
    }
    private func abandon() {
        model.abandon(reason)
        if model.error == nil { close() }
    }
}

/// One of the two answers, drawn as a row rather than a button: this is a list being arrowed
/// through, and a row that looked like a button would invite the pointer it does not need.
private struct OptionRow: View {
    let icon: String
    let title: String
    let selected: Bool
    let choose: () -> Void
    @State private var hovering = false
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(selected ? 0.9 : 0.4))
                .frame(width: 12)
            Text(title)
                .font(.system(size: 12.5, weight: selected ? .medium : .regular))
                .foregroundStyle(.white.opacity(selected ? 1 : 0.75))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: RunningStripView.optionHeight)
        .background(RoundedRectangle(cornerRadius: 7)
            .fill(.white.opacity(selected ? 0.14 : hovering ? 0.06 : 0)))
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
