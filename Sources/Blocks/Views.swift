import SwiftUI
import BlocksCore
import Carbon

struct MenuView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var model: AppModel
    @State private var actionHelp: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "timer").foregroundStyle(palette.accent)
                Text("Blocks").font(Studio.title(12))
                Spacer()
                Button { model.toggleNotchBar() } label: {
                    Image(systemName: model.notchBarShowing ? "rectangle.topthird.inset.filled" : "menubar.rectangle")
                }.buttonStyle(IconButton())
                    .disabled(model.error != nil)
                    .help(model.notchBarShowing ? "Hide notch bar" : "Show notch bar")
                    .accessibilityLabel(model.notchBarShowing ? "Hide notch bar" : "Show notch bar")
                if [.running, .paused, .finished].contains(model.state.phase) {
                    SessionGlyph(model: model)
                }
            }
            if model.state.phase == .idle {
                startCallout
                    .animation(reduceMotion ? nil : Studio.settle, value: model.state.phase)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let block = model.state.block {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(block.intent).font(.system(size: 13, weight: .medium))
                                    .lineLimit(2).help(block.intent)
                                let project = model.projectIndex.tag(of: block)
                                if !project.isEmpty {
                                    Text(project).font(.system(size: 11)).foregroundStyle(palette.muted)
                                        .lineLimit(1).help(project)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(model.clock)
                                    .foregroundStyle(model.state.phase == .paused ? palette.amber : palette.accent)
                                    .font(.system(size: 26, weight: .semibold)).monospacedDigit().tracking(-0.7)
                                    .contentTransition(.numericText(countsDown: true))
                                    .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: model.clock)
                                Text("left / \(model.totalSessionTime) total")
                                    .font(.system(size: 10)).foregroundStyle(palette.muted)
                            }.fixedSize()
                        }
                    }
                    controls
                }
                .animation(reduceMotion ? nil : Studio.settle, value: model.state.phase)
                .zIndex(1)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Today").font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("\(focusTime(model.todayFocusSeconds)) / \(model.state.preferences.dailyFocusHours)h focus")
                        .font(.system(size: 11)).foregroundStyle(palette.muted)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : Studio.settle, value: model.todayFocusSeconds)
                }
                FocusProgress(seconds: model.todayFocusSeconds, targetSeconds: model.dailyFocusTargetSeconds, height: 4)
            }
            if let error = model.error { Text(error).font(Studio.small).foregroundStyle(.red).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) }
            if let error = model.hotkeyError { Text(error).font(Studio.small).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true) }
            taskQueue

        }.padding(.horizontal, 20).padding(.vertical, 16).frame(width: 380)
            .frame(maxHeight: .infinity, alignment: .top)
        Divider()
            HStack(spacing: 8) {
                Button { model.surfaces.review() } label: { HStack { Text("Reports & To do"); KeyHint(text: "⌘1") } }
                    .keyboardShortcut("1")
                    .buttonStyle(FooterButton())
                Spacer()
                Button { model.surfaces.settings() } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(IconButton()).keyboardShortcut(",").help("Settings · ⌘,").accessibilityLabel("Settings")
                Button { model.quit() } label: { Image(systemName: "power") }
                    .buttonStyle(IconButton()).help("Quit; current session is saved").accessibilityLabel("Quit Blocks")
            }.font(.system(size: 12, weight: .medium)).foregroundStyle(palette.muted).padding(.horizontal, 12).padding(.vertical, 12)
        }.frame(width: 380, height: menuHeight).studioCanvas()
            .animation(reduceMotion ? nil : Studio.settle, value: model.pendingTasks.count)
    }
    var menuHeight: CGFloat {
        // Reserve space for section gaps and the padded footer, plus up to three task rows.
        // Only the task list scrolls; session controls and footer actions stay in place.
        let base: CGFloat = model.state.phase == .idle ? 242 : model.state.phase == .finished ? 304 : 308
        let captured = CGFloat(max(1, min(3, model.pendingTasks.count))) * 36
        let errors = [model.error, model.hotkeyError].compactMap { $0 }.reduce(CGFloat.zero) { height, message in
            let bounds = (message as NSString).boundingRect(
                with: NSSize(width: 340, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: NSFont.systemFont(ofSize: 12)])
            return height + ceil(bounds.height) + 12
        }
        return min(base + captured + errors, max(220, (NSScreen.main?.visibleFrame.height ?? 850) - 60))
    }
    /// The grace countdown reads like the clock above it, so the two numbers on the card are
    /// plainly the same kind of thing: time left before something happens on its own.
    static func countdown(_ seconds: TimeInterval) -> String {
        let whole = Int(ceil(max(0, seconds)))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
    /// Starting is one compact row, with the default length still visible before opening it.
    @ViewBuilder var startCallout: some View {
        Button { model.surfaces.start() } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").foregroundStyle(palette.accent)
                Text("Start a session")
                Spacer(minLength: 6)
                Text("\(model.state.preferences.blockMinutes)m").foregroundStyle(palette.muted)
                KeyHint(text: startShortcut)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(StudioButton(compact: true)).disabled(model.error != nil)
            .help("Start a session")
            .accessibilityLabel("Start a session")
            .accessibilityHint("Press \(startShortcut) from anywhere")
    }
    private var startShortcut: String {
        Studio.shortcut(code: model.state.preferences.startHotkeyCode, modifiers: model.state.preferences.startHotkeyModifiers)
    }
    @ViewBuilder var controls: some View {
        phaseControls
            .overlay(alignment: .bottomLeading) {
                if let actionHelp {
                    Text(actionHelp)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(palette.raised, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(palette.line, lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(y: 30)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .zIndex(1)
            .onChange(of: model.state.phase) { actionHelp = nil }
            .onDisappear { actionHelp = nil }
    }
    private func sessionAction(_ icon: String, _ description: String, tint: Color? = nil,
                               action: @escaping () -> Void) -> some View {
        SessionActionButton(icon: icon, description: description, tint: tint ?? palette.muted,
                            hoveredDescription: $actionHelp, action: action)
    }
    @ViewBuilder private var phaseControls: some View {
        if model.error == nil {
            switch model.state.phase {
            case .idle:
                EmptyView()
            case .running, .paused:
                HStack(spacing: 4) {
                    sessionAction("checkmark.circle", "Mark task complete", tint: palette.accent) { model.completeTask() }
                    if model.state.phase == .paused {
                        sessionAction("play.fill", "Resume the timer") { model.resume() }
                            .keyboardShortcut("r")
                    } else {
                        sessionAction("pause.fill", model.state.block?.pauseUsed == false
                                      ? "Pause the session with a reason" : "Stop and reset the session") {
                            model.surfaces.prompt(.pause)
                        }
                    }
                    sessionAction("xmark.circle", "Abandon this session…") { model.surfaces.prompt(.abandon) }
                    sessionAction("plus.circle", "Extend the session by \(Engine.extendMinutes) minutes") { model.extendTimer() }
                    Spacer(minLength: 0)
                }
            case .finished:
                HStack(spacing: 4) {
                    sessionAction("checkmark.circle", "Finish now and save the session", tint: palette.accent) { model.finishNow() }
                        .keyboardShortcut(.return, modifiers: .command)
                    sessionAction("plus.circle", "Extend the session by \(Engine.extendMinutes) minutes") { model.extend() }
                    Spacer(minLength: 0)
                    if let left = model.extendRemaining {
                        Text("Saves itself in \(MenuView.countdown(left))")
                            .font(.system(size: 11)).foregroundStyle(palette.muted).monospacedDigit()
                            .accessibilityLabel("Saves itself in \(Int(left)) seconds")
                    }
                }
            case .checking:
                EmptyView()
            }
        }
    }
    @ViewBuilder var taskQueue: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Text("To do").font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.muted)
                Text("\(model.pendingTasks.count)").font(Studio.smallMedium).foregroundStyle(palette.muted)
                Spacer()
                Button { model.surfaces.capture() } label: { Label("Add task", systemImage: "plus") }
                    .buttonStyle(FooterButton()).disabled(model.error != nil)
            }
            if model.pendingTasks.isEmpty {
                Text("Save your next task here.").font(Studio.small).foregroundStyle(palette.muted)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(model.pendingTasks) { item in
                            HStack(spacing: 10) {
                                Button { model.setQueuedTaskCompleted(item.id, completed: true) } label: { Image(systemName: "circle") }
                                    .buttonStyle(IconButton())
                                    .help("Mark task done")
                                    .accessibilityLabel("Mark \(item.title) done")
                                Text(item.title).font(Studio.small).lineLimit(1).help(item.title).frame(maxWidth: .infinity, alignment: .leading)
                                Button { model.start(item.title, queuedID: item.id) } label: { Image(systemName: "play.fill") }
                                    .buttonStyle(IconButton(tint: palette.accent))
                                    .disabled(!model.canStartTask)
                                    .opacity(model.canStartTask ? 1 : 0.35)
                                    .help(model.canStartTask ? "Start a \(model.state.preferences.blockMinutes)-minute session" : "Finish the current session first")
                                    .accessibilityLabel("Start \(item.title)")
                                Button { model.removeQueuedTask(item.id) } label: { Image(systemName: "trash") }
                                    .buttonStyle(IconButton())
                                    .help("Delete task")
                                    .accessibilityLabel("Delete \(item.title)")
                            }.frame(height: 36).disabled(model.error != nil)
                        }
                    }.padding(.trailing, 8)
                }
                .frame(height: CGFloat(min(3, model.pendingTasks.count)) * 36)
                .scrollIndicators(.visible)
                .accessibilityLabel("To do list")
            }
        }
    }

}

