import SwiftUI
import BlocksCore
import Carbon

private let blocksGreen = Studio.accent

struct MenuView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 0) {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("A little focus. A little progress.").font(Studio.title(16))
                Text(model.state.phase == .idle ? "Your next session is a shortcut away." : "One task until the clock runs out.").font(Studio.small).foregroundStyle(Studio.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if model.state.phase == .idle {
                startCallout
                    .animation(reduceMotion ? nil : Studio.settle, value: model.state.phase)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    Label(status, systemImage: statusIcon)
                        .font(Studio.smallMedium).foregroundStyle(Studio.accent)
                        .contentTransition(.opacity)
                    if let block = model.state.block {
                        Text(model.clock).font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit().tracking(-2)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: model.clock)
                        Text(block.intent).font(Studio.title(18)).fixedSize(horizontal: false, vertical: true)
                        // The tag shown is the task's current one, so retagging is reflected
                        // here as well as in reports.
                        let project = model.projectIndex.tag(of: block)
                        if !project.isEmpty { ProjectTag(name: project) }
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
                    Text("\(model.todayCount) / \(model.state.preferences.dailyTarget) sessions").font(.system(size: 13, weight: .medium)).foregroundStyle(Studio.muted)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : Studio.settle, value: model.todayCount)
                }
                BlockProgress(completed: model.todayCount, target: model.state.preferences.dailyTarget)
            }
            if let error = model.error { Text(error).font(Studio.small).foregroundStyle(.red).textSelection(.enabled) }
            if let error = model.hotkeyError { Text(error).font(Studio.small).foregroundStyle(.orange) }
            distractions

        }.padding(22).frame(width: 380)
        }
        Divider()
            HStack {
                Button { model.surfaces.review() } label: { Label("Tasks & reports", systemImage: "rectangle.grid.1x2") }
                    .buttonStyle(FooterButton())
                Spacer()
                Button { model.surfaces.settings() } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(IconButton()).keyboardShortcut(",").help("Settings").accessibilityLabel("Settings")
                Button { model.quit() } label: { Image(systemName: "power") }
                    .buttonStyle(IconButton()).help("Quit; current session is saved").accessibilityLabel("Quit Blocks")
            }.font(.system(size: 13, weight: .medium)).foregroundStyle(Studio.muted).padding(.horizontal, 22).padding(.vertical, 12)
        }.frame(width: 380, height: menuHeight).studioCanvas()
            .animation(reduceMotion ? nil : Studio.settle, value: model.state.distractions.count)
    }
    private var menuHeight: CGFloat {
        let base: CGFloat = model.state.phase == .idle ? 330 : model.state.phase == .paused ? 530 : model.state.phase == .finished ? 520 : 475
        let captured: CGFloat = model.state.distractions.isEmpty ? 0 : 95 + min(210, CGFloat(model.state.distractions.count) * 58)
        return min(base + captured, max(300, (NSScreen.main?.visibleFrame.height ?? 850) - 60))
    }
    var status: String {
        if model.sleeping { return "Display asleep · timer suspended" }
        switch model.state.phase {
        case .idle: return ""
        case .running: return "Focus in progress"
        case .paused: return "Paused. Take your time."
        case .finished: return "Time's up"
        case .checking: return "Saving session"
        }
    }
    private var statusIcon: String {
        switch model.state.phase {
        case .paused: return "pause.fill"
        case .finished: return "checkmark.circle.fill"
        default: return "circle.fill"
        }
    }
    /// The grace countdown reads like the clock above it, so the two numbers on the card are
    /// plainly the same kind of thing: time left before something happens on its own.
    static func countdown(_ seconds: TimeInterval) -> String {
        let whole = Int(ceil(max(0, seconds)))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
    /// When nothing is running, the lilac card *is* the start button: every point of it is
    /// clickable, and it carries the two facts a second start needs, the shortcut and the length.
    @ViewBuilder var startCallout: some View {
        let prefs = model.state.preferences
        Button { model.surfaces.start() } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .semibold)).foregroundStyle(Studio.accent)
                    Text("Start a session").font(Studio.title(17)).tracking(-0.3).lineLimit(1)
                    Spacer(minLength: 6)
                    Text(startShortcut).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Studio.muted)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Studio.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                }
                Text("\(prefs.blockMinutes) minutes on one task").font(Studio.small).foregroundStyle(Studio.muted).lineLimit(1)
                    .padding(.leading, 24)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(HeroButton()).disabled(model.error != nil)
            .accessibilityLabel("Start a session")
            .accessibilityHint("Press \(startShortcut) from anywhere")
    }
    private var startShortcut: String {
        Studio.shortcut(code: model.state.preferences.startHotkeyCode, modifiers: model.state.preferences.startHotkeyModifiers)
    }
    @ViewBuilder var controls: some View {
        VStack(spacing: 10) {
            phaseControls
            // Where the clock lives is a decision worth making mid-session — a bar closed by
            // hand has no other way back, and a session that suddenly wants the screen quiet
            // should not have to go to Settings for it. So the toggle is here for as long as
            // there is a clock to move.
            if model.error == nil, [.running, .paused, .finished].contains(model.state.phase) {
                Button { model.toggleNotchBar() } label: {
                    Label(model.notchBarShowing ? "Hide the notch bar" : "Show the notch bar",
                          systemImage: model.notchBarShowing ? "rectangle.topthird.inset.filled" : "menubar.rectangle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(FooterButton()).font(Studio.smallMedium).foregroundStyle(Studio.muted)
                .help(model.notchBarShowing ? "Send the clock back to the menu bar" : "Put the clock back in the bar at the top of the screen")
            }
        }
    }
    @ViewBuilder private var phaseControls: some View {
        if model.error == nil {
            switch model.state.phase {
            case .idle:
                EmptyView()
            case .running, .paused:
                VStack(spacing: 10) {
                    if model.state.phase == .paused {
                        Button { model.resume() } label: { Label("Resume this session", systemImage: "play.fill").frame(maxWidth: .infinity) }.buttonStyle(StudioButton(primary: true))
                    }
                    HStack {
                        Button(model.state.block?.pauseUsed == false ? "Pause…" : "Stop & reset…") { model.surfaces.prompt(.pause) }.buttonStyle(StudioButton())
                        Spacer()
                        Button("Abandon…") { model.surfaces.prompt(.abandon) }.buttonStyle(FooterButton()).font(Studio.smallMedium).foregroundStyle(Studio.muted)
                    }
                }
            case .finished:
                // The session is not written yet: extending reopens this same record, so the
                // offer has to be answered (or time out) before anything is logged.
                VStack(spacing: 10) {
                    Button { model.extend() } label: {
                        Label("Extend \(Engine.extendMinutes) minutes", systemImage: "plus").frame(maxWidth: .infinity)
                    }.buttonStyle(StudioButton(primary: true))
                        .keyboardShortcut("e", modifiers: [.command, .shift])
                        .help("Add \(Engine.extendMinutes) more minutes to this session")
                    HStack {
                        Button("Finish now") { model.finishNow() }.buttonStyle(StudioButton())
                        Spacer()
                        if let left = model.extendRemaining {
                            Text("Saves itself in \(MenuView.countdown(left))").font(Studio.small).foregroundStyle(Studio.muted)
                                .monospacedDigit().accessibilityLabel("Saves itself in \(Int(left)) seconds")
                        }
                    }
                }
            case .checking:
                EmptyView()
            }
        }
    }
    /// The popover is the only place a distraction is seen between capture and expiry.
    @ViewBuilder var distractions: some View {
        if !model.state.distractions.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Distractions").font(.system(size: 14, weight: .semibold)).foregroundStyle(Studio.muted)
                    Spacer()
                    Text("\(model.state.distractions.count)").font(Studio.smallMedium).foregroundStyle(Studio.muted)
                        .contentTransition(.numericText())
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.state.distractions) { item in
                            HStack(alignment: .center, spacing: 12) {
                                Button { model.resolve(item.id) } label: { Image(systemName: "circle").font(.system(size: 15, weight: .medium)) }
                                    .buttonStyle(IconButton(tint: Studio.accent)).help("Resolve this distraction")
                                    .accessibilityLabel("Resolve “\(item.text)”")
                                Text(item.text).font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(item.at, style: .time).font(Studio.small).foregroundStyle(Studio.muted)
                            }.studioRow()
                        }
                    }.padding(2)
                }.frame(height: min(210, CGFloat(model.state.distractions.count) * 58))
                Text("Unresolved distractions clear after seven days.").font(Studio.small).foregroundStyle(Studio.muted)
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

