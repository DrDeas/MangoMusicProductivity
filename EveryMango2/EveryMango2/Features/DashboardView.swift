import SwiftUI

/// MAIN: the day at a glance, laid out like the synth's front panel.
struct DashboardView: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        Page {
            ScopePanel()
            OscillatorPanel()
            EnergyPanel()
            TodayPanel()
            FilterPanel()
            MixerPanel()
            WinsPanel()
        }
    }
}

// MARK: Day scope

/// The oscillator display, showing the selected day as a waveform:
/// the line rises for every time block, and a playhead marks now.
struct ScopePanel: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        let blocks = store.blocks(on: app.day)
        let events = store.prefs.showCalendarInSequencer ? app.calendar.busy(on: app.day) : []
        Panel("Day scope", style: .light, padding: 6) {
            Button("Open Seq") { app.tab = .seq }
                .buttonStyle(.synthCompact)
        } content: {
            DisplayWell(height: 104) {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    Canvas { ctx, size in
                        draw(&ctx, size: size, blocks: blocks, events: events)
                    }
                }
                VStack {
                    HStack {
                        Text(Clock.label(store.prefs.dayStart))
                        Spacer()
                        Text(blocks.isEmpty ? "No blocks yet" : "\(blocks.count) blocks, \(Clock.duration(store.plannedMinutes(on: app.day)))")
                        Spacer()
                        Text(Clock.label(store.prefs.dayEnd))
                    }
                    .font(.lato(10))
                    .foregroundStyle(skin.wave.opacity(0.8))
                    Spacer()
                }
                .padding(5)
            }
            .contentShape(Rectangle())
            .onTapGesture { app.tab = .seq }
            .accessibilityElement()
            .accessibilityLabel("Day scope")
            .accessibilityValue(blocks.isEmpty ? "No blocks" : "\(blocks.count) blocks planned")
        }
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, blocks: [TimeBlock], events: [Span]) {
        let start = Double(store.prefs.dayStart)
        let end = Double(max(store.prefs.dayEnd, store.prefs.dayStart + 60))
        func x(_ minute: Int) -> CGFloat {
            CGFloat((min(max(Double(minute), start), end) - start) / (end - start)) * size.width
        }
        let base = size.height * 0.78
        let top = size.height * 0.30
        ctx.fill(Path(CGRect(x: 0, y: base, width: size.width, height: 1)), with: .color(skin.displayLine))

        for e in events where Double(e.end) > start && Double(e.start) < end {
            let rect = CGRect(x: x(e.start), y: base + 5, width: max(2, x(e.end) - x(e.start)), height: 4)
            ctx.fill(Path(rect), with: .color(skin.displayLine))
        }

        var wave = Path()
        wave.move(to: CGPoint(x: 0, y: base))
        for b in blocks where Double(b.end) > start && Double(b.start) < end {
            let x0 = x(b.start), x1 = x(b.end)
            let ramp = min(4, (x1 - x0) / 3)
            wave.addLine(to: CGPoint(x: x0, y: base))
            wave.addLine(to: CGPoint(x: x0 + ramp, y: top))
            wave.addLine(to: CGPoint(x: x1 - ramp, y: top))
            wave.addLine(to: CGPoint(x: x1, y: base))
            if b.done {
                var fill = Path()
                fill.move(to: CGPoint(x: x0, y: base))
                fill.addLine(to: CGPoint(x: x0 + ramp, y: top))
                fill.addLine(to: CGPoint(x: x1 - ramp, y: top))
                fill.addLine(to: CGPoint(x: x1, y: base))
                fill.closeSubpath()
                ctx.fill(fill, with: .color(skin.wave.opacity(0.3)))
            }
        }
        wave.addLine(to: CGPoint(x: size.width, y: base))
        ctx.stroke(wave, with: .color(skin.wave), style: StrokeStyle(lineWidth: 1.6, lineJoin: .bevel))

        if app.isToday {
            let now = store.nowMinutes
            if Double(now) >= start && Double(now) <= end {
                ctx.fill(Path(CGRect(x: x(now) - 0.5, y: 16, width: 1, height: size.height - 16)), with: .color(.white.opacity(0.85)))
            }
        }
    }
}

// MARK: Oscillators (focus slots)

