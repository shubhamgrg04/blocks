import SwiftUI
import BlocksCore
import Carbon

private let blocksGreen = Studio.accent

struct MenuView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.state.phase == .idle {
                startCallout
                    .animation(reduceMotion ? nil : Studio.settle, value: model.state.phase)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    Label(status, systemImage: model.state.phase == .paused ? "pause.fill" : "circle.fill")
                        .font(Studio.smallMedium).foregroundStyle(Studio.accent)
                        .contentTransition(.opacity)
                    if let block = model.state.block {
                        Text(model.clock).font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit().tracking(-2)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: model.clock)
                        Text(block.intent).font(Studio.title(18)).fixedSize(horizontal: false, vertical: true)
                    }
                    controls
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Studio.lilac, in: RoundedRectangle(cornerRadius: 22))
                    .animation(reduceMotion ? nil : Studio.settle, value: model.state.phase)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Built today").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(model.todayCount) / \(model.state.preferences.dailyTarget) blocks").font(.system(size: 13, weight: .medium)).foregroundStyle(Studio.muted)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : Studio.settle, value: model.todayCount)
                }
                BlockProgress(completed: model.todayCount, target: model.state.preferences.dailyTarget)
            }
            if let error = model.error { Text(error).font(Studio.small).foregroundStyle(.red).textSelection(.enabled) }
            if let error = model.hotkeyError { Text(error).font(Studio.small).foregroundStyle(.orange) }
            upNext
            parked
            HStack {
                Button { model.surfaces.review() } label: { Label("Review your day", systemImage: "rectangle.grid.1x2") }
                    .buttonStyle(FooterButton())
                Spacer()
                Button { model.surfaces.settings() } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(IconButton()).keyboardShortcut(",").help("Settings").accessibilityLabel("Settings")
                Button { model.quit() } label: { Image(systemName: "power") }
                    .buttonStyle(IconButton()).help("Quit; current block is saved").accessibilityLabel("Quit Blocks")
            }.font(.system(size: 13, weight: .medium)).foregroundStyle(Studio.muted)
        }.padding(22).frame(width: 380).studioCanvas()
            .animation(reduceMotion ? nil : Studio.settle, value: model.state.pending.count)
            .animation(reduceMotion ? nil : Studio.settle, value: model.state.parked.count)
    }
    var status: String {
        if model.sleeping { return "Display asleep · timer suspended" }
        switch model.state.phase {
        case .idle: return ""
        case .running: return "Focus in progress"
        case .paused: return "Paused. Take your time."
        case .checking: return "Time served · honesty check"
        }
    }
    /// When nothing is running, the lilac card *is* the start button: every point of it is
    /// clickable, and it carries the two facts a second start needs, the shortcut and the length.
    @ViewBuilder var startCallout: some View {
        let prefs = model.state.preferences
        Button { model.surfaces.prompt(.intent) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .semibold)).foregroundStyle(Studio.accent)
                    Text("Start a new block").font(Studio.title(17)).tracking(-0.3).lineLimit(1)
                    Spacer(minLength: 6)
                    Text(startShortcut).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Studio.muted)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Studio.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                Text("\(prefs.blockMinutes) minutes on one intent").font(Studio.small).foregroundStyle(Studio.muted).lineLimit(1)
                    .padding(.leading, 24)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(HeroButton()).disabled(model.error != nil)
            .accessibilityLabel("Start a new block")
            .accessibilityHint("Press \(startShortcut) from anywhere")
    }
    private var startShortcut: String {
        Studio.shortcut(code: model.state.preferences.startHotkeyCode, modifiers: model.state.preferences.startHotkeyModifiers)
    }
    @ViewBuilder var controls: some View {
        if model.error == nil {
            switch model.state.phase {
            case .idle:
                EmptyView()
            case .running, .paused:
                VStack(spacing: 10) {
                    if model.state.phase == .paused {
                        Button { model.resume() } label: { Label("Resume this block", systemImage: "play.fill").frame(maxWidth: .infinity) }.buttonStyle(StudioButton(primary: true))
                    }
                    HStack {
                        Button(model.state.block?.pauses.isEmpty == true ? "Pause…" : "Stop & reset…") { model.surfaces.prompt(.pause) }.buttonStyle(StudioButton())
                        Spacer()
                        Button("Abandon…") { model.surfaces.prompt(.abandon) }.buttonStyle(FooterButton()).font(Studio.smallMedium).foregroundStyle(Studio.muted)
                    }
                }
            case .checking:
                Button("Show honesty check") { model.surfaces.showTakeover() }.buttonStyle(StudioButton(primary: true))
            }
        }
    }
    /// Pending intents are planned work; they never expire and leave only by being started
    /// here or removed. Kept visually distinct from the parked list directly below it.
    @ViewBuilder var upNext: some View {
        if !model.state.pending.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Up next").font(.system(size: 14, weight: .semibold)).foregroundStyle(blocksGreen)
                    Spacer()
                    Text("\(model.state.pending.count)").font(Studio.smallMedium).foregroundStyle(Studio.muted)
                        .contentTransition(.numericText())
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.state.pending) { item in
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(blocksGreen).frame(width: 16)
                                Text(item.text).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Button { model.removePending(item.id) } label: { Image(systemName: "xmark") }
                                    .buttonStyle(IconButton())
                                    .help("Remove from the queue")
                                    .accessibilityLabel("Remove \u{201C}\(item.text)\u{201D} from the queue")
                            }.studioRow()
                        }
                    }.padding(2)
                }.frame(height: min(180, CGFloat(model.state.pending.count) * 58))
            }
        }
    }
    /// The popover is the only place a parked thought is seen between capture and expiry.
    @ViewBuilder var parked: some View {
        if !model.state.parked.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Parked thoughts").font(.system(size: 14, weight: .semibold)).foregroundStyle(Studio.muted)
                    Spacer()
                    Text("\(model.state.parked.count)").font(Studio.smallMedium).foregroundStyle(Studio.muted)
                        .contentTransition(.numericText())
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.state.parked) { item in
                            HStack(alignment: .center, spacing: 12) {
                                Button { model.resolve(item.id) } label: { Image(systemName: "circle").font(.system(size: 15, weight: .medium)) }
                                    .buttonStyle(IconButton(tint: Studio.accent)).help("Resolve parked item")
                                    .accessibilityLabel("Resolve “\(item.text)”")
                                Text(item.text).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(item.at, style: .time).font(Studio.small).foregroundStyle(Studio.muted)
                            }.studioRow()
                        }
                    }.padding(2)
                }.frame(height: min(210, CGFloat(model.state.parked.count) * 58))
                Text("Unresolved thoughts clear after seven days.").font(Studio.small).foregroundStyle(Studio.muted)
            }
        }
    }
}

