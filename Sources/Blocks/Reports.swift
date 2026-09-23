import SwiftUI
import BlocksCore

func focusTime(_ seconds: Double) -> String {
    let minutes = Int(seconds / 60)
    if minutes == 0 && seconds > 0 { return "<1m" }
    if minutes < 60 { return "\(minutes)m" }
    return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
}

struct ReportsView: View {
    @Environment(\.studioPalette) private var palette
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
                    Text("Tasks").font(Studio.title(28))
                    Label("Focus history", systemImage: "chart.bar.xaxis").font(Studio.small).foregroundStyle(palette.muted)
                }
                Spacer()
                Picker("Period", selection: $period) { Text("Day").tag(1); Text("7 days").tag(7); Text("30 days").tag(30) }.pickerStyle(.segmented).labelsHidden().frame(width: 220)
            }
            HStack {
                Button { offset -= 1; selectedDay = nil } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous period").keyboardShortcut("[", modifiers: .command).help("Previous period  ⌘[")
                Text(period == 1 ? start.formatted(date: .abbreviated, time: .omitted) : "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.addingTimeInterval(-1).formatted(.dateTime.month(.abbreviated).day().year()))").font(Studio.smallMedium)
                Button { offset += 1; selectedDay = nil } label: { Image(systemName: "chevron.right") }.disabled(offset == 0).accessibilityLabel("Next period").keyboardShortcut("]", modifiers: .command).help("Next period  ⌘]")
                Spacer()
                projectFilter
            }.buttonStyle(.borderless)
            HStack(spacing: 0) {
                metric(focusTime(records.reduce(0) { $0 + $1.focusDuration }), "Focused time")
                metric("\(records.filter { $0.outcome == .completed }.count)", "Completed sessions")
                metric("\(Set(records.map { calendar.startOfDay(for: $0.end ?? $0.start) }).count)", "Active days")
            }.padding(22).background(palette.raised, in: RoundedRectangle(cornerRadius: 16))
            if records.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Room for your next session.").font(Studio.title(18))
                    Text("Start from the menu or your shortcut. Your focused time will appear here.").foregroundStyle(palette.muted)
                }.padding(.vertical, 20)
            } else {
                chart
                VStack(alignment: .leading, spacing: 16) {
                    Text("By project").font(Studio.title(18))
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
                                    Capsule().fill(palette.line)
                                    Capsule().fill(Projects.color(name)).frame(width: geometry.size.width * share)
                                }.frame(height: 7)
                                Text("\(Int((share * 100).rounded()))%").font(Studio.small).foregroundStyle(palette.muted).monospacedDigit().frame(width: 38, alignment: .trailing)
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
            Text("Focus totals exclude pauses and time while Blocks was asleep or closed. Sessions are grouped by their end date and by their task's project, so retagging a task moves its hours here too.").font(Studio.small).foregroundStyle(palette.muted)
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
            }.font(Studio.smallMedium).foregroundStyle(project == nil ? palette.muted : palette.ink)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(project.map { Projects.color($0).opacity(0.2) } ?? .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(project == nil ? palette.line : .clear, lineWidth: 1))
        }.menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
            .disabled(projects.isEmpty)
    }
    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(value).font(Studio.title(28)); Text(label).font(Studio.small).foregroundStyle(palette.muted) }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var chart: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Daily focus").font(Studio.title(18)); Spacer(); Image(systemName: "cursorarrow.click").foregroundStyle(palette.muted).help("Select a day to see its sessions").accessibilityLabel("Select a day to filter sessions") }
            HStack(alignment: .bottom, spacing: period > 7 ? 5 : 16) {
                ForEach(days, id: \.self) { day in
                    let total = seconds(day)
                    Button { selectedDay = day } label: {
                        VStack(spacing: 8) {
                            if period <= 7 { Text(focusTime(total)).font(Studio.small).foregroundStyle(palette.muted) }
                            VStack(spacing: 1) {
                                ForEach(breakdown.reversed(), id: \.0) { name, _ in
                                    let amount = records.filter { tag($0) == name && calendar.isDate($0.end ?? $0.start, inSameDayAs: day) }.reduce(0) { $0 + $1.focusDuration }
                                    if amount > 0 { Rectangle().fill(Projects.color(name)).frame(height: max(1, amount / max(1, days.map(seconds).max() ?? 1) * 125)) }
                                }
                                if total == 0 { Rectangle().fill(palette.line).frame(height: 3) }
                            }.clipShape(RoundedRectangle(cornerRadius: period > 7 ? 3 : 6))
                            if period <= 7 { Text(day.formatted(.dateTime.weekday(.abbreviated))).font(Studio.small).foregroundStyle(palette.muted) }
                        }.frame(maxWidth: .infinity).opacity(selectedDay == nil || selectedDay == day ? 1 : 0.4)
                    }.buttonStyle(.plain).help("\(day.formatted(date: .abbreviated, time: .omitted)): \(focusTime(total))").accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(focusTime(total)) focused")
                }
            }.frame(height: 178, alignment: .bottom)
        }.padding(22).background(palette.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SessionRow: View {
    @Environment(\.studioPalette) private var palette
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
                Text(block.start.formatted(.dateTime.month(.abbreviated).day())).font(Studio.small).foregroundStyle(palette.muted)
            }.frame(width: 76, alignment: .leading)
            RoundedRectangle(cornerRadius: 2).fill(palette.accent.opacity(block.outcome == .completed ? 1 : 0.3)).frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(block.intent).font(.system(size: 14, weight: .medium)).foregroundStyle(palette.ink)
                HStack(spacing: 8) {
                    if let model, let task {
                        ProjectPicker(
                            selection: Binding(get: { task.project }, set: { model.updateTask(task.id, project: $0) }),
                            projects: model.projects)
                    } else {
                        ProjectTag(name: project)
                    }
                    Text(block.outcome?.rawValue.capitalized ?? "In progress").font(Studio.small).foregroundStyle(palette.muted)
                }
                if let reason = block.reason { Text(reason).font(Studio.small).foregroundStyle(palette.muted) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text(focusTime(block.focusDuration)).font(Studio.smallMedium).foregroundStyle(palette.ink).monospacedDigit()
        }.fixedSize(horizontal: false, vertical: true).accessibilityElement(children: .combine)
    }
}