/// The full rectangle tracks the pointer, including the empty space around the glyph.
/// One shared description avoids overlapping tooltips when moving between actions.
private struct SessionActionButton: View {
    @Environment(\.studioPalette) private var palette
    let icon: String
    let description: String
    let tint: Color
    @Binding var hoveredDescription: String?
    let action: () -> Void
    @Environment(\.isFocused) private var focused
    private var hovering: Bool { hoveredDescription == description }

    var body: some View {
        Button {
            hoveredDescription = nil
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(hovering ? palette.ink : tint)
                .frame(width: 44, height: 32)
                .background(RoundedRectangle(cornerRadius: 7).fill(palette.ink.opacity(hovering ? 0.08 : 0)))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(focused ? palette.ink : .clear, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside { hoveredDescription = description }
            else if hovering { hoveredDescription = nil }
        }
        .onDisappear { if hovering { hoveredDescription = nil } }
        .accessibilityLabel(description)
    }
}

/// The start action and running timer share a softly rounded, mint-tinted surface.
struct HeroButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { HeroButtonBody(configuration: configuration) }
}
private struct HeroButtonBody: View {
    @Environment(\.studioPalette) private var palette
    let configuration: ButtonStyle.Configuration
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var focused
    @State private var hovering = false
    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .padding(20)
            .foregroundStyle(palette.ink)
            .background(palette.raised, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).fill(palette.accent.opacity(hovering && enabled ? 0.06 : 0)))
            .contentShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(focused ? palette.ink : palette.line, lineWidth: 1))
            .opacity(enabled ? (pressed ? 0.85 : 1) : 0.4)
            .animation(Studio.tap, value: pressed)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
    }
}

