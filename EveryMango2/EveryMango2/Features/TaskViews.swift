import SwiftUI

/// Three small bars showing how much energy a task needs.
struct EnergyBars: View {
    @Environment(\.skin) private var skin
    let energy: Energy

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(1...3, id: \.self) { level in
                Rectangle()
                    .fill(level <= energy.rank ? skin.accent : skin.faceDim.opacity(0.4))
                    .frame(width: 3, height: CGFloat(3 + level * 2))
            }
        }
        .accessibilityLabel("\(energy.label) energy")
    }
}

/// One task on one line: status light, title, and a quiet row of details.
struct TaskRow: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    @Environment(\.panelStyle) private var style
    let task: MangoTask
    var showBoard = true

    var body: some View {
        let c = skin.panel(style)
        HStack(spacing: 2) {
            TaskLight(status: task.status) { store.toggleDone(task.id) }
            Button {
                app.sheet = .task(task.id)
            } label: {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.lato(15))
                            .strikethrough(task.isDone)
                            .foregroundStyle(c.text.opacity(task.isDone ? 0.5 : 1))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        details(c)
                    }
                    Spacer(minLength: 0)
                    if store.isFocused(task.id) {
                        Text("OSC")
                            .font(.lato(9, bold: true))
                            .foregroundStyle(skin.switchOnText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 2).fill(skin.switchOn))
                    }
                }
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .contextMenu { menu }
    }

    private func details(_ c: PanelColors) -> some View {
        HStack(spacing: 7) {
            if showBoard, let board = store.board(task.boardID) {
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 1).fill(skin.hue(board.hue)).frame(width: 6, height: 6)
                    Text(board.name)
                }
            }
            Text(Clock.duration(task.estimate))
            EnergyBars(energy: task.energy)
            if let due = task.due, !task.isDone {
                let late = due < store.today
                Text(DayText.dueChip(due, today: store.today, gentle: store.prefs.gentle, calendar: store.calendar))
                    .foregroundStyle(late ? skin.accent : c.subtext)
            }
            if task.repeatRule != .none {
                Image(systemName: "repeat").font(.system(size: 9, weight: .bold))
            }
            if !task.steps.isEmpty {
                Text("\(task.steps.filter(\.done).count)/\(task.steps.count)")
            }
            if task.status == .stuck {
                Text("STUCK").font(.lato(9, bold: true)).foregroundStyle(skin.modBlue)
            }
        }
        .font(.lato(11))
        .foregroundStyle(c.subtext)
        .lineLimit(1)
    }

    @ViewBuilder
    private var menu: some View {
        if !task.isDone {
            Button("Do today", systemImage: "sun.max") { store.setDue(task.id, store.today) }
            Button("Tomorrow", systemImage: "sunrise") { store.setDue(task.id, store.today.adding(days: 1, calendar: store.calendar)) }
            Button("Place in sequencer", systemImage: "chart.bar.xaxis") { app.schedule(task.id, on: app.day) }
            Button(store.isFocused(task.id) ? "Remove from focus slots" : "Add to focus slots", systemImage: "dial.medium") {
                store.toggleFocus(task.id)
            }
            Button("Start focus", systemImage: "play") { app.startFocus(taskID: task.id) }
            if task.boardID != store.somedayBoard.id {
                Button("Park in Someday", systemImage: "moon.zzz") { store.move(task.id, to: store.somedayBoard.id) }
            }
        }
        Button("Delete", systemImage: "trash", role: .destructive) { store.deleteTask(task.id) }
    }
}

/// A field with an add button. Return adds and keeps the keyboard up for the next one.
struct QuickAdd: View {
    let placeholder: String
    var onAdd: (String) -> Void
    @State private var text = ""

    var body: some View {
        HStack(spacing: 6) {
            SynthField(placeholder: placeholder, text: $text, onSubmit: add)
                .submitLabel(.done)
            Button("Add", action: add)
                .buttonStyle(.synth)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func add() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        text = ""
        Haptics.tap()
    }
}

/// Everything about one task. Lists stay simple; the detail lives here.
struct TaskDetailSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    let taskID: UUID
    @State private var pickingDate = false

    private var task: Binding<MangoTask> {
        Binding(
            get: { store.task(taskID) ?? MangoTask(title: "", boardID: store.inboxBoard.id) },
            set: { store.update($0) }
        )
    }

    var body: some View {
        SheetFrame(title: "Task") {
            if store.task(taskID) != nil {
                main
                when
                shape
                steps
                words
                footer
            } else {
                Panel("Task") { PanelLabel("This task was removed.") }
            }
        }
    }