/// The idle card as a button: the same lilac surface and radius the timer card uses, so the
/// state change is the contents, not the container. Hover deepens the tint a touch, press sinks
/// it a hair, and nothing else.
struct HeroButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { HeroButtonBody(configuration: configuration) }
}
private struct HeroButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .padding(20)
            .foregroundStyle(Studio.ink)
            .background(Studio.lilac, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).fill(Studio.accent.opacity(hovering && enabled ? 0.06 : 0)))
            .contentShape(RoundedRectangle(cornerRadius: 22))
            .scaleEffect(reduceMotion ? 1 : pressed ? 0.99 : 1)
            .opacity(enabled ? (pressed ? 0.85 : 1) : 0.4)
            .animation(Studio.tap, value: pressed)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Plain text buttons in footers and corners: no chrome, but still a visible nudge under the
/// pointer so they read as controls rather than captions.
struct FooterButton: ButtonStyle {
    var tint: Color = Studio.muted
    func makeBody(configuration: Configuration) -> some View { FooterButtonBody(tint: tint, configuration: configuration) }
}
private struct FooterButtonBody: View {
    let tint: Color
    let configuration: ButtonStyle.Configuration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    var body: some View {
        configuration.label
            .padding(.horizontal, 8).padding(.vertical, 6)
            .foregroundStyle(hovering ? Studio.ink : tint)
            .background(Studio.ink.opacity(hovering ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 8))
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(Studio.tap, value: configuration.isPressed)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
    }
}