/// Plain text buttons in footers and corners: no chrome, but still a visible nudge under the
/// pointer so they read as controls rather than captions.
struct FooterButton: ButtonStyle {
    var tint: Color? = nil
    func makeBody(configuration: Configuration) -> some View { FooterButtonBody(tint: tint, configuration: configuration) }
}
private struct FooterButtonBody: View {
    @Environment(\.studioPalette) private var palette
    let tint: Color?
    let configuration: ButtonStyle.Configuration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var focused
    @State private var hovering = false
    var body: some View {
        configuration.label
            .padding(.horizontal, 8).padding(.vertical, 6)
            .foregroundStyle(hovering ? palette.ink : (tint ?? palette.muted))
            .background(palette.ink.opacity(hovering ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(focused ? palette.ink : .clear, lineWidth: 1))
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
    @Environment(\.studioPalette) private var palette
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
                    .font(.system(size: 13)).foregroundStyle(palette.muted)
            }
            FocusedTextField(
                placeholder: placeholder, text: $state.text,
                onSubmit: submit, onCancel: close,
                onMove: { _ in false }, textColor: NSColor(palette.ink),
                placeholderColor: NSColor(palette.muted)
            ).frame(height: 26).padding(14)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(palette.accent.opacity(0.5), lineWidth: 1.5))
            HStack {
                Button(action: close) { HStack { Text("Cancel"); KeyHint(text: "esc") } }.keyboardShortcut(.cancelAction).buttonStyle(StudioButton())
                Spacer()
                // Return is handled by the text field itself, so this button must not also
                // claim .defaultAction — both would fire and submit twice.
                Button(action: submit) { HStack { Text(actionTitle); Text("↵").accessibilityHidden(true) } }
                    .buttonStyle(StudioButton(primary: true))
                    // Abandoning needs no reason; pausing does, because the typing *is* the
                    // pause's mechanism rather than a note attached to it.
                    .disabled(kind != .abandon && state.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(26).frame(width: 520).studioCanvas()
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .islandSurface(tint: kind == .pause ? palette.amber : palette.lavender, radius: 24)
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
    var onDelete: () -> Bool = { false }
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
        field.textColor = textColor ?? .labelColor
        if let editor = field.currentEditor() as? NSTextView {
            editor.textColor = textColor ?? .labelColor
            editor.insertionPointColor = textColor ?? .labelColor
        }
        // The start strip's field is borrowed to name a project, so the placeholder changes
        // under a field that is already on screen; setting it only at build time would leave
        // the old prompt showing.
        if let placeholderColor {
            field.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: placeholderColor, .font: font ?? NSFont.systemFont(ofSize: 17, weight: .medium)])
        } else if field.placeholderString != placeholder {
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
            case #selector(NSResponder.deleteBackward(_:)), #selector(NSResponder.deleteForward(_:)):
                return parent.onDelete()
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
    case tasks = "Reports", todo = "To do"
    var id: String { rawValue }
    var key: String { self == .tasks ? "1" : "2" }
    var shortcut: KeyEquivalent { KeyEquivalent(key.first!) }
}

/// Reports show focused work; To do holds work saved for later.
struct ReviewView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var model: AppModel
    @State private var newTask = ""
    @State private var tab: ReviewTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(model: AppModel, tab: ReviewTab = .tasks) {
        self.model = model
        _tab = State(initialValue: tab)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The title bar is transparent, so this row sits just below the window controls.
            HStack {
                StudioTabs(selection: $tab)
                Spacer()
                Button { model.surfaces.start() } label: { HStack { Text("New session"); KeyHint(text: "⌘N") } }
                    .buttonStyle(StudioButton()).keyboardShortcut("n").disabled(model.error != nil)
                Button { model.surfaces.settings() } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(IconButton()).keyboardShortcut(",").help("Settings  ⌘,").accessibilityLabel("Settings")
            }.padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    switch tab {
                    case .tasks:
                        ReportsView(model: model)
                    case .todo:
                        todo
                    }
                }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(tab)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: tab == .todo ? .trailing : .leading).combined(with: .opacity),
                        removal: .opacity))
                    .animation(reduceMotion ? nil : Studio.settle, value: model.pendingTasks.count)
            }.clipped()
                .animation(reduceMotion ? .easeOut(duration: 0.15) : Studio.settle, value: tab)
        }.frame(minWidth: 650, minHeight: 560).studioCanvas()
    }

    @ViewBuilder private func section<Content: View>(
        _ title: String, _ count: Int?, tint: Color = .secondary, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.system(size: 17, weight: .semibold, design: .default)).foregroundStyle(palette.ink)
                if let count { Text("\(count)").font(Studio.smallMedium).foregroundStyle(palette.muted).contentTransition(.numericText()) }
            }
            content()
        }
    }

    @ViewBuilder private var todo: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                TextField("Add a task for later", text: $newTask)
                    .textFieldStyle(.plain).font(.system(size: 15)).onSubmit(addTask)
                    .accessibilityLabel("New task")
                Button("Add task", action: addTask).buttonStyle(StudioButton(primary: true))
                    .disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.studioRow()
            section("Up next", model.pendingTasks.count) {
                if model.pendingTasks.isEmpty {
                    Text("Your list is clear. Add a task above, or press \(Studio.shortcut(code: model.state.preferences.hotkeyCode, modifiers: model.state.preferences.hotkeyModifiers)) from any app.")
                        .font(Studio.small).foregroundStyle(palette.muted)
                } else {
                    Text(model.canStartTask ? "Start a task when you’re ready to focus." : "Finish the current session to start another task.")
                        .font(Studio.small).foregroundStyle(palette.muted)
                    VStack(spacing: 6) {
                        ForEach(model.pendingTasks) { item in queuedRow(item) }
                    }
                }
            }
            if !model.completedQueuedTasks.isEmpty {
                section("Completed", model.completedQueuedTasks.count) {
                    VStack(spacing: 6) {
                        ForEach(model.completedQueuedTasks) { item in queuedRow(item) }
                    }
                }
            }
        }.disabled(model.error != nil)
    }
    private func addTask() {
        guard !newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        model.enqueue(newTask)
        if model.error == nil { newTask = "" }
    }
    @ViewBuilder private func queuedRow(_ item: QueuedTask) -> some View {
        HStack(spacing: 12) {
            Button { model.setQueuedTaskCompleted(item.id, completed: !item.completed) } label: {
                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
            }.buttonStyle(IconButton(tint: item.completed ? palette.accent : palette.muted))
                .accessibilityLabel(item.completed ? "Reopen \(item.title)" : "Mark \(item.title) done")
            Text(item.title).strikethrough(item.completed).font(.system(size: 14))
                .foregroundStyle(item.completed ? palette.muted : palette.ink)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
            if !item.completed {
                Button { model.start(item.title, queuedID: item.id) } label: { Label("Start", systemImage: "play.fill") }
                    .buttonStyle(FooterButton(tint: palette.accent)).disabled(!model.canStartTask)
                    .opacity(model.canStartTask ? 1 : 0.35)
                    .help(model.canStartTask ? "Start a \(model.state.preferences.blockMinutes)-minute session" : "Finish the current session first")
                    .accessibilityLabel("Start \(item.title)")
            }
            Button { model.removeQueuedTask(item.id) } label: { Image(systemName: "trash") }
                .buttonStyle(IconButton()).accessibilityLabel("Remove \(item.title)")
        }.studioRow()
    }
}

