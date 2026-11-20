import SwiftUI

/// CAL: your device calendars, time blocks and due tasks in one place.
struct CalendarView: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    enum Mode: Hashable { case month, week, list }
    @State private var mode: Mode = .month

    var body: some View {
        Page {
            HStack(spacing: 6) {
                MultiSwitch(options: [SwitchOption(Mode.month, "Month"), SwitchOption(Mode.week, "Week"), SwitchOption(Mode.list, "Agenda")],
                            selection: $mode, height: 32)
                if app.calendar.hasAccess {
                    Button("+ Event") {
                        app.sheet = .newEvent(app.day, app.isToday ? min(22 * 60, Clock.snap(store.nowMinutes + 30, to: 30)) : 9 * 60)
                    }
                    .buttonStyle(.synthProminent)
                }
            }
            if !app.calendar.hasAccess { access }
            switch mode {
            case .month:
                MonthPanel()
                DayAgenda(day: app.day, showHeader: true)
            case .week:
                WeekPanel()
                DayAgenda(day: app.day, showHeader: true)
            case .list:
                ForEach(0..<21, id: \.self) { offset in
                    let day = app.day.adding(days: offset, calendar: store.calendar)
                    if offset == 0 || hasAnything(on: day) {
                        DayAgenda(day: day, showHeader: true)
                    }
                }
            }
            if app.calendar.hasAccess {
                Button("Choose calendars") { app.sheet = .calendars }
                    .buttonStyle(.synth)
                    .padding(.vertical, 4)
            }
        }
        .onAppear { app.calendar.ensureLoaded(around: app.day) }
    }

    private func hasAnything(on day: Day) -> Bool {
        !app.calendar.events(on: day).isEmpty || !store.blocks(on: day).isEmpty || !store.tasks(due: day).isEmpty
    }

    private var access: some View {
        Panel("Calendar access", style: .navy) {
            if app.calendar.wasDenied {
                PanelLabel("Calendar access is off. Turn it on in Settings to see your events beside your blocks.", size: 13)
                ModButton(title: "Open Settings", state: .used) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            } else {
                PanelLabel("Connect the calendars already on this iPhone (iCloud, Google, Exchange). Events appear here and in the sequencer, and blocks schedule around them.", size: 13)
                ModButton(title: "Connect calendars", state: .armed) {
                    Task { await app.calendar.requestAccess() }
                }
            }
        }
    }
}

/// What a day holds, as small coloured marks for the month and week grids.
private struct DayMarks {
    var events: Int
    var blocks: Int
    var tasks: Int
    var load: Double
}

private func marks(for day: Day, app: AppModel, store: MangoStore) -> DayMarks {
    DayMarks(events: app.calendar.events(on: day).count, blocks: store.blocks(on: day).count,
             tasks: store.tasks(due: day).count, load: store.load(on: day))
}

struct MonthPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        let grid = app.day.monthGrid(calendar: store.calendar)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        Panel(DayText.format(app.day, "MMMM yyyy", store.calendar), style: .light, padding: 6) {
            Button {
                app.select(app.day.adding(months: -1, calendar: store.calendar))
            } label: { Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold)) }
                .buttonStyle(.synthCompact)
                .accessibilityLabel("Previous month")
            Button {
                app.select(app.day.adding(months: 1, calendar: store.calendar))
            } label: { Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)) }
                .buttonStyle(.synthCompact)
                .accessibilityLabel("Next month")
        } content: {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(grid.prefix(7)), id: \.self) { day in
                    Text(DayText.format(day, "EEEEE", store.calendar))
                        .font(.lato(10, bold: true))
                        .foregroundStyle(skin.light.subtext)
                }
                ForEach(grid, id: \.self) { day in
                    DayCell(day: day, inMonth: day.month == app.day.month)
                }
            }
        }
    }
}

struct WeekPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        let week = app.day.week(calendar: store.calendar)
        Panel("Week of \(DayText.format(week[0], "d MMM", store.calendar))", style: .light, padding: 6) {
            Button {
                app.shiftDay(by: -7)
            } label: { Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold)) }
                .buttonStyle(.synthCompact)
                .accessibilityLabel("Previous week")
            Button {
                app.shiftDay(by: 7)
            } label: { Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)) }
                .buttonStyle(.synthCompact)
                .accessibilityLabel("Next week")
        } content: {
            HStack(spacing: 2) {
                ForEach(week, id: \.self) { day in
                    VStack(spacing: 2) {
                        Text(DayText.format(day, "EEEEE", store.calendar))
                            .font(.lato(10, bold: true))
                            .foregroundStyle(skin.light.subtext)
                        DayCell(day: day, inMonth: true, tall: true)
                    }
                }
            }
        }
    }
}