/// Starting and capturing both have strips of their own now; what is left here are the two
/// prompts that ask for a sentence of explanation, which is more than a strip should hold.
enum PromptKind { case pause, abandon }
/// What a prompt or a strip has been typed into so far, and which suggestion the keyboard is
/// on. A reference type, so the text field's own Return and arrow handlers read the current
/// values directly rather than depending on SwiftUI having refreshed the representable's
/// stored closures first.
@MainActor final class PromptState: ObservableObject {
    @Published var text = ""
    /// The highlighted row of whatever list is being offered, or nil when the caret owns the
    /// keystroke. Only the start strip has a list; the reasoned prompts leave it nil.
    @Published var highlighted: Int?
    @Published var project = ""
}

struct PromptView: View {
    @ObservedObject var model: AppModel
    let kind: PromptKind
    let close: () -> Void
    @StateObject private var state = PromptState()
    var title: String {
        switch kind {
        case .pause: return model.state.block?.pauseUsed == false ? "Why are you pausing?" : "Stop this session?"
        case .abandon: return "Leave this session?"
        }
    }
    var placeholder: String {
        switch kind {
        case .pause: return "Type a reason…"
        case .abandon: return "Type a reason, or leave it blank"
        }
    }
    var actionTitle: String {
        switch kind {
        case .pause: return "Save reason"
        case .abandon: return "Abandon"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(Studio.title(22)).tracking(-0.5)
            if kind == .pause {
                Text(model.state.block?.pauseUsed == false ? "The timer keeps running until you submit a reason. One pause per session." : "You have used your pause. A second stop resets this session and logs the reason.")
                    .font(.system(size: 13)).foregroundStyle(Studio.muted)
            }
            FocusedTextField(
                placeholder: placeholder, text: $state.text,
                onSubmit: submit, onCancel: close,
                onMove: { _ in false }
            ).frame(height: 26).padding(14)
                .background(Studio.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Studio.accent.opacity(0.5), lineWidth: 1.5))
            HStack {
                Button("Cancel", action: close).keyboardShortcut(.cancelAction).buttonStyle(StudioButton())
                Spacer()
                // Return is handled by the text field itself, so this button must not also
                // claim .defaultAction — both would fire and submit twice.
                Button(action: submit) { Text(actionTitle) }
                    .buttonStyle(StudioButton(primary: true))
                    // Abandoning needs no reason; pausing does, because the typing *is* the
                    // pause's mechanism rather than a note attached to it.
                    .disabled(kind != .abandon && state.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(30).frame(width: 520).studioCanvas()
    }
    func submit() {
        let text = state.text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .pause:
            guard !text.isEmpty else { return }
            model.stop(text)
        case .abandon:
            model.abandon(text)
        }
        if model.error == nil { close() }
    }
}

/// An NSHostingView builds its subviews *before* it has a window, and SwiftUI does not call
/// `updateNSView` again once the panel appears. Anything that focuses from the SwiftUI side —
/// `@FocusState` in `onAppear`, `defaultFocus`, or a check inside `updateNSView` — therefore
/// runs while `window` is still nil and is silently dropped. Claiming focus as the field
/// enters the window hierarchy is the one moment that is guaranteed to happen.
final class PromptTextField: NSTextField {
    /// The field editor is shared and arrives with the last styling it was given, so a strip
    /// that draws white on black has to claim the caret colour as it takes focus. Without
    /// this the caret is the system's dark one, invisible on the strip.
    override func becomeFirstResponder() -> Bool {
        let claimed = super.becomeFirstResponder()
        if claimed, let editor = currentEditor() as? NSTextView {
            editor.insertionPointColor = textColor ?? .textColor
        }
        return claimed
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window === window else { return }
            window.makeFirstResponder(self)
            // Focus selects the whole value by default. The strips re-focus this field after a
            // menu closes, and selecting what was already typed would mean the next keystroke
            // wiped it — so the caret goes to the end instead.
            self.currentEditor()?.selectedRange = NSRange(location: self.stringValue.count, length: 0)
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
    /// The prompts take the system's own colours; the capture strip draws itself on black and
    /// has to say so, placeholder included — a placeholder left to the system is grey on black.
    var textColor: NSColor?
    var placeholderColor: NSColor?
    var font: NSFont?

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSTextField {
        let field = PromptTextField()
        if let placeholderColor {
            field.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: placeholderColor, .font: font ?? NSFont.systemFont(ofSize: 17, weight: .medium)])
        } else {
            field.placeholderString = placeholder
        }
        field.isBezeled = false
        field.drawsBackground = false
        field.font = font ?? NSFont.systemFont(ofSize: 17, weight: .medium)
        if let textColor { field.textColor = textColor }
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
        // The start strip's field is borrowed to name a project, so the placeholder changes
        // under a field that is already on screen; setting it only at build time would leave
        // the old prompt showing.
        if placeholderColor == nil, field.placeholderString != placeholder {
            field.placeholderString = placeholder
        }
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

enum ReviewTab: String, CaseIterable, Identifiable {
    case week = "Reports", tasks = "Tasks", archive = "Archive"
    var id: String { rawValue }
    var key: String { self == .week ? "1" : self == .tasks ? "2" : "3" }
    var shortcut: KeyEquivalent { KeyEquivalent(key.first!) }
}

/// Reports, tasks, and archive keep historical sessions separate from ongoing work.
struct ReviewView: View {
    @ObservedObject var model: AppModel
    @State private var tab: ReviewTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(model: AppModel, tab: ReviewTab = .week) {
        self.model = model
        _tab = State(initialValue: tab)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The title bar is transparent, so this row sits just below the window controls.
            StudioTabs(selection: $tab).padding(.horizontal, 32).padding(.top, 36).padding(.bottom, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    switch tab {
                    case .week:
                        ReportsView(model: model)
                    case .tasks:
                        TaskShelf(model: model)
                        distractions
                    case .archive:
                        historical
                    }
                }.padding(.horizontal, 32).padding(.top, 6).padding(.bottom, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(tab)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: tab == .archive ? .trailing : .leading).combined(with: .opacity),
                        removal: .opacity))
                    .animation(reduceMotion ? nil : Studio.settle, value: model.state.distractions.count)
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

