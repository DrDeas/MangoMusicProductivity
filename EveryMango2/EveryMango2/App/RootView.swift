import SwiftUI
import Combine

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var app = app
        VStack(spacing: 0) {
            HeaderBar()
            CaptureBar()
            ZStack {
                skin.gutter
                content
            }
            .overlay(alignment: .bottom) { toast }
            if store.focusRun != nil { FocusStrip() }
            TabStrip()
        }
        .background(skin.header.ignoresSafeArea())
        .sheet(item: $app.sheet) { sheet in
            sheetView(sheet)
                .environment(app)
                .environment(store)
                .environment(\.skin, skin)
                .tint(skin.accent)
        }
        .onReceive(ticker) { _ in
            if store.focusRun != nil { store.tickFocus() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch app.tab {
        case .main: DashboardView()
        case .dump: DumpView()
        case .seq: SequencerView()
        case .boards: BoardsView()
        case .cal: CalendarView()
        }
    }

    @ViewBuilder
    private func sheetView(_ sheet: AppSheet) -> some View {
        switch sheet {
        case .task(let id): TaskDetailSheet(taskID: id)
        case .note(let id): NoteEditorSheet(noteID: id)
        case .block(let id): BlockEditorSheet(blockID: id)
        case .board(let id): BoardEditorSheet(boardID: id)
        case .settings: SettingsSheet()
        case .focus: FocusSheet()
        case .search: SearchSheet()
        case .calendars: CalendarChooserSheet()
        case .newEvent(let day, let minute):
            EventEditor(store: app.calendar.ek, event: app.calendar.newEvent(on: day, startMinute: minute))
                .ignoresSafeArea()
        case .event(let id):
            if let event = app.calendar.ekEvent(id) {
                EventViewer(event: event).ignoresSafeArea()
            } else {
                SheetFrame(title: "Event") {
                    PanelLabel("This event is no longer in your calendar.")
                }
            }
        }
    }

    /// Undo and short confirmations, drawn as the plugin's value window.
    @ViewBuilder
    private var toast: some View {
        if let label = store.undoLabel {
            InfoWindow(text: store.toast ?? label, actionTitle: "Undo") {
                store.undo()
                store.toast = nil
            }
            .padding(.bottom, 10)
            .transition(.opacity)
            .task(id: label) {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if !Task.isCancelled && store.undoLabel == label {
                    store.dismissUndo()
                    store.toast = nil
                }
            }
        } else if let message = store.toast {
            InfoWindow(text: message)
                .padding(.bottom, 10)
                .transition(.opacity)
                .task(id: message) {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    if !Task.isCancelled && store.toast == message { store.toast = nil }
                }
        }
    }
}

// MARK: Header

/// The top strip of the instrument: scene switch, the day "patch browser", load meter, menu.
struct HeaderBar: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                MultiSwitch(options: [SwitchOption(SceneMode.a, "A"), SwitchOption(SceneMode.b, "B"), SwitchOption(SceneMode.dual, "A+B")],
                            selection: $store.prefs.sceneMode, height: 26)
                    .frame(width: 118)
                Text(sceneCaption)
                    .font(.lato(11))
                    .foregroundStyle(skin.headerText.opacity(0.7))
                    .lineLimit(1)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    VUMeter(level: store.load(on: app.day), second: doneLevel)
                        .frame(width: 92, height: 15)
                    Text(loadCaption)
                        .font(.lato(9))
                        .foregroundStyle(skin.headerText.opacity(0.7))
                }
                .accessibilityElement()
                .accessibilityLabel("Day load")
                .accessibilityValue(loadCaption)
                Button("Menu") { app.sheet = .settings }
                    .buttonStyle(.synthCompact)
            }
            DayBrowser()
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 7)
        .background(skin.header)
    }

    private var sceneCaption: String {
        switch store.prefs.sceneMode {
        case .a: return store.prefs.sceneAName
        case .b: return store.prefs.sceneBName
        case .dual: return "Dual"
        }
    }

    private var doneLevel: Double {
        Double(store.doneMinutes(on: app.day)) / (max(0.5, store.prefs.capacityHours) * 60)
    }

    private var loadCaption: String {
        "\(Clock.duration(store.plannedMinutes(on: app.day))) of \(Clock.duration(Int(store.prefs.capacityHours * 60)))"
    }
}

