import SwiftUI

/// The plugin's menu, as a sheet.
struct SettingsSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    @State private var confirmReset = false

    var body: some View {
        @Bindable var store = store
        SheetFrame(title: "Menu") {
            Panel("Skin", style: .light) {
                MultiSwitch(options: [SwitchOption(false, "Classic"), SwitchOption(true, "Dark")], selection: $store.prefs.darkSkin)
            }
            Panel("Scenes") {
                PanelLabel("Each board lives in scene A or B. The switch at the top left shows one scene or both.", dim: true, size: 11)
                HStack(spacing: 6) {
                    PanelLabel("A", bold: true)
                    SynthField(placeholder: "Scene A name", text: $store.prefs.sceneAName)
                    PanelLabel("B", bold: true)
                    SynthField(placeholder: "Scene B name", text: $store.prefs.sceneBName)
                }
            }
            Panel("Day", style: .light) {
                SynthSlider(label: "Day starts", value: intBinding($store.prefs.dayStart), range: 0...Double(12 * 60), step: 60,
                            defaultValue: Double(7 * 60), format: { Clock.label(Int($0)) })
                SynthSlider(label: "Day ends", value: intBinding($store.prefs.dayEnd), range: Double(13 * 60)...Double(24 * 60), step: 60,
                            defaultValue: Double(22 * 60), format: { Clock.label(Int($0)) })
            }
            Panel("Feel") {
                HStack(alignment: .top, spacing: 14) {
                    SynthKnob(label: "Capacity", value: $store.prefs.capacityHours, range: 1...12, step: 0.5, defaultValue: 6,
                              format: { String(format: "%g h", $0) })
                    VStack(alignment: .leading, spacing: 8) {
                        toggleRow("Gentle language", isOn: $store.prefs.gentle)
                        toggleRow("Haptics", isOn: $store.prefs.haptics)
                        toggleRow("Alert when a block starts", isOn: Binding(
                            get: { store.prefs.blockAlerts },
                            set: { on in
                                store.prefs.blockAlerts = on
                                if on { Notifier.shared.requestPermission() }
                            }
                        ))
                    }
                }
                PanelLabel("Capacity is how many hours you want to plan in a day. It sets the load meter in the header.", dim: true, size: 11)
            }
            Panel("Calendars and focus", style: .light) {
                HStack(spacing: 6) {
                    Button("Calendars") { app.sheet = .calendars }
                        .buttonStyle(.synth)
                    Button("Focus envelope") { app.sheet = .focus }
                        .buttonStyle(.synth)
                }
            }
            Panel("Data") {
                PanelLabel("Everything is stored on this iPhone.", dim: true, size: 11)
                HStack(spacing: 6) {
                    ShareLink(item: AppModel.stateURL) {
                        Text("Export backup")
                    }
                    .buttonStyle(.synth)
                    .simultaneousGesture(TapGesture().onEnded { app.saveNow() })
                    Spacer()
                    Button(confirmReset ? "Tap again to erase" : "Erase everything") {
                        if confirmReset {
                            store.restore(SampleData.firstRun(calendar: store.calendar, now: store.now()))
                            app.openBoardID = nil
                            confirmReset = false
                            store.toast = "Reset to a fresh start."
                        } else {
                            confirmReset = true
                        }
                    }
                    .buttonStyle(.synth)
                }
            }
            Text("EveryMango2  \u{00B7}  ripen at your own pace")
                .font(.lato(10))
                .foregroundStyle(Color(hex: 0x808080))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            PanelLabel(title, size: 13)
            Spacer()
            LatchButton(label: isOn.wrappedValue ? "On" : "Off", isOn: isOn)
        }
    }

    private func intBinding(_ binding: Binding<Int>) -> Binding<Double> {
        Binding<Double>(get: { Double(binding.wrappedValue) }, set: { binding.wrappedValue = Int($0.rounded()) })
    }
}

/// Search across tasks, notes and the brain dump.
struct SearchSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    @State private var query = ""
    @FocusState private var focused: Bool

    var body: some View {
        let results = store.search(query)
        SheetFrame(title: "Search") {
            SynthField(placeholder: "Find a task, note or thought", text: $query)
                .focused($focused)
                .padding(4)
            if !results.tasks.isEmpty {
                Panel("Tasks (\(results.tasks.count))", style: .light) {
                    ForEach(results.tasks.prefix(30)) { TaskRow(task: $0) }
                }
            }
            if !results.notes.isEmpty {
                Panel("Notes (\(results.notes.count))") {
                    ForEach(results.notes.prefix(30)) { NoteCard(note: $0) }
                }
            }
            if !results.thoughts.isEmpty {
                Panel("Brain dump (\(results.thoughts.count))", style: .navy) {
                    ForEach(results.thoughts.prefix(30)) { thought in
                        PanelLabel(thought.text, size: 14)
                    }
                    ModButton(title: "Open Dump", state: .used) {
                        app.tab = .dump
                        app.sheet = nil
                    }
                }
            }
            if !query.isEmpty && results.tasks.isEmpty && results.notes.isEmpty && results.thoughts.isEmpty {
                Panel("Search") { PanelLabel("Nothing matches.", dim: true) }
            }
        }
        .onAppear { focused = true }
    }
}
