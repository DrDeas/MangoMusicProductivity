import SwiftUI

/// SEQ: time blocking. The day runs top to bottom; blocks are the steps.
/// Hold a block to drag it, pull its bottom edge to stretch it, tap empty time to add one.
struct SequencerView: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    @State private var movingID: UUID?
    @State private var liveStart: Int?
    @State private var resizingID: UUID?
    @State private var liveLength: Int?

    private let hourHeight: CGFloat = 64
    private let gutter: CGFloat = 54

    private struct Item: Identifiable {
        enum Kind {
            case block(TimeBlock)
            case event(CalendarService.Event)
        }
        let id: String
        let span: Span
        let kind: Kind
    }

    var body: some View {
        let blocks = store.blocks(on: app.day)
        let events = store.prefs.showCalendarInSequencer ? app.calendar.events(on: app.day) : []
        let firstHour = min(store.prefs.dayStart, blocks.map(\.start).min() ?? 1440) / 60
        let lastHour = min(24, (max(store.prefs.dayEnd, blocks.map(\.end).max() ?? 0) + 59) / 60)
        VStack(spacing: 4) {
            tray(allDay: events.filter(\.allDay))
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(firstHour..<max(lastHour, firstHour + 1), id: \.self) { hour in
                            hourRow(hour).id(hour)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { point in
                        addBlock(at: firstHour * 60 + Int(point.y / hourHeight * 60))
                    }
                    .overlay(alignment: .topLeading) {
                        GeometryReader { geo in
                            lanes(blocks: blocks, events: events.filter { !$0.allDay }, firstHour: firstHour, width: geo.size.width)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .background(skin.slate.fill)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(skin.slate.border, lineWidth: 1))
                .onAppear {
                    let hour = app.isToday ? max(firstHour, store.nowMinutes / 60 - 1) : firstHour
                    proxy.scrollTo(hour, anchor: .top)
                }
            }
        }
        .padding(4)
        .environment(\.panelStyle, .slate)
    }

    // MARK: Tray

    private func tray(allDay: [CalendarService.Event]) -> some View {
        let waiting = store.unscheduled(on: app.day)
        return Panel("Unscheduled", style: .navy, padding: 6) {
            Button("+ Block") { addBlock(at: nil) }
                .buttonStyle(.synthCompact)
            if app.calendar.hasAccess {
                Button("+ Event") { app.sheet = .newEvent(app.day, max(store.prefs.dayStart, app.isToday ? Clock.snap(store.nowMinutes + 30, to: 30) : 9 * 60)) }
                    .buttonStyle(.synthCompact)
            }
        } content: {
            if waiting.isEmpty {
                PanelLabel("Everything for this day has a place. Tap empty time to add a block.", dim: true, size: 11)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(waiting) { task in
                            ModButton(title: "+ \(task.title)  \(Clock.duration(task.estimate))", state: .used) {
                                app.schedule(task.id, on: app.day)
                            }
                            .frame(maxWidth: 220)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
            }
            ForEach(allDay) { event in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1).fill(event.color).frame(width: 4, height: 14)
                    PanelLabel("All day: \(event.title)", size: 11)
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture { app.sheet = .event(event.eventID) }
            }
        }
    }

    // MARK: Grid

    private func hourRow(_ hour: Int) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(Clock.label(hour * 60))
                .font(.lato(10, bold: true))
                .foregroundStyle(skin.slate.subtext)
                .frame(width: gutter - 10, alignment: .trailing)
                .offset(y: -6)
            VStack(spacing: 0) {
                Rectangle().fill(skin.slate.subtext.opacity(0.45)).frame(height: 1)
                Spacer(minLength: 0)
                Rectangle().fill(skin.slate.subtext.opacity(0.15)).frame(height: 1)
                Spacer(minLength: 0)
            }
        }
        .frame(height: hourHeight)
    }

    private func y(_ minute: Int, _ firstHour: Int) -> CGFloat {
        CGFloat(minute - firstHour * 60) / 60 * hourHeight
    }

    // MARK: Blocks and events

    private func lanes(blocks: [TimeBlock], events: [CalendarService.Event], firstHour: Int, width: CGFloat) -> some View {
        var items: [Item] = blocks.map { b in
            var span = b.span
            if b.id == movingID, let s = liveStart { span = Span(start: s, end: s + b.length) }
            if b.id == resizingID, let l = liveLength { span = Span(start: b.start, end: b.start + l) }
            return Item(id: b.id.uuidString, span: span, kind: .block(b))
        }
        items += events.map { Item(id: $0.id, span: app.calendar.span(of: $0, on: app.day), kind: .event($0)) }
        let layout = Scheduling.columns(items.map { (id: $0.id, span: $0.span) })
        let laneWidth = max(40, width - gutter - 6)
        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                let place = layout[item.id] ?? Scheduling.Placement(column: 0, columns: 1)
                let w = laneWidth / CGFloat(place.columns)
                let h = max(22, CGFloat(item.span.length) / 60 * hourHeight - 2)
                itemView(item, height: h)
                    .frame(width: w - 2, height: h)
                    .offset(x: gutter + CGFloat(place.column) * w, y: y(item.span.start, firstHour))
            }
            if app.isToday {
                Rectangle().fill(Color(hex: 0xFF0101))
                    .frame(width: laneWidth + 8, height: 1.5)
                    .offset(x: gutter - 8, y: y(store.nowMinutes, firstHour))
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func itemView(_ item: Item, height: CGFloat) -> some View {
        switch item.kind {
        case .event(let event):
            eventView(event, span: item.span)
        case .block(let block):
            blockView(block, span: item.span, height: height)
        }
    }

    private func eventView(_ event: CalendarService.Event, span: Span) -> some View {
        Button {
            app.sheet = .event(event.eventID)
        } label: {
            HStack(spacing: 5) {
                Rectangle().fill(event.color).frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title).font(.lato(12, bold: true)).lineLimit(1)
                    Text("\(Clock.label(span.start)) \u{2013} \(Clock.label(span.end))").font(.lato(10)).lineLimit(1)
                }
                .foregroundStyle(skin.lcdText)
                .padding(.vertical, 2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(skin.lcd)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(event.color.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Event: \(event.title), \(Clock.label(span.start)) to \(Clock.label(span.end))")
    }

    private func blockView(_ block: TimeBlock, span: Span, height: CGFloat) -> some View {
        let active = block.id == movingID || block.id == resizingID
        let status: TaskStatus = block.done ? .done : (store.task(block.taskID)?.status ?? .fresh)
        return ZStack(alignment: .bottom) {
            HStack(alignment: .top, spacing: 0) {
                TaskLight(status: status, size: 20) { store.toggleBlockDone(block.id) }
                    .frame(width: 32, height: min(height, 34))
                VStack(alignment: .leading, spacing: 1) {
                    Text(block.title)
                        .font(.lato(13, bold: true))
                        .strikethrough(block.done)
                        .lineLimit(height > 48 ? 2 : 1)
                    if height > 34 {
                        Text("\(Clock.label(span.start)) \u{2013} \(Clock.label(span.end))  \(Clock.duration(span.length))")
                            .font(.lato(10))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(Skin.onHue)
                .padding(.top, 4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // The stretch handle along the bottom edge.
            Capsule().fill(Skin.onHue.opacity(0.45))
                .frame(width: 26, height: 3)
                .padding(.bottom, 2)
                .frame(maxWidth: .infinity, minHeight: 16, alignment: .bottom)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { g in
                            resizingID = block.id
                            liveLength = max(15, Clock.snap(block.length + Int(g.translation.height / hourHeight * 60)))
                        }
                        .onEnded { _ in
                            if let l = liveLength { store.resizeBlock(block.id, length: l) }
                            resizingID = nil
                            liveLength = nil
                        }
                )
                .accessibilityHidden(true)
        }
        .background(skin.hue(block.hue).opacity(block.done ? 0.5 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(active ? Color.white : Color.black, lineWidth: active ? 2 : 1))
        .shadow(color: .black.opacity(active ? 0.5 : 0), radius: 6, y: 3)
        .onTapGesture { app.sheet = .block(block.id) }
        .gesture(
            LongPressGesture(minimumDuration: 0.25)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    switch value {
                    case .first(true):
                        break
                    case .second(true, let drag):
                        if movingID != block.id {
                            movingID = block.id
                            Haptics.tap()
                        }
                        let delta = Int((drag?.translation.height ?? 0) / hourHeight * 60)
                        liveStart = max(0, min(1440 - block.length, Clock.snap(block.start + delta)))
                    default:
                        break
                    }
                }
                .onEnded { _ in
                    if movingID == block.id, let s = liveStart { store.moveBlock(block.id, toStart: s) }
                    movingID = nil
                    liveStart = nil
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.title), \(Clock.label(span.start)) to \(Clock.label(span.end))")
        .accessibilityAction(named: "Move earlier") { store.moveBlock(block.id, toStart: block.start - 15) }
        .accessibilityAction(named: "Move later") { store.moveBlock(block.id, toStart: block.start + 15) }
    }

    private func addBlock(at minute: Int?) {
        let start: Int
        if let minute {
            start = (minute / 30) * 30
        } else {
            let earliest = app.isToday ? max(store.prefs.dayStart, store.nowMinutes) : store.prefs.dayStart
            let busy = store.blocks(on: app.day).map(\.span) + app.calendar.busy(on: app.day)
            start = Scheduling.freeSlot(length: 60, busy: busy, earliest: earliest, dayEnd: 1440) ?? earliest
        }
        let block = store.addBlock(day: app.day, start: start, length: 60, title: "New block")
        Haptics.tap()
        app.sheet = .block(block.id)
    }
}

struct BlockEditorSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    let blockID: UUID

    private var block: Binding<TimeBlock> {
        Binding(
            get: { store.block(blockID) ?? TimeBlock(day: store.today, start: 0, length: 15, title: "") },
            set: { store.update($0) }
        )
    }

    var body: some View {
        SheetFrame(title: "Block") {
            if let current = store.block(blockID) {
                Panel("Block") {
                    SynthField(placeholder: "What is this time for?", text: block.title)
                    if let task = store.task(current.taskID) {
                        HStack {
                            PanelLabel("Linked to a task", dim: true, size: 11)
                            Spacer()
                            Button("Open task") { app.sheet = .task(task.id) }
                                .buttonStyle(.synthCompact)
                        }
                    }
                }
                Panel("Time", style: .light) {
                    let start = Binding<Double>(
                        get: { Double(block.wrappedValue.start) },
                        set: { block.wrappedValue.start = Int($0) }
                    )
                    SynthSlider(label: "Start", value: start, range: 0...Double(1440 - current.length), step: 15,
                                format: { Clock.label(Int($0)) })
                    SteppedSlider(label: "Length", stops: [15, 30, 45, 60, 90, 120, 180, 240, 300, 360], value: block.length,
                                  format: { Clock.duration($0) })
                    HStack {
                        Text("\(DayText.short(current.day, store.calendar))  \(Clock.label(current.start)) \u{2013} \(Clock.label(current.end))")
                            .lcd(size: 12)
                        Spacer()
                        Button("Next day") {
                            block.wrappedValue.day = current.day.adding(days: 1, calendar: store.calendar)
                        }
                        .buttonStyle(.synthCompact)
                    }
                }
                Panel("Colour") {
                    HStack(spacing: 6) {
                        ForEach(0..<Skin.hues.count, id: \.self) { index in
                            Button {
                                block.wrappedValue.hue = index
                                Haptics.tap()
                            } label: {
                                RoundedRectangle(cornerRadius: 3).fill(skin.hue(index))
                                    .frame(height: 30)
                                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(current.hue == index ? Color.white : Color.black, lineWidth: current.hue == index ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Colour \(index + 1)")
                        }
                    }
                }
                HStack(spacing: 6) {
                    Button("Start focus") {
                        app.startFocus(taskID: current.taskID, title: current.title)
                    }
                    .buttonStyle(.synthProminent)
                    if app.calendar.hasAccess {
                        Button(current.eventID == nil ? "Copy to calendar" : "In calendar") {
                            if let id = try? app.calendar.addToCalendar(current) {
                                block.wrappedValue.eventID = id
                                store.toast = "Copied to your calendar."
                            } else {
                                store.toast = "Could not save to the calendar."
                            }
                        }
                        .buttonStyle(.synth)
                        .disabled(current.eventID != nil)
                    }
                    Spacer()
                    Button("Remove") {
                        store.deleteBlock(blockID)
                        dismiss()
                    }
                    .buttonStyle(.synth)
                }
                .padding(6)
            } else {
                Panel("Block") { PanelLabel("This block was removed.") }
            }
        }
    }
}
