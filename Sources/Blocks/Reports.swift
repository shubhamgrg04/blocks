import SwiftUI
import BlocksCore

func focusTime(_ seconds: Double) -> String {
    let minutes = Int(seconds / 60)
    if minutes == 0 && seconds > 0 { return "<1m" }
    if minutes < 60 { return "\(minutes)m" }
    return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
}

struct TaskShelf: View {
    @ObservedObject var model: AppModel
    @State private var query = ""
    @State private var showCompleted = false
    var tasks: [FocusTask] {
        model.state.tasks.filter { $0.completed == showCompleted && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.project.localizedCaseInsensitiveContains(query)) }.sorted { $0.lastUsedAt > $1.lastUsedAt }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("One task, one session.").font(Studio.title(21))
                Spacer()
                Button("New session") { model.surfaces?.prompt(.intent) }.buttonStyle(StudioButton(primary: true)).disabled(model.state.phase != .idle)
            }
            HStack {
                TextField("Search tasks or projects", text: $query).textFieldStyle(.roundedBorder)
                Toggle("Completed tasks", isOn: $showCompleted).toggleStyle(.checkbox)
            }
            if tasks.isEmpty { Text(showCompleted ? "Tasks you mark done will appear here." : "Start a session to create a task. Needing longer extends the session rather than adding another.").foregroundStyle(Studio.muted).padding(.vertical, 20) }
            ForEach(tasks) { task in TaskRow(model: model, task: task) }
        }
    }
}

private struct TaskRow: View {
    @ObservedObject var model: AppModel
    let task: FocusTask
    var sessions: [Block] { model.history.filter { $0.belongs(to: task) }.sorted { $0.start > $1.start } }
    /// Retagging here moves the task's recorded sessions with it, so the shelf is where a
    /// history gets organised after the fact as well as where today's work is tagged.
    private var project: Binding<String> {
        Binding(get: { task.project }, set: { model.updateTask(task.id, project: $0) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Button { model.updateTask(task.id, completed: !task.completed) } label: {
                    Image(systemName: task.completed ? "checkmark.circle.fill" : "circle").font(.system(size: 20))
                }.buttonStyle(.plain).help(task.completed ? "Reopen task" : "Mark task done").accessibilityLabel(task.completed ? "Reopen \(task.title)" : "Complete \(task.title)")
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title).font(Studio.title(16))
                    HStack(spacing: 10) {
                        ProjectPicker(selection: project, projects: model.projects)
                        Text(sessionSummary).foregroundStyle(Studio.muted)
                    }.font(Studio.small)
                }
                Spacer()
            }
            // Tasks created before the one-session rule can still hold several; their history
            // is shown as it was recorded rather than rewritten.
            if sessions.count > 1 {
                DisclosureGroup("Session history") {
                    VStack(spacing: 8) { ForEach(sessions) { session in SessionRow(block: session, project: task.project) } }.padding(.top, 12)
                }.font(Studio.small).foregroundStyle(Studio.muted)
            }
        }.padding(18).background(Studio.surface, in: RoundedRectangle(cornerRadius: 16))
    }
    private var sessionSummary: String {
        let focused = focusTime(sessions.reduce(0) { $0 + $1.focusDuration })
        guard let first = sessions.first else { return "No session recorded" }
        if sessions.count == 1 { return "\(focused) · \(first.start.formatted(date: .abbreviated, time: .shortened))" }
        return "\(sessions.count) sessions · \(focused)"
    }
}