/// Compact navigation with visible shortcuts; selection and keyboard focus are separate states.
struct StudioTabs: View {
    @Environment(\.studioPalette) private var palette
    @Binding var selection: ReviewTab
    @Namespace private var slab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 4) {
            ForEach(ReviewTab.allCases) { tab in
                Button { selection = tab } label: {
                    HStack(spacing: 10) { Text(tab.rawValue); KeyHint(text: "⌘" + tab.key) }
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(selection == tab ? palette.ink : palette.muted)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background {
                            if selection == tab {
                                RoundedRectangle(cornerRadius: 20).fill(palette.line)
                                    .matchedGeometryEffect(id: "slab", in: slab)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(TabSegment())
                .keyboardShortcut(tab.shortcut, modifiers: .command)
                .help(tab.rawValue + "  ⌘" + tab.key)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(4)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(palette.line, lineWidth: 1))
        .animation(reduceMotion ? nil : Studio.tap, value: selection)
        .accessibilityElement(children: .contain).accessibilityLabel("Review tabs")
    }
}
private struct TabSegment: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { TabSegmentBody(configuration: configuration) }
}
private struct TabSegmentBody: View {
    @Environment(\.studioPalette) private var palette
    let configuration: ButtonStyle.Configuration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isFocused) private var focused
    @State private var hovering = false
    var body: some View {
        configuration.label
            .overlay(RoundedRectangle(cornerRadius: 20).fill(palette.ink.opacity(hovering ? 0.05 : 0)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(focused ? palette.ink : .clear, lineWidth: 1))
            .animation(Studio.tap, value: configuration.isPressed)
            .animation(Studio.tap, value: hovering)
            .onHover { hovering = $0 }
    }
}

struct SettingsView: View {
    @Environment(\.studioPalette) private var palette
    @ObservedObject var model: AppModel
    private func intBinding(_ key: WritableKeyPath<Preferences, Int>) -> Binding<Int> {
        Binding(get: { model.state.preferences[keyPath: key] }, set: { value in var prefs = model.state.preferences; prefs[keyPath: key] = value; model.setPreferences(prefs) })
    }
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings").font(Studio.title(24))
                Text("Appearance, session defaults, notifications and shortcuts").foregroundStyle(palette.muted)
            }
            themePicker
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Run Blocks on startup", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                    .toggleStyle(.switch)
                Text("Open Blocks automatically when you log in to your Mac.").font(Studio.small).foregroundStyle(palette.muted)
                if let message = model.loginMessage {
                    Text(message).font(Studio.small).foregroundStyle(palette.muted)
                    Button("Open Login Items Settings") { model.openLoginSettings() }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(16).background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    rhythm("Minutes per session", value: model.state.preferences.blockMinutes, binding: intBinding(\.blockMinutes), range: Preferences.lengthRange, color: palette.raised)
                    rhythm("Focus hours per day", value: model.state.preferences.dailyFocusHours, binding: intBinding(\.dailyFocusHours), range: Preferences.dailyFocusHoursRange, color: palette.raised)
                }
                // Each caption sits under the control it belongs to rather than collecting at the
                // bottom of the pane as a paragraph of small print.
                Text("Defaults apply to your next session. You can also choose a length in the start popup.").font(Studio.small).foregroundStyle(palette.muted).fixedSize(horizontal: false, vertical: true)
            }
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
                Text("The notch bar stays visible between sessions. Closing it temporarily switches to the menu bar.").font(Studio.small).foregroundStyle(palette.muted).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Toggle("Completion sound", isOn: Binding(get: { model.state.preferences.soundNotificationEnabled }, set: { value in
                        var prefs = model.state.preferences; prefs.soundNotificationEnabled = value; model.setPreferences(prefs)
                    })).toggleStyle(.switch)
                    Spacer(minLength: 0)
                }
                Text("A soft, brief tone when your timer ends.").font(Studio.small).foregroundStyle(palette.muted)
                HStack {
                    Picker("Completion audio", selection: Binding(get: { model.state.preferences.completionSound }, set: { value in
                        var prefs = model.state.preferences; prefs.completionSound = value; model.setPreferences(prefs)
                    })) {
                        ForEach(CompletionSound.allCases, id: \.self) { sound in Text(sound.title).tag(sound) }
                    }
                    Button { model.previewCompletionSound() } label: { Label("Preview", systemImage: "speaker.wave.2") }
                        .help("Play the selected notification sound")
                }
                .disabled(!model.state.preferences.soundNotificationEnabled)
                Text(model.state.preferences.completionSound.detail)
                    .font(Studio.small).foregroundStyle(palette.muted).fixedSize(horizontal: false, vertical: true)
            }.padding(16).background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 16) {
                Text("Global shortcuts").font(Studio.title(16))
                HStack {
                    Label("Add to To do", systemImage: "tray")
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
                Text("Select a shortcut, then press a key with Command, Control, or Option. Escape cancels. Start opens session controls while a session is running.").font(Studio.small).foregroundStyle(palette.muted).fixedSize(horizontal: false, vertical: true)
                if let error = model.hotkeyError { Text(error).font(Studio.small).foregroundStyle(.red) }
            }.padding(16).background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield").font(.title2).foregroundStyle(palette.accent)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Local storage").font(.system(size: 14, weight: .semibold))
                    Text("Your sessions and preferences are saved on this Mac.").font(Studio.small).foregroundStyle(palette.muted)
                    Button("Open data folder") { NSWorkspace.shared.open(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Blocks")) }
                        .buttonStyle(FooterButton(tint: palette.accent)).font(Studio.smallMedium).padding(.top, 2).padding(.leading, -8)
                }
            }
        }.padding(28).padding(.top, 12).frame(width: 560)
        }.frame(width: 560, height: 730).studioCanvas()
            .onAppear { model.refreshLaunchAtLogin() }
            .onDisappear { model.stopCompletionSound() }
    }
    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Appearance").font(Studio.title(16))
                Spacer()
                Text("Dark themes")
                    .font(Studio.small).foregroundStyle(palette.muted)
            }
            HStack(spacing: 10) {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    ThemeChoice(theme: theme, selected: model.state.preferences.theme == theme) {
                        var prefs = model.state.preferences
                        prefs.theme = theme
                        model.setPreferences(prefs)
                    }
                }
            }
            Text("Accent colors throughout the app. The notch bar always stays black.")
                .font(Studio.small).foregroundStyle(palette.muted)
        }
    }
    private func rhythm(_ title: String, value: Int, binding: Binding<Int>, range: ClosedRange<Int>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.muted)
            HStack {
                Text("\(value)").font(Studio.title(28)).monospacedDigit().contentTransition(.numericText()).animation(Studio.tap, value: value)
                Spacer()
                Stepper(title, value: binding, in: range).labelsHidden().fixedSize()
                    .accessibilityLabel(title).accessibilityValue("\(value)")
            }
        }.padding(18).frame(maxWidth: .infinity).background(color, in: RoundedRectangle(cornerRadius: 12))
    }

}