enum PromptKind { case intent, queue, pause, abandon, capture }
/// Selection lives in a reference type so the text field's Return and arrow handlers read the
/// current highlight directly, rather than depending on SwiftUI having refreshed the
/// representable's stored closures first.
@MainActor final class PromptState: ObservableObject {
    @Published var text = ""
    @Published var highlighted: Int?
}

struct PromptView: View {
    @ObservedObject var model: AppModel
    let kind: PromptKind
    let close: () -> Void
    @StateObject private var state = PromptState()
    var title: String {
        switch kind {
        case .intent: return "What will you work on?"
        case .queue: return "Line up the next block."
        case .pause: return model.state.block?.pauses.isEmpty == true ? "Why are you pausing?" : "Stop this block?"
        case .abandon: return "Leave an honest record."
        case .capture: return "Park it for later."
        }
    }
    var placeholder: String {
        switch kind {
        case .intent: return "One thing you intend to finish"
        case .queue: return "One thing to pick up next"
        case .capture: return "A few words…"
        case .pause, .abandon: return "Type a reason…"
        }
    }
    var actionTitle: String {
        switch kind {
        case .intent: return "Begin"
        case .queue: return "Queue it"
        case .capture: return "Park"
        case .pause, .abandon: return "Save reason"
        }
    }
    /// Suggestions narrow as you type, so a queue of any size stays reachable without arrowing.
    var suggestions: [PendingIntent] {
        guard kind == .intent else { return [] }
        let query = state.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.state.pending }
        return model.state.pending.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(Studio.title(22)).tracking(-0.5)
            if kind == .pause {
                Text(model.state.block?.pauses.isEmpty == true ? "The timer keeps running until you submit a reason. One pause per block." : "You have used your pause. A second stop resets this block and logs the reason.")
                    .font(.system(size: 13)).foregroundStyle(Studio.muted)
            }
            FocusedTextField(
                placeholder: placeholder, text: $state.text,
                onSubmit: submit, onCancel: close,
                onMove: move
            ).frame(height: 26).padding(14)
                .background(Studio.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Studio.accent.opacity(0.5), lineWidth: 1.5))
            if !suggestions.isEmpty { suggestionList }
            HStack {
                Button("Cancel", action: close).keyboardShortcut(.cancelAction).buttonStyle(StudioButton())
                Spacer()
                // Return is handled by the text field itself, so this button must not also
                // claim .defaultAction — both would fire and submit twice.
                Button(action: submit) { Text(state.highlighted == nil ? actionTitle : "Begin") }
                    .buttonStyle(StudioButton(primary: true))
                    .disabled(state.highlighted == nil && state.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(30).frame(width: 520).studioCanvas()
            .onChange(of: state.text) { state.highlighted = nil }
    }
    @ViewBuilder var suggestionList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("From your queue").font(.system(size: 13, weight: .semibold)).foregroundStyle(Studio.muted)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, item in
                        let selected = state.highlighted == index
                        SuggestionRow(text: item.text, at: item.at, selected: selected) { state.highlighted = index; submit() }
                    }
                }
            }.frame(height: min(180, CGFloat(suggestions.count) * 44))
                .animation(Studio.tap, value: state.highlighted)
            Text("↑↓ to choose, or just type something else.").font(Studio.small).foregroundStyle(Studio.muted)
        }
    }
    /// Returns true when the keystroke belongs to the list rather than the text field: the
    /// field keeps Up at the top of the list, so the caret is never stranded in the suggestions.
    func move(_ delta: Int) -> Bool {
        guard kind == .intent, !suggestions.isEmpty else { return false }
        switch (state.highlighted, delta > 0) {
        case (nil, true): state.highlighted = 0
        case (nil, false): return false
        case (let current?, true): state.highlighted = min(current + 1, suggestions.count - 1)
        case (0, false): state.highlighted = nil
        case (let current?, false): state.highlighted = current - 1
        }
        return true
    }
    func submit() {
        if kind == .intent, let index = state.highlighted, suggestions.indices.contains(index) {
            let chosen = suggestions[index]
            model.start(chosen.text, consuming: chosen.id)
            if model.error == nil { close() }
            return
        }
        let text = state.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        switch kind {
        case .intent: model.start(text)
        case .queue: model.queue(text)
        case .pause: model.stop(text)
        case .abandon: model.abandon(text)
        case .capture: model.park(text)
        }
        if model.error == nil { close() }
    }
}