/// Three slots for the three things that matter most. No more than three, by design.
struct OscillatorPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        let focus = store.focusTasks
        Panel("Focus slots") {
            ForEach(0..<MangoStore.focusLimit, id: \.self) { index in
                HStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(.lato(12, bold: true))
                        .foregroundStyle(index < focus.count ? skin.switchOnText : skin.lcdText)
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 2).fill(index < focus.count ? skin.switchOn : skin.lcd))
                    if index < focus.count {
                        TaskRow(task: focus[index])
                        Button {
                            app.startFocus(taskID: focus[index].id)
                        } label: {
                            Image(systemName: "play.fill").font(.system(size: 11))
                        }
                        .buttonStyle(.synthCompact)
                        .accessibilityLabel("Start focus on \(focus[index].title)")
                    } else {
                        emptySlot
                    }
                }
            }
        }
    }

    private var emptySlot: some View {
        let candidates = (store.tasks(due: store.today) + store.carriedOver).filter { !store.isFocused($0.id) }
        return Menu {
            if candidates.isEmpty {
                Text("Add a task for today first")
            }
            ForEach(candidates.prefix(12)) { task in
                Button(task.title) { store.toggleFocus(task.id) }
            }
        } label: {
            HStack {
                Text("Empty. Tap to choose a task.")
                    .font(.lato(13))
                    .foregroundStyle(skin.slate.subtext)
                Spacer()
            }
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
    }
}

// MARK: Energy and "pick one"

struct EnergyPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    @State private var pickID: UUID?

    var body: some View {
        let energy = Binding<Double>(
            get: { Double((store.energyToday ?? .medium).rank) },
            set: { store.setEnergy(Energy.allCases[min(2, max(0, Int($0.rounded()) - 1))]) }
        )
        Panel("Energy", style: .navy) {
            HStack(alignment: .center, spacing: 12) {
                SynthKnob(label: "Energy", value: energy, range: 1...3, step: 1, defaultValue: 2,
                          format: { Energy.allCases[min(2, max(0, Int($0.rounded()) - 1))].label })
                VStack(alignment: .leading, spacing: 8) {
                    PanelLabel(store.energyToday == nil ? "How is your energy today? Turn the knob." : "Can't decide where to start?", size: 12)
                    ModButton(title: pickID == nil ? "Pick one for me" : "Pick another", state: pickID == nil ? .used : .selected) {
                        let energyNow = store.energyToday ?? .medium
                        if store.energyToday == nil { store.setEnergy(energyNow) }
                        pickID = store.pickOne(energy: energyNow)?.id
                        if pickID == nil { store.toast = "Nothing waiting. Enjoy the quiet." }
                    }
                }
            }
            if let picked = store.task(pickID), !picked.isDone {
                HStack(spacing: 6) {
                    TaskRow(task: picked)
                    ModButton(title: "Start", state: .armed) {
                        app.startFocus(taskID: picked.id)
                    }
                    .frame(width: 64)
                }
            }
        }
    }
}

// MARK: Today

struct TodayPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        let due = store.tasks(due: app.day)
        let carried = app.isToday ? store.carriedOver.filter(store.passesFilter) : []
        let wins = store.wins(on: app.day)
        Panel(DayText.title(app.day, today: store.today, calendar: store.calendar), style: .light) {
            if store.filterIsOn {
                Text("FILTER ON").font(.lato(9, bold: true)).foregroundStyle(skin.light.titleText)
            }
        } content: {
            if !carried.isEmpty {
                HStack {
                    PanelLabel("\(Gentle.carriedTitle(gentle: store.prefs.gentle)) (\(carried.count))", dim: true, size: 11, bold: true)
                    Spacer()
                    Button("Fresh start") { store.freshStart() }
                        .buttonStyle(.synthCompact)
                }
                ForEach(carried) { TaskRow(task: $0) }
                Rectangle().fill(skin.light.border.opacity(0.4)).frame(height: 1)
            }
            if due.isEmpty && carried.isEmpty {
                PanelLabel(wins.isEmpty ? "Nothing planned. Add one small thing, or rest." : "All clear. \(wins.count) done.", dim: true, size: 13)
            }
            ForEach(due) { TaskRow(task: $0) }
            QuickAdd(placeholder: "Add a task for \(DayText.title(app.day, today: store.today, calendar: store.calendar).lowercased())") { title in
                store.addTask(title, due: app.day)
            }
            if !wins.isEmpty {
                Rectangle().fill(skin.light.border.opacity(0.4)).frame(height: 1)
                PanelLabel("Wins (\(wins.count))", dim: true, size: 11, bold: true)
                ForEach(wins) { TaskRow(task: $0) }
            }
        }
    }
}