/// Preview the real surface, text, and accent colors before choosing a theme.
private struct ThemeChoice: View {
    let theme: AppTheme
    let selected: Bool
    let choose: () -> Void
    @Environment(\.studioPalette) private var palette
    @Environment(\.isFocused) private var focused
    @State private var hovering = false
    var body: some View {
        let preview = StudioPalette(theme)
        Button(action: choose) {
            VStack(alignment: .leading, spacing: 9) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "timer").foregroundStyle(preview.accent)
                        Text("25:00").foregroundStyle(preview.ink).monospacedDigit()
                    }.font(.system(size: 12, weight: .semibold))
                    HStack(spacing: 4) {
                        Capsule().fill(preview.accent).frame(width: 22)
                        Capsule().fill(preview.lavender).frame(width: 12)
                        Capsule().fill(preview.line)
                    }.frame(height: 3)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 9))
                HStack(spacing: 3) {
                    Text(theme.title).font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? palette.accent : palette.muted.opacity(0.5))
                        .font(.system(size: 11))
                }
            }
            .padding(8).frame(maxWidth: .infinity)
            .foregroundStyle(palette.ink)
            .background(hovering ? palette.raised : palette.surface, in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13)
                .strokeBorder(focused ? palette.ink : selected ? palette.accent : palette.line,
                              lineWidth: selected || focused ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(theme.title), dark theme")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityValue(selected ? "Selected" : "")
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