/// A queued intent offered in the intent prompt. Keyboard highlight and pointer hover share
/// one look so the two ways of choosing never disagree about what is about to be started.
private struct SuggestionRow: View {
    let text: String
    let at: Date
    let selected: Bool
    let choose: () -> Void
    @State private var hovering = false
    var body: some View {
        HStack {
            Text(text).font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
            Text(at, format: .dateTime.weekday(.abbreviated).hour().minute())
                .font(Studio.small).foregroundStyle(Studio.muted)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(selected ? blocksGreen.opacity(0.28) : hovering ? Studio.ink.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .animation(Studio.tap, value: hovering)
        .onHover { hovering = $0 }
        .onTapGesture(perform: choose)
    }
}

/// An NSHostingView builds its subviews *before* it has a window, and SwiftUI does not call
/// `updateNSView` again once the panel appears. Anything that focuses from the SwiftUI side —
/// `@FocusState` in `onAppear`, `defaultFocus`, or a check inside `updateNSView` — therefore
/// runs while `window` is still nil and is silently dropped. Claiming focus as the field
/// enters the window hierarchy is the one moment that is guaranteed to happen.
final class PromptTextField: NSTextField {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window === window else { return }
            window.makeFirstResponder(self)
        }
    }
}

/// SwiftUI's focus system engages for windows SwiftUI itself presents. These prompts are
/// NSHostingViews inside hand-built panels, so Blocks owns the text field and focuses it the
/// same way a click does.
struct FocusedTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onMove: (Int) -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = PromptTextField()
        field.placeholderString = placeholder
        field.isBezeled = false
        field.drawsBackground = false
        field.font = NSFont.systemFont(ofSize: 17, weight: .medium)
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit(_:))
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
    }
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FocusedTextField
        init(_ parent: FocusedTextField) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.cancelOperation(_:)): parent.onCancel(); return true
            case #selector(NSResponder.moveDown(_:)): return parent.onMove(1)
            case #selector(NSResponder.moveUp(_:)): return parent.onMove(-1)
            default: return false
            }
        }
        @objc func submit(_ sender: NSTextField) {
            parent.text = sender.stringValue
            parent.onSubmit()
        }
    }
}

struct TakeoverView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ZStack {
            Studio.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("You set out to").font(.callout).foregroundStyle(Studio.muted)
                        Text(model.state.block?.intent ?? "").font(Studio.title(23)).fixedSize(horizontal: false, vertical: true)
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Studio.surface, in: RoundedRectangle(cornerRadius: 18))
                    Text("Did you do what you intended?").font(.system(size: 16, weight: .medium))
                    HStack(spacing: 12) {
                        answerButton("Yes", key: "y", answer: .yes)
                        answerButton("Partly", key: "p", answer: .partly)
                        answerButton("No", key: "n", answer: .no)
                    }
                    Text("Every honest answer counts toward your day.").font(.callout).foregroundStyle(Studio.muted)
                    Button("Abandon with a reason…") { model.surfaces.prompt(.abandon) }.buttonStyle(FooterButton()).padding(.leading, -8)
                    if let error = model.error { Text(error).foregroundStyle(.red) }
                }.frame(maxWidth: 660).padding(50).frame(maxWidth: .infinity)
            }
        }.studioCanvas()
    }
    func answerButton(_ title: String, key: KeyEquivalent, answer: Honesty) -> some View {
        Button { model.answer(answer) } label: {
            HStack { Text(title); Spacer(); Text(String(key.character).uppercased()).font(Studio.smallMedium).opacity(0.65) }.frame(maxWidth: .infinity)
        }.buttonStyle(StudioButton()).keyboardShortcut(key, modifiers: [])
    }
}