    private var main: some View {
        Panel("Task") {
            SynthField(placeholder: "What needs doing?", text: task.title, axis: .vertical)
            MultiSwitch(options: TaskStatus.allCases.map { SwitchOption($0, $0.short) }, selection: task.status)
            if task.wrappedValue.status == .stuck {
                SynthField(placeholder: "What's in the way?", text: task.stuckNote, axis: .vertical)
            }
        }
    }

    private var when: some View {
        Panel("When", style: .light) {
            MenuField(label: "Day", value: dayLabel) {
                Button("Today") { setDue(store.today) }
                Button("Tomorrow") { setDue(store.today.adding(days: 1, calendar: store.calendar)) }
                Button("Next week") { setDue(store.today.adding(days: 7, calendar: store.calendar)) }
                Button("Pick a date\u{2026}") { pickingDate = true }
                Button("No date") { setDue(nil) }
            }
            if pickingDate {
                DatePicker("Day", selection: dateBinding, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(skin.accent)
            }
            MenuField(label: "Repeat", value: task.wrappedValue.repeatRule.label) {
                ForEach(RepeatRule.allCases) { rule in
                    Button(rule.label) { task.wrappedValue.repeatRule = rule }
                }
            }
            HStack(spacing: 6) {
                Button("Place in Seq") {
                    app.schedule(taskID, on: task.wrappedValue.due ?? app.day)
                }
                .buttonStyle(.synth)
                Button("Start focus") {
                    app.startFocus(taskID: taskID)
                }
                .buttonStyle(.synthProminent)
            }
        }
    }

    private var shape: some View {
        Panel("Shape") {
            SteppedSlider(label: "Length", stops: Estimate.steps, value: task.estimate, format: { Clock.duration($0) })
            HStack(spacing: 8) {
                PanelLabel("Energy", dim: true)
                MultiSwitch(options: Energy.allCases.map { SwitchOption($0, $0.label) }, selection: task.energy)
            }
            MenuField(label: "Board", value: store.board(task.wrappedValue.boardID)?.name ?? "Inbox") {
                ForEach(store.boards) { board in
                    Button(board.name) { store.move(taskID, to: board.id) }
                }
            }
            HStack {
                PanelLabel(store.isFocused(taskID) ? "In a focus slot on Main" : "Not in a focus slot", dim: true)
                Spacer()
                Button(store.isFocused(taskID) ? "Remove" : "Add to slots") {
                    store.toggleFocus(taskID)
                }
                .buttonStyle(.synthCompact)
            }
        }
    }

    private var steps: some View {
        Panel("Small steps", style: .light) {
            ForEach(task.wrappedValue.steps) { step in
                HStack(spacing: 4) {
                    TaskLight(status: step.done ? .done : .fresh, size: 20) { toggleStep(step.id) }
                    Text(step.title)
                        .font(.lato(14))
                        .strikethrough(step.done)
                        .foregroundStyle(skin.light.text.opacity(step.done ? 0.5 : 1))
                    Spacer(minLength: 0)
                    Button {
                        task.wrappedValue.steps.removeAll { $0.id == step.id }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(skin.light.subtext)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove step")
                }
            }
            QuickAdd(placeholder: "Add a tiny step") { title in
                task.wrappedValue.steps.append(Step(title: title))
            }
        }
    }

    private var words: some View {
        Panel("Why and notes") {
            SynthField(placeholder: "Why this matters", text: task.why, axis: .vertical)
            SynthField(placeholder: "Notes", text: task.notes, axis: .vertical)
        }
    }

    private var footer: some View {
        HStack {
            if task.wrappedValue.focusSessions > 0 {
                Text("\(task.wrappedValue.focusSessions) focus rounds")
                    .lcd(size: 11)
            }
            Spacer()
            Button("Delete task") {
                store.deleteTask(taskID)
                dismiss()
            }
            .buttonStyle(.synth)
        }
        .padding(6)
    }

    private var dayLabel: String {
        guard let due = task.wrappedValue.due else { return "No date" }
        return "\(DayText.title(due, today: store.today, calendar: store.calendar)), \(DayText.short(due, store.calendar))"
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { (task.wrappedValue.due ?? store.today).date(atMinute: 720, calendar: store.calendar) },
            set: { task.wrappedValue.due = Day($0, calendar: store.calendar) }
        )
    }

    private func setDue(_ day: Day?) {
        task.wrappedValue.due = day
        pickingDate = false
    }

    private func toggleStep(_ id: UUID) {
        var t = task.wrappedValue
        if let i = t.steps.firstIndex(where: { $0.id == id }) {
            t.steps[i].done.toggle()
            task.wrappedValue = t
        }
    }
}