    @ViewBuilder private var distractions: some View {
        section("Distractions", model.state.distractions.count) {
            if model.state.distractions.isEmpty {
                Text("Nothing captured. ⌘/ writes a distraction down instead of acting on it.").foregroundStyle(Studio.muted)
            } else {
                VStack(spacing: 6) {
                    ForEach(model.state.distractions) { item in
                        row(icon: "circle", tint: .secondary, text: item.text, stamp: item.at) {
                            Button("Resolve") { model.resolve(item.id) }
                                .buttonStyle(FooterButton(tint: Studio.accent)).font(Studio.smallMedium)
                                .accessibilityLabel("Resolve \u{201C}\(item.text)\u{201D}")
                        }
                    }
                }
                Text("Unresolved distractions move to the Archive tab after seven days.").font(Studio.small).foregroundStyle(Studio.muted)
            }
        }
    }

    @ViewBuilder private var historical: some View {
        let archived = model.archivedDistractions
        VStack(alignment: .leading, spacing: 30) {
            section("Distractions", archived.isEmpty ? nil : archived.count) {
                if archived.isEmpty {
                    Text("Resolved and expired distractions will appear here.").foregroundStyle(Studio.muted)
                } else {
                    VStack(spacing: 6) {
                        ForEach(archived) { event in
                            row(icon: "tray.full", tint: .secondary, text: event.item.text,
                                stamp: event.archivedAt, note: event.disposition) {
                                Button("Restore") { model.restoreDistraction(event.item) }
                                    .buttonStyle(FooterButton(tint: Studio.accent)).font(Studio.smallMedium)
                                    .accessibilityLabel("Restore \u{201C}\(event.item.text)\u{201D} to the live list")
                            }
                        }
                    }
                    Text("Restoring gives a distraction a fresh seven days.").font(Studio.small).foregroundStyle(Studio.muted)
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
                                RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.145, green: 0.424, blue: 0.408))
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
    /// Said plainly, because the point of the setting is that the two clocks never run at once.
    private var notchModeExplanation: String {
        switch model.state.preferences.notchTimerMode {
        case .bar: return "A black bar sits at the top of the screen during a session, grown out of the notch where there is one."
        case .menuBar: return "The menu bar carries the clock on its own."
        }
    }

    @ObservedObject var model: AppModel
    private func intBinding(_ key: WritableKeyPath<Preferences, Int>) -> Binding<Int> {
        Binding(get: { model.state.preferences[keyPath: key] }, set: { value in var prefs = model.state.preferences; prefs[keyPath: key] = value; model.setPreferences(prefs) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 14) {
                rhythm("Minutes per session", value: model.state.preferences.blockMinutes, binding: intBinding(\.blockMinutes), range: Preferences.lengthRange, color: Studio.lilac)
                rhythm("Sessions per day", value: model.state.preferences.dailyTarget, binding: intBinding(\.dailyTarget), range: 1...60, color: Studio.peach)
            }
            // Each caption sits under the control it belongs to rather than collecting at the
            // bottom of the pane as a paragraph of small print.
            Text("This length is the default every session starts with. Changing it here applies to your next session; a running one keeps the length it started with. Sessions finish quietly — start again whenever you’re ready.").font(Studio.small).foregroundStyle(Studio.muted).fixedSize(horizontal: false, vertical: true)
                .padding(.top, -14)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Session clock").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker("Session clock", selection: Binding(get: { model.state.preferences.notchTimerMode }, set: { value in
                        var prefs = model.state.preferences; prefs.notchTimerMode = value; model.setPreferences(prefs)
                    })) {
                        Text("Notch bar").tag(NotchTimerMode.bar)
                        Text("Menu bar").tag(NotchTimerMode.menuBar)
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 200)
                }
                Text(notchModeExplanation + " The clock is only ever in one place: while the bar is up the menu bar keeps its icon and drops the digits. Closing the bar mid-session hands the clock back to the menu bar, and the menu can call it up again.").font(Studio.small).foregroundStyle(Studio.muted).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 16) {
                Text("Shortcuts").font(Studio.title(18))
                HStack {
                    Label("Capture a distraction", systemImage: "tray")
                    Spacer()
                    HotkeyRecorder(code: model.state.preferences.hotkeyCode, modifiers: model.state.preferences.hotkeyModifiers) { code, modifiers in
                        var prefs = model.state.preferences; prefs.hotkeyCode = code; prefs.hotkeyModifiers = modifiers; model.setPreferences(prefs)
                    }.frame(width: 130, height: 34)
                }
                HStack {
                    Label("Start a session", systemImage: "play")
                    Spacer()
                    HotkeyRecorder(code: model.state.preferences.startHotkeyCode, modifiers: model.state.preferences.startHotkeyModifiers) { code, modifiers in
                        var prefs = model.state.preferences; prefs.startHotkeyCode = code; prefs.startHotkeyModifiers = modifiers; model.setPreferences(prefs)
                    }.frame(width: 130, height: 34)
                }
                HStack {
                    Label("Extend a finished session", systemImage: "plus.circle")
                    Spacer()
                    HotkeyRecorder(code: model.state.preferences.extendHotkeyCode, modifiers: model.state.preferences.extendHotkeyModifiers) { code, modifiers in
                        var prefs = model.state.preferences; prefs.extendHotkeyCode = code; prefs.extendHotkeyModifiers = modifiers; model.setPreferences(prefs)
                    }.frame(width: 130, height: 34)
                }
                Text("Click a shortcut, then press a key with Command, Control, or Option. Escape cancels. The start shortcut only opens while nothing is running; the extend shortcut works for \(Int(Engine.extendWindow / 60)) minutes after a session ends.").font(Studio.small).foregroundStyle(Studio.muted).fixedSize(horizontal: false, vertical: true)
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