enum ReviewTab: String, CaseIterable, Identifiable {
    case week = "This week", archive = "Archive"
    var id: String { rawValue }
    var key: String { self == .week ? "1" : "2" }
    var shortcut: KeyEquivalent { KeyEquivalent(key.first!) }
}

/// Two tabs: the live week, and the archive of what was parked, resolved, or dropped. The
/// window always opens on the week; the archive is a deliberate detour, never the default.
struct ReviewView: View {
    @ObservedObject var model: AppModel
    @State private var tab: ReviewTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(model: AppModel, tab: ReviewTab = .week) {
        self.model = model
        _tab = State(initialValue: tab)
    }
    private var days: [Date] { (-6...0).map { Calendar.current.date(byAdding: .day, value: $0, to: Date())! } }
    private func count(_ day: Date) -> Int {
        model.history.filter { $0.outcome == .completed && $0.end.map { Calendar.current.isDate($0, inSameDayAs: day) } == true }.count
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The title bar is transparent, so this row sits just below the window controls.
            StudioTabs(selection: $tab).padding(.horizontal, 32).padding(.top, 36).padding(.bottom, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    switch tab {
                    case .week:
                        sparkline
                        today
                        upNext
                        parked
                    case .archive:
                        historical
                    }
                }.padding(.horizontal, 32).padding(.top, 6).padding(.bottom, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(tab)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: tab == .archive ? .trailing : .leading).combined(with: .opacity),
                        removal: .opacity))
                    .animation(reduceMotion ? nil : Studio.settle, value: model.state.pending.count)
                    .animation(reduceMotion ? nil : Studio.settle, value: model.state.parked.count)
            }.clipped()
                .animation(reduceMotion ? .easeOut(duration: 0.15) : Studio.settle, value: tab)
        }.frame(minWidth: 650, minHeight: 560).studioCanvas()
    }

    @ViewBuilder private func section<Content: View>(
        _ title: String, _ count: Int?, tint: Color = .secondary, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(Studio.ink)
                if let count { Text("\(count)").font(Studio.smallMedium).foregroundStyle(Studio.muted).contentTransition(.numericText()) }
            }
            content()
        }
    }

    @ViewBuilder private var sparkline: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Your week, in blocks").font(Studio.title(19))
                Spacer()
                Text("\(days.reduce(0) { $0 + count($1) }) completed").font(.system(size: 13, weight: .medium)).foregroundStyle(Studio.accent)
            }
            let peak = max(1, days.map { count($0) }.max() ?? 1)
            HStack(alignment: .bottom, spacing: 16) {
                ForEach(days, id: \.self) { day in
                    DayBar(day: day, total: count(day), peak: peak)
                }
            }.frame(height: 146, alignment: .bottom)
        }.padding(24).background(Studio.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    /// Today's blocks stay with the sparkline: a count and the things that make it up are one
    /// thought, and splitting them to satisfy the current/historical rule reads worse.
    @ViewBuilder private var today: some View {
        let blocks = model.history.filter { $0.end.map { Calendar.current.isDateInToday($0) } == true }
        section("Today’s blocks", blocks.isEmpty ? nil : blocks.count) {
            if blocks.isEmpty {
                Text("No blocks yet today.").foregroundStyle(Studio.muted)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(blocks.reversed()) { block in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(block.intent).font(.headline)
                                Spacer()
                                Text(block.check?.rawValue.capitalized ?? block.outcome?.rawValue.capitalized ?? "")
                                    .foregroundStyle(block.outcome == .completed ? blocksGreen : .secondary)
                            }
                            Text("\(block.start.formatted(date: .omitted, time: .shortened)) · \(Int(block.plannedSeconds / 60)) min planned").font(Studio.small).foregroundStyle(Studio.muted)
                            if let reason = block.reason { Text(reason).font(.system(size: 13)) }
                            ForEach(Array(block.pauses.enumerated()), id: \.offset) { _, pause in
                                Text("Pause: \(pause.reason) · \(Int(pause.seconds))s").font(Studio.small).foregroundStyle(Studio.muted)
                            }
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Studio.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    @ViewBuilder private var upNext: some View {
        section("Up next", model.state.pending.count, tint: blocksGreen) {
            if model.state.pending.isEmpty {
                Text("Nothing queued. ⇧⌘/ during a block lines up the next one.").foregroundStyle(Studio.muted)
            } else {
                VStack(spacing: 6) {
                    ForEach(model.state.pending) { item in
                        row(icon: "arrow.right", tint: blocksGreen, text: item.text, stamp: item.at) {
                            Button { model.removePending(item.id) } label: { Image(systemName: "xmark") }
                                .buttonStyle(IconButton())
                                .help("Remove from the queue")
                                .accessibilityLabel("Remove \u{201C}\(item.text)\u{201D} from the queue")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var parked: some View {
        section("Parked thoughts", model.state.parked.count) {
            if model.state.parked.isEmpty {
                Text("Nothing parked. ⌘/ captures a distraction without acting on it.").foregroundStyle(Studio.muted)
            } else {
                VStack(spacing: 6) {
                    ForEach(model.state.parked) { item in
                        row(icon: "circle", tint: .secondary, text: item.text, stamp: item.at) {
                            Button("Resolve") { model.resolve(item.id) }
                                .buttonStyle(FooterButton(tint: Studio.accent)).font(Studio.smallMedium)
                                .accessibilityLabel("Resolve \u{201C}\(item.text)\u{201D}")
                        }
                    }
                }
                Text("Unresolved thoughts move to the Archive tab after seven days.").font(Studio.small).foregroundStyle(Studio.muted)
            }
        }
    }

    @ViewBuilder private var historical: some View {
        let archived = model.archivedParked
        let removed = model.removedIntents
        VStack(alignment: .leading, spacing: 30) {
            section("Parked thoughts", archived.isEmpty ? nil : archived.count) {
                if archived.isEmpty {
                    Text("Resolved and expired distractions will appear here.").foregroundStyle(Studio.muted)
                } else {
                    VStack(spacing: 6) {
                        ForEach(archived) { event in
                            row(icon: "tray.full", tint: .secondary, text: event.item.text,
                                stamp: event.archivedAt, note: event.disposition) {
                                Button("Restore") { model.restoreParked(event.item) }
                                    .buttonStyle(FooterButton(tint: Studio.accent)).font(Studio.smallMedium)
                                    .accessibilityLabel("Restore \u{201C}\(event.item.text)\u{201D} to the parked list")
                            }
                        }
                    }
                    Text("Restoring gives a thought a fresh seven days.").font(Studio.small).foregroundStyle(Studio.muted)
                }
            }
            section("Removed intents", removed.isEmpty ? nil : removed.count) {
                if removed.isEmpty {
                    Text("Intents you remove from the queue stay here for thirty days.").foregroundStyle(Studio.muted)
                } else {
                    VStack(spacing: 6) {
                        ForEach(removed) { event in
                            row(icon: "arrow.uturn.left", tint: .secondary, text: event.intent.text,
                                stamp: event.archivedAt, note: "removed") {
                                Button("Restore") { model.restorePending(event.intent) }
                                    .buttonStyle(FooterButton(tint: Studio.accent)).font(Studio.smallMedium)
                                    .accessibilityLabel("Restore \u{201C}\(event.intent.text)\u{201D} to the queue")
                            }
                        }
                    }
                    Text("Removed intents stay restorable for thirty days.").font(Studio.small).foregroundStyle(Studio.muted)
                }
            }
        }
    }

    @ViewBuilder private func row<Trailing: View>(
        icon: String, tint: Color, text: String, stamp: Date, note: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint).frame(width: 16)
            Text(text).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            if let note { Text(note).font(Studio.small).foregroundStyle(Studio.muted) }
            Text(stamp, format: .dateTime.weekday(.abbreviated).hour().minute())
                .font(Studio.small).foregroundStyle(Studio.muted)
            trailing()
        }
        .studioRow()
    }
}

/// A segmented pill in the Studio vocabulary: the selected segment is a solid accent slab that
/// slides between labels, and every segment answers hover and press like the other controls.
struct StudioTabs: View {
    @Binding var selection: ReviewTab
    @Namespace private var slab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ReviewTab.allCases) { tab in
                Button { selection = tab } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(selection == tab ? Color.white : Studio.ink)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background {
                            if selection == tab {
                                RoundedRectangle(cornerRadius: 10).fill(Studio.accent)
                                    .matchedGeometryEffect(id: "slab", in: slab)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(TabSegment())
                .keyboardShortcut(tab.shortcut, modifiers: .command)
                .help(tab.rawValue + "  ⌘" + tab.key)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Studio.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Studio.line, lineWidth: 1))
        .animation(reduceMotion ? nil : Studio.tap, value: selection)
        .accessibilityElement(children: .contain).accessibilityLabel("Review tabs")
    }
}
private struct TabSegment: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { TabSegmentBody(configuration: configuration) }
}
private struct TabSegmentBody: View {
    let configuration: ButtonStyle.Configuration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    var body: some View {
        configuration.label
            .overlay(RoundedRectangle(cornerRadius: 10).fill(Studio.ink.opacity(hovering ? 0.05 : 0)))
            .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.96 : 1)
            .animation(Studio.tap, value: configuration.isPressed)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    private func intBinding(_ key: WritableKeyPath<Preferences, Int>) -> Binding<Int> {
        Binding(get: { model.state.preferences[keyPath: key] }, set: { value in var prefs = model.state.preferences; prefs[keyPath: key] = value; model.setPreferences(prefs) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 14) {
                rhythm("Minutes per block", value: model.state.preferences.blockMinutes, binding: intBinding(\.blockMinutes), range: 1...180, color: Studio.lilac)
                rhythm("Blocks per day", value: model.state.preferences.dailyTarget, binding: intBinding(\.dailyTarget), range: 1...60, color: Studio.peach)
            }
            Text("New block lengths apply to your next block.").font(Studio.small).foregroundStyle(Studio.muted)
                .padding(.top, -14)
            VStack(alignment: .leading, spacing: 16) {
                Text("Shortcuts").font(Studio.title(18))
                HStack {
                    Label("Park a thought", systemImage: "tray")
                    Spacer()
                    HotkeyRecorder(code: model.state.preferences.hotkeyCode, modifiers: model.state.preferences.hotkeyModifiers) { code, modifiers in
                        var prefs = model.state.preferences; prefs.hotkeyCode = code; prefs.hotkeyModifiers = modifiers; model.setPreferences(prefs)
                    }.frame(width: 130, height: 34)
                }
                HStack {
                    Label("Start a block", systemImage: "play")
                    Spacer()
                    HotkeyRecorder(code: model.state.preferences.startHotkeyCode, modifiers: model.state.preferences.startHotkeyModifiers) { code, modifiers in
                        var prefs = model.state.preferences; prefs.startHotkeyCode = code; prefs.startHotkeyModifiers = modifiers; model.setPreferences(prefs)
                    }.frame(width: 130, height: 34)
                }
                Text("Click a shortcut, then press a key with Command, Control, or Option. Escape cancels. During a block, the start shortcut queues your next intent.").font(Studio.small).foregroundStyle(Studio.muted).fixedSize(horizontal: false, vertical: true)
                if let error = model.hotkeyError { Text(error).font(Studio.small).foregroundStyle(.red) }
            }.padding(20).background(Studio.surface, in: RoundedRectangle(cornerRadius: 18))
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield").font(.title2).foregroundStyle(Studio.accent)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Just you and your Mac.").font(.system(size: 14, weight: .semibold))
                    Text("No tracking, no blocking, no accounts. Your data stays here.").font(Studio.small).foregroundStyle(Studio.muted)
                    if let message = model.loginMessage { Text(message).font(Studio.small) }
                    Button("Open data folder") { NSWorkspace.shared.open(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Blocks")) }
                        .buttonStyle(FooterButton(tint: Studio.accent)).font(Studio.smallMedium).padding(.top, 2).padding(.leading, -8)
                }
            }
        }.padding(28).padding(.top, 12).frame(width: 560).studioCanvas()
    }
    private func rhythm(_ title: String, value: Int, binding: Binding<Int>, range: ClosedRange<Int>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Studio.muted)
            HStack {
                Text("\(value)").font(Studio.title(36)).monospacedDigit().contentTransition(.numericText()).animation(Studio.tap, value: value)
                Spacer()
                Stepper(title, value: binding, in: range).labelsHidden().fixedSize()
                    .accessibilityLabel(title).accessibilityValue("\(value)")
            }
        }.padding(18).frame(maxWidth: .infinity).background(color, in: RoundedRectangle(cornerRadius: 18))
    }

}

struct HotkeyRecorder: NSViewRepresentable {
    var code: UInt32
    var modifiers: UInt32
    var changed: (UInt32, UInt32) -> Void
    func makeNSView(context: Context) -> RecorderButton { let view = RecorderButton(); view.changed = changed; return view }
    func updateNSView(_ view: RecorderButton, context: Context) {
        view.changed = changed
        // A running block republishes the model every second, re-rendering this Form.
        // Leaving a recording button untouched keeps it first responder mid-capture.
        guard !view.recording else { return }
        view.code = code; view.modifiers = modifiers; view.updateTitle()
    }
}
final class RecorderButton: NSButton {
    var code: UInt32 = 35
    var modifiers: UInt32 = 768
    var changed: ((UInt32, UInt32) -> Void)?
    var recording = false
    override var acceptsFirstResponder: Bool { true }
    init() { super.init(frame: .zero); bezelStyle = .rounded; target = self; action = #selector(record) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc func record() {
        recording = true
        title = "Press shortcut…"
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
    }
    override func resignFirstResponder() -> Bool {
        if recording { recording = false; updateTitle() }
        return super.resignFirstResponder()
    }
    func updateTitle() {
        title = Studio.shortcut(code: code, modifiers: modifiers)
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { recording = false; updateTitle(); return }
        let flags = event.modifierFlags
        guard !flags.intersection([.command, .control, .option]).isEmpty else { NSSound.beep(); return }
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        recording = false; code = UInt32(event.keyCode); modifiers = mask; updateTitle(); changed?(code, mask)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }; return super.performKeyEquivalent(with: event)
    }
    /// Virtual key codes are layout-independent, so every code Carbon can register has a name.
    static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2", 20: "3",
        21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
        31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return", 37: "L", 38: "J", 39: "'", 40: "K",
        41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`",
        51: "Delete", 53: "Escape", 65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 71: "Clear",
        75: "Keypad /", 76: "Enter", 78: "Keypad -", 81: "Keypad =", 82: "Keypad 0", 83: "Keypad 1",
        84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4", 87: "Keypad 5", 88: "Keypad 6", 89: "Keypad 7",
        91: "Keypad 8", 92: "Keypad 9", 96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
        103: "F11", 105: "F13", 106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help",
        115: "Home", 116: "Page Up", 117: "Forward Delete", 118: "F4", 119: "End", 120: "F2",
        121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]
}

/// One day in the week chart. Under the pointer the bar lifts a touch and the count and label
/// step up in contrast, so the column reads as a thing you are looking at, not just a shape.
private struct DayBar: View {
    let day: Date
    let total: Int
    let peak: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    var body: some View {
        let today = Calendar.current.isDateInToday(day)
        VStack(spacing: 10) {
            Text("\(total)").font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(total > 0 || hovering ? Studio.accent : .secondary)
                .offset(y: hovering && !reduceMotion ? -2 : 0)
            RoundedRectangle(cornerRadius: 8)
                .fill(today ? Studio.accent : Studio.lilac)
                .overlay(RoundedRectangle(cornerRadius: 8).fill(Studio.accent.opacity(hovering && !today ? 0.18 : 0)))
                .frame(height: max(8, CGFloat(total) / CGFloat(peak) * 100))
                .scaleEffect(x: 1, y: hovering && !reduceMotion ? 1.04 : 1, anchor: .bottom)
                .shadow(color: Studio.accent.opacity(hovering ? 0.18 : 0), radius: 6, y: 3)
            Text(day, format: .dateTime.weekday(.abbreviated)).font(Studio.smallMedium)
                .foregroundStyle(hovering ? Studio.ink : Studio.muted)
        }.frame(maxWidth: .infinity)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)): \(total) blocks")
    }
}