// MARK: Filter

/// The filter section. Cutoff hides long tasks; the energy pass hides demanding ones.
struct FilterPanel: View {
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    private let stops = [5, 15, 30, 60, 120, 0]

    var body: some View {
        let cutoff = Binding<Int>(
            get: { store.prefs.cutoffMinutes ?? 0 },
            set: { store.prefs.cutoffMinutes = $0 == 0 ? nil : $0 }
        )
        let ceiling = Binding<Energy?>(
            get: { store.prefs.energyCeiling },
            set: { store.prefs.energyCeiling = $0 }
        )
        Panel("Filter") {
            if store.filterIsOn {
                Button("Open") {
                    store.prefs.cutoffMinutes = nil
                    store.prefs.energyCeiling = nil
                }
                .buttonStyle(.synthCompact)
            }
        } content: {
            SteppedSlider(label: "Cutoff: show tasks up to", stops: stops, value: cutoff,
                          format: { $0 == 0 ? "Any length" : Clock.duration($0) })
            HStack(spacing: 8) {
                PanelLabel("Energy pass", dim: true)
                MultiSwitch(options: [SwitchOption(Energy?.some(.low), "Low"), SwitchOption(Energy?.some(.medium), "Med"), SwitchOption(Energy?.none, "All")],
                            selection: ceiling)
            }
        }
    }
}

// MARK: Mixer

/// One channel strip per board. The meter shows how much of the board is done.
struct MixerPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        Panel("Mixer") {
            Button("Boards") { app.openBoardID = nil; app.tab = .boards }
                .buttonStyle(.synthCompact)
        } content: {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(store.visibleBoards) { board in
                        strip(board)
                    }
                }
            }
        }
    }

    private func strip(_ board: Board) -> some View {
        let counts = store.counts(for: board.id)
        let total = counts.open + counts.done
        let fraction = total == 0 ? 0 : CGFloat(counts.done) / CGFloat(total)
        return Button {
            app.open(board: board.id)
        } label: {
            VStack(spacing: 5) {
                Text("\(counts.open)")
                    .font(.lato(12, bold: true))
                    .foregroundStyle(skin.lcdText)
                    .frame(width: 40, height: 20)
                    .background(RoundedRectangle(cornerRadius: 2).fill(skin.lcd))
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2).fill(skin.slate.groove.opacity(skin.isDark ? 0.15 : 1))
                    RoundedRectangle(cornerRadius: 2).fill(skin.hue(board.hue)).frame(height: max(2, 70 * fraction))
                }
                .frame(width: 12, height: 70)
                Text(board.name)
                    .font(.lato(10, bold: true))
                    .foregroundStyle(skin.slate.text)
                    .lineLimit(1)
                    .frame(width: 56)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(board.name), \(counts.open) open, \(counts.done) done")
    }
}

// MARK: Wins

/// The step sequencer, with one step per day of the last week. Patterns, not pressure.
struct WinsPanel: View {
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        let history = store.winHistory(days: 7)
        let peak = max(4, history.map(\.wins).max() ?? 0)
        let total = history.reduce(0) { $0 + $1.wins }
        Panel("Wins this week", style: .orange) {
            Text("\(total)").font(.lato(12, bold: true)).foregroundStyle(skin.orange.titleText)
        } content: {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(history, id: \.day) { item in
                    VStack(spacing: 3) {
                        ZStack(alignment: .bottom) {
                            Rectangle().fill(item.day == store.today ? Color(hex: 0xA9D0EF) : Color(hex: 0xDEDEDE))
                            Rectangle().fill(skin.modFill)
                                .frame(height: 64 * CGFloat(item.wins) / CGFloat(peak))
                        }
                        .frame(height: 64)
                        .overlay(Rectangle().strokeBorder(Color(hex: 0x6D6D7D), lineWidth: 1))
                        Text(DayText.format(item.day, "EEEEE", store.calendar))
                            .font(.lato(10, bold: true))
                            .foregroundStyle(skin.orange.text)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement()
                    .accessibilityLabel(DayText.format(item.day, "EEEE", store.calendar))
                    .accessibilityValue("\(item.wins) wins")
                }
            }
        }
    }
}