struct ReportsView: View {
    @ObservedObject var model: AppModel
    @State private var period = 7
    @State private var offset = 0
    @State private var project: String?
    @State private var selectedDay: Date?
    private var calendar: Calendar { .current }
    private var end: Date { calendar.date(byAdding: .day, value: 1 + offset * period, to: calendar.startOfDay(for: Date()))! }
    private var start: Date { calendar.date(byAdding: .day, value: -period, to: end)! }
    private var days: [Date] { (0..<period).map { calendar.date(byAdding: .day, value: $0, to: start)! } }
    private var records: [Block] { model.history.filter { block in
        let date = block.end ?? block.start
        return date >= start && date < end && (project == nil || tag(block) == project)
    } }
    private var projects: [String] { Array(Set(model.history.map { tag($0) })).sorted() }
    private var breakdown: [(String, Double)] {
        Dictionary(grouping: records, by: tag).map { ($0.key, $0.value.reduce(0) { $0 + $1.focusDuration }) }.sorted { $0.1 > $1.1 }
    }
    private var total: Double { records.reduce(0) { $0 + $1.focusDuration } }
    /// Every heading in a report — filter, bar, breakdown row — comes through here, so a task
    /// retagged in the shelf or in the timeline below moves its hours at once.
    private func tag(_ block: Block) -> String { model.projectIndex.name(of: block) }
    private func seconds(_ day: Date) -> Double { records.filter { calendar.isDate($0.end ?? $0.start, inSameDayAs: day) }.reduce(0) { $0 + $1.focusDuration } }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time well spent").font(Studio.title(28))
                    Text("Every session adds up.").foregroundStyle(Studio.muted)
                }
                Spacer()
                Picker("Period", selection: $period) { Text("Day").tag(1); Text("7 days").tag(7); Text("30 days").tag(30) }.pickerStyle(.segmented).labelsHidden().frame(width: 220)
            }
            HStack {
                Button { offset -= 1; selectedDay = nil } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous period")
                Text(period == 1 ? start.formatted(date: .abbreviated, time: .omitted) : "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day().year()))").font(Studio.smallMedium)
                Button { offset += 1; selectedDay = nil } label: { Image(systemName: "chevron.right") }.disabled(offset == 0).accessibilityLabel("Next period")
                Spacer()
                projectFilter
            }.buttonStyle(.borderless)
            HStack(spacing: 0) {
                metric(focusTime(records.reduce(0) { $0 + $1.focusDuration }), "Focused time")
                metric("\(records.filter { $0.outcome == .completed }.count)", "Completed sessions")
                metric("\(Set(records.map { calendar.startOfDay(for: $0.end ?? $0.start) }).count)", "Active days")
            }.padding(22).background(Studio.lilac, in: RoundedRectangle(cornerRadius: 18))
            if records.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room for your next session.").font(Studio.title(18))
                    Text("Start from the menu or your shortcut. Your focused time will appear here.").foregroundStyle(Studio.muted)
                }.padding(.vertical, 20)
            } else {
                chart
                VStack(alignment: .leading, spacing: 16) {
                    Text("Where your focus went").font(Studio.title(18))
                    // Each row is also the filter for its project: the answer to "where did the
                    // week go" is usually followed by "show me that", and that should not mean
                    // a trip back up to a menu.
                    ForEach(breakdown, id: \.0) { name, seconds in
                        let share = seconds / max(1, total)
                        Button { project = project == name ? nil : name; selectedDay = nil } label: {
                            HStack(spacing: 14) {
                                ProjectDot(name: name, size: 9)
                                Text(name).frame(width: 130, alignment: .leading).lineLimit(1)
                                GeometryReader { geometry in
                                    Capsule().fill(Studio.line)
                                    Capsule().fill(Projects.color(name)).frame(width: geometry.size.width * share)
                                }.frame(height: 7)
                                Text("\(Int((share * 100).rounded()))%").font(Studio.small).foregroundStyle(Studio.muted).monospacedDigit().frame(width: 38, alignment: .trailing)
                                Text(focusTime(seconds)).monospacedDigit().frame(width: 62, alignment: .trailing)
                            }
                            .contentShape(Rectangle())
                            .opacity(project == nil || project == name ? 1 : 0.45)
                        }.buttonStyle(.plain).help(project == name ? "Show every project" : "Show only \(name)")
                            .accessibilityElement(children: .combine)
                    }
                }
                Divider()
                HStack {
                    Text(selectedDay.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Session timeline").font(Studio.title(18))
                    Spacer()
                    if selectedDay != nil { Button("Show all") { selectedDay = nil }.buttonStyle(.borderless) }
                }
                LazyVStack(spacing: 14) {
                    ForEach(records.filter { selectedDay == nil || calendar.isDate($0.end ?? $0.start, inSameDayAs: selectedDay!) }.sorted { $0.start > $1.start }) { block in
                        SessionRow(block: block, project: tag(block), model: model)
                    }
                }
            }
            Text("Focus totals exclude pauses and time while Blocks was asleep or closed. Sessions are grouped by their end date and by their task's project, so retagging a task moves its hours here too.").font(Studio.small).foregroundStyle(Studio.muted)
        }.onChange(of: period) { offset = 0; selectedDay = nil }.onChange(of: project) { selectedDay = nil }
    }
    /// The filter is a chip rather than a pop-up button: it is a refinement of a report, not a
    /// setting the report waits on, and it is empty-handed until there is a project to pick.
    private var projectFilter: some View {
        Menu {
            Button("All projects") { project = nil }
            Divider()
            ForEach(projects, id: \.self) { name in
                Button { project = name } label: { Label(name, systemImage: project == name ? "checkmark" : "circle.fill") }
            }
        } label: {
            HStack(spacing: 6) {
                if let project { ProjectDot(name: project, size: 8) } else { Image(systemName: "line.3.horizontal.decrease").font(.system(size: 10)) }
                Text(project ?? "All projects").lineLimit(1)
            }.font(Studio.smallMedium).foregroundStyle(project == nil ? Studio.muted : Studio.ink)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(project.map { Projects.color($0).opacity(0.2) } ?? .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(project == nil ? Studio.line : .clear, lineWidth: 1))
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .disabled(projects.isEmpty)
    }
    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(value).font(Studio.title(28)); Text(label).font(Studio.small).foregroundStyle(Studio.muted) }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var chart: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Daily rhythm").font(Studio.title(18)); Spacer(); Text("Select a day to see its sessions").font(Studio.small).foregroundStyle(Studio.muted) }
            HStack(alignment: .bottom, spacing: period > 7 ? 5 : 16) {
                ForEach(days, id: \.self) { day in
                    let total = seconds(day)
                    Button { selectedDay = day } label: {
                        VStack(spacing: 8) {
                            if period <= 7 { Text(focusTime(total)).font(Studio.small).foregroundStyle(Studio.muted) }
                            VStack(spacing: 1) {
                                ForEach(breakdown.reversed(), id: \.0) { name, _ in
                                    let amount = records.filter { tag($0) == name && calendar.isDate($0.end ?? $0.start, inSameDayAs: day) }.reduce(0) { $0 + $1.focusDuration }
                                    if amount > 0 { Rectangle().fill(Projects.color(name)).frame(height: max(1, amount / max(1, days.map(seconds).max() ?? 1) * 125)) }
                                }
                                if total == 0 { Rectangle().fill(Studio.line).frame(height: 3) }
                            }.clipShape(RoundedRectangle(cornerRadius: period > 7 ? 3 : 6))
                            if period <= 7 { Text(day.formatted(.dateTime.weekday(.abbreviated))).font(Studio.small).foregroundStyle(Studio.muted) }
                        }.frame(maxWidth: .infinity).opacity(selectedDay == nil || selectedDay == day ? 1 : 0.4)
                    }.buttonStyle(.plain).help("\(day.formatted(date: .abbreviated, time: .omitted)): \(focusTime(total))").accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(focusTime(total)) focused")
                }
            }.frame(height: 178, alignment: .bottom)
        }.padding(22).background(Studio.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct SessionRow: View {
    let block: Block
    /// The resolved project, passed in so a row does not have to look it up for itself.
    let project: String
    /// Present wherever a session can be retagged in place — the timeline is where an untagged
    /// stretch of history is actually noticed, so it is also where it should be fixable.
    var model: AppModel?
    private var task: FocusTask? { model?.task(for: block) }
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(block.start.formatted(.dateTime.hour().minute())).monospacedDigit()
                Text(block.start.formatted(.dateTime.month(.abbreviated).day())).font(Studio.small).foregroundStyle(Studio.muted)
            }.frame(width: 76, alignment: .leading)
            RoundedRectangle(cornerRadius: 2).fill(Studio.accent.opacity(block.outcome == .completed ? 1 : 0.3)).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(block.intent).font(.system(size: 14, weight: .medium)).foregroundStyle(Studio.ink)
                HStack(spacing: 8) {
                    if let model, let task {
                        ProjectPicker(
                            selection: Binding(get: { task.project }, set: { model.updateTask(task.id, project: $0) }),
                            projects: model.projects)
                    } else {
                        ProjectTag(name: project)
                    }
                    Text(block.outcome?.rawValue.capitalized ?? "In progress").font(Studio.small).foregroundStyle(Studio.muted)
                }
                if let reason = block.reason { Text(reason).font(Studio.small).foregroundStyle(Studio.muted) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(focusTime(block.focusDuration)).font(Studio.smallMedium).foregroundStyle(Studio.ink).monospacedDigit()
        }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
}