/// The patch browser, browsing days instead of patches.
struct DayBrowser: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        HStack(spacing: 6) {
            jog("chevron.left", label: "Previous day") { app.shiftDay(by: -1) }
            HStack(spacing: 6) {
                Button {
                    app.sheet = .search
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 30, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search")
                Button {
                    app.select(store.today)
                    Haptics.tap()
                } label: {
                    VStack(spacing: 1) {
                        Text(DayText.title(app.day, today: store.today, calendar: store.calendar))
                            .font(.lato(17, bold: true))
                            .lineLimit(1)
                        HStack {
                            Text(DayText.format(app.day, "EEE d MMM", store.calendar))
                            Spacer(minLength: 4)
                            Text(winsCaption)
                        }
                        .font(.lato(10))
                        .opacity(0.75)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Returns to today")
                Image(systemName: app.isToday ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundStyle(app.isToday ? skin.accent : skin.faceDim)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(skin.faceText)
            .padding(.horizontal, 4)
            .frame(height: 42)
            .background(RoundedRectangle(cornerRadius: 3).fill(skin.face))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(skin.faceBorder, lineWidth: 1))
            jog("chevron.right", label: "Next day") { app.shiftDay(by: 1) }
        }
    }

    private var winsCaption: String {
        let wins = store.wins(on: app.day).count
        return wins == 1 ? "1 win" : "\(wins) wins"
    }

    private func jog(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 42)
                .contentShape(Rectangle())
        }
        .buttonStyle(SynthJogStyle())
        .accessibilityLabel(label)
    }
}

struct SynthJogStyle: ButtonStyle {
    @Environment(\.skin) private var skin

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? skin.pressedText : skin.faceText)
            .background(RoundedRectangle(cornerRadius: 3).fill(configuration.isPressed ? skin.pressed : skin.face))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(skin.faceBorder, lineWidth: 1))
    }
}

// MARK: Capture

/// The brain-dump bar, on every screen. Type, press return, and the thought is safe.
struct CaptureBar: View {
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(focused ? Color(hex: 0xFF0101) : skin.lcdText.opacity(0.5))
                .frame(width: 9, height: 9)
                .shadow(color: focused ? Color(hex: 0xFF0101) : .clear, radius: 4)
            Text("REC")
                .font(.lato(11, bold: true))
                .foregroundStyle(skin.lcdText)
            TextField("", text: $text, prompt: Text("Capture any thought\u{2026}").foregroundStyle(skin.lcdText.opacity(0.45)))
                .font(.lato(15))
                .foregroundStyle(skin.lcdText)
                .tint(skin.lcdText)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(capture)
            if !text.isEmpty {
                Button("Capture", action: capture)
                    .buttonStyle(.synthCompact)
            } else if focused {
                Button("Close") { focused = false }
                    .buttonStyle(.synthCompact)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(skin.lcd)
        .overlay(alignment: .top) { Rectangle().fill(skin.faceBorder).frame(height: 1) }
    }

    private func capture() {
        if store.capture(text) != nil {
            Haptics.success()
            store.toast = "Captured. Sort it later in Dump."
            text = ""
            focused = true
        } else {
            focused = false
        }
    }
}

// MARK: Tabs

struct TabStrip: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let on = app.tab == tab
                Button {
                    if on && tab == .boards { app.openBoardID = nil }
                    app.tab = tab
                    Haptics.tap()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 16, weight: .semibold))
                        Text(label(for: tab).uppercased())
                            .font(.lato(10, bold: true))
                            .tracking(0.8)
                    }
                    .foregroundStyle(on ? skin.switchOnText : skin.faceText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 2).fill(on ? skin.switchOn : Color.clear).padding(2))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
                if tab != AppTab.allCases.last {
                    Rectangle().fill(skin.faceBorder.opacity(0.6)).frame(width: 1, height: 34)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 3).fill(skin.face))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(skin.faceBorder, lineWidth: 1))
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(skin.header)
    }

    private func label(for tab: AppTab) -> String {
        if tab == .dump && !store.thoughts.isEmpty { return "Dump \(store.thoughts.count)" }
        return tab.label
    }
}

/// A slim transport strip shown while a focus session runs.
struct FocusStrip: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let run = store.focusRun {
                let pos = run.position(at: context.date)
                Button {
                    app.sheet = .focus
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: run.isPaused ? "pause.fill" : "play.fill")
                            .font(.system(size: 11))
                        Text(FocusText.clock(pos.remaining))
                            .font(.lato(15, bold: true))
                            .monospacedDigit()
                        Text(FocusText.phase(pos.phase))
                            .font(.lato(11, bold: true))
                        Text(run.title)
                            .font(.lato(12))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(skin.lcdText)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(skin.lcd)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

enum FocusText {
    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func phase(_ phase: FocusPlan.Phase) -> String {
        switch phase.kind {
        case .focus: return "FOCUS \(phase.round)"
        case .rest: return "BREAK"
        case .longRest: return "LONG BREAK"
        }
    }
}

// MARK: Sheet chrome

/// Sheets are drawn as the plugin's overlay windows: grey title bar, close cross, panel body.
struct SheetFrame<Content: View>: View {
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.lato(12, bold: true))
                    .tracking(1.2)
                    .foregroundStyle(Color.white)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(skin.danger)
                        .frame(width: 40, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.leading, 14)
            .frame(height: 38)
            .background(skin.isDark ? Color(hex: 0x0F0F0F) : Color(hex: 0x979797))
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    content()
                }
                .padding(4)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(skin.gutter)
        }
        .background(skin.gutter.ignoresSafeArea())
        .presentationDragIndicator(.hidden)
    }
}

/// The scrolling page each tab uses: black gutters between panels.
struct Page<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(4)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