/// One day in a grid: number, marks for events, blocks and tasks, and a load bar along the bottom.
struct DayCell: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    let day: Day
    let inMonth: Bool
    var tall = false

    var body: some View {
        let selected = day == app.day
        let isToday = day == store.today
        let m = marks(for: day, app: app, store: store)
        Button {
            app.select(day)
            Haptics.tap()
        } label: {
            VStack(spacing: 3) {
                Text("\(day.day)")
                    .font(.lato(14, bold: isToday || selected))
                    .foregroundStyle(selected ? skin.switchOnText : (isToday ? skin.pressed : skin.faceText))
                HStack(spacing: 2) {
                    if m.events > 0 { dot(skin.modBlue) }
                    if m.blocks > 0 { dot(selected ? skin.switchOnText : skin.accent) }
                    if m.tasks > 0 { dot(skin.armedFill) }
                }
                .frame(height: 5)
                if tall {
                    Text(m.events + m.blocks + m.tasks == 0 ? " " : "\(m.events + m.blocks + m.tasks)")
                        .font(.lato(10))
                        .foregroundStyle(selected ? skin.switchOnText : skin.faceDim)
                }
                GeometryReader { geo in
                    Rectangle()
                        .fill(m.load > 1 ? Color(hex: 0xFF0101) : skin.modBlue)
                        .frame(width: geo.size.width * CGFloat(min(1, m.load)))
                }
                .frame(height: 2)
            }
            .padding(.top, 5)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 2).fill(selected ? skin.switchOn : skin.face))
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(isToday ? skin.accent : skin.faceBorder.opacity(0.5), lineWidth: isToday ? 2 : 1))
            .opacity(inMonth ? 1 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(DayText.format(day, "EEEE d MMMM", store.calendar))
        .accessibilityValue("\(m.events) events, \(m.blocks) blocks, \(m.tasks) tasks")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 5, height: 5)
    }
}

/// Everything on one day in time order: events, then blocks, then tasks that are due.
struct DayAgenda: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    let day: Day
    var showHeader = true

    private struct Line: Identifiable {
        let id: String
        let minute: Int
        let time: String
        let title: String
        let detail: String
        let color: Color
        let open: AppSheet
    }

    var body: some View {
        let lines = makeLines()
        let due = store.tasks(due: day)
        Panel("\(DayText.title(day, today: store.today, calendar: store.calendar)), \(DayText.short(day, store.calendar))", padding: 6) {
            Button("Plan") {
                app.select(day)
                app.tab = .seq
            }
            .buttonStyle(.synthCompact)
        } content: {
            if lines.isEmpty && due.isEmpty {
                PanelLabel("Nothing on this day.", dim: true, size: 12).padding(4)
            }
            ForEach(lines) { line in
                Button {
                    app.sheet = line.open
                } label: {
                    HStack(spacing: 8) {
                        Text(line.time)
                            .font(.lato(11, bold: true))
                            .foregroundStyle(skin.lcdText)
                            .frame(width: 62, height: 24)
                            .background(RoundedRectangle(cornerRadius: 2).fill(skin.lcd))
                        RoundedRectangle(cornerRadius: 1).fill(line.color).frame(width: 4, height: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(line.title).font(.lato(14)).foregroundStyle(skin.slate.text).lineLimit(1)
                            if !line.detail.isEmpty {
                                Text(line.detail).font(.lato(10)).foregroundStyle(skin.slate.subtext).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if !due.isEmpty {
                PanelLabel("Due", dim: true, size: 10, bold: true)
                ForEach(due) { TaskRow(task: $0) }
            }
        }
    }

    private func makeLines() -> [Line] {
        var lines: [Line] = []
        for e in app.calendar.events(on: day) {
            let span = app.calendar.span(of: e, on: day)
            lines.append(Line(id: "e-\(e.id)", minute: e.allDay ? -1 : span.start,
                              time: e.allDay ? "All day" : Clock.label(span.start), title: e.title,
                              detail: [e.calendarTitle, e.location].filter { !$0.isEmpty }.joined(separator: "  \u{00B7}  "),
                              color: e.color, open: .event(e.eventID)))
        }
        for b in store.blocks(on: day) {
            lines.append(Line(id: "b-\(b.id)", minute: b.start, time: Clock.label(b.start), title: b.title,
                              detail: "Block  \u{00B7}  \(Clock.duration(b.length))\(b.done ? "  \u{00B7}  done" : "")",
                              color: skin.hue(b.hue), open: .block(b.id)))
        }
        return lines.sorted { ($0.minute, $0.title) < ($1.minute, $1.title) }
    }
}

struct CalendarChooserSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        @Bindable var store = store
        SheetFrame(title: "Calendars") {
            Panel("Show these calendars", padding: 6) {
                if app.calendar.calendars.isEmpty {
                    PanelLabel("No calendars found on this device.", dim: true)
                }
                ForEach(app.calendar.calendars) { cal in
                    let shown = Binding<Bool>(
                        get: { !store.prefs.hiddenCalendarIDs.contains(cal.id) },
                        set: { on in
                            store.prefs.hiddenCalendarIDs.removeAll { $0 == cal.id }
                            if !on { store.prefs.hiddenCalendarIDs.append(cal.id) }
                        }
                    )
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 1).fill(cal.color).frame(width: 5, height: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            PanelLabel(cal.title, size: 14)
                            PanelLabel(cal.source, dim: true, size: 10)
                        }
                        Spacer()
                        LatchButton(label: shown.wrappedValue ? "On" : "Off", isOn: shown)
                    }
                    .padding(.horizontal, 4)
                }
            }
            Panel("Sequencer", style: .light) {
                HStack {
                    Text("Show events in the sequencer and schedule blocks around them")
                        .font(.lato(13))
                        .foregroundStyle(skin.light.text)
                    Spacer()
                    LatchButton(label: store.prefs.showCalendarInSequencer ? "On" : "Off", isOn: $store.prefs.showCalendarInSequencer)
                }
            }
        }
    }
}
