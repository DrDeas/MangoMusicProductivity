import SwiftUI

/// BOARDS: one board per topic or thread. The list is a mixer; each board opens to its tasks and notes.
struct BoardsView: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store

    var body: some View {
        if let board = store.board(app.openBoardID) {
            BoardDetail(board: board)
        } else {
            BoardList()
        }
    }
}

struct BoardList: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin

    var body: some View {
        Page {
            Panel("Boards", padding: 6) {
                Button("+ Board") {
                    let board = store.addBoard(name: "New board")
                    app.sheet = .board(board.id)
                }
                .buttonStyle(.synthCompact)
            } content: {
                ForEach(store.visibleBoards) { board in
                    row(board)
                }
                if store.topicBoards.isEmpty {
                    PanelLabel("No boards in this scene yet. Add one, or switch scenes at the top left.", dim: true, size: 12)
                        .padding(6)
                }
            }
        }
    }

    private func row(_ board: Board) -> some View {
        let counts = store.counts(for: board.id)
        let total = counts.open + counts.done
        return Button {
            app.openBoardID = board.id
            Haptics.tap()
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(skin.hue(board.hue)).frame(width: 8, height: 40)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(board.name)
                            .font(.lato(16, bold: true))
                            .foregroundStyle(skin.slate.text)
                            .lineLimit(1)
                        if board.kind == .normal {
                            Text(board.scene.letter)
                                .font(.lato(9, bold: true))
                                .foregroundStyle(skin.switchOnText)
                                .frame(width: 16, height: 14)
                                .background(RoundedRectangle(cornerRadius: 2).fill(skin.switchOn))
                        }
                    }
                    VUMeter(level: total == 0 ? 0 : Double(counts.done) / Double(total) * 0.79)
                        .frame(height: 9)
                }
                Text("\(counts.open)")
                    .font(.lato(14, bold: true))
                    .foregroundStyle(skin.lcdText)
                    .frame(width: 44, height: 28)
                    .background(RoundedRectangle(cornerRadius: 3).fill(skin.lcd))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(skin.slate.subtext)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(board.name), \(counts.open) open, \(counts.done) done")
        .contextMenu {
            if board.kind == .normal {
                Button("Edit board", systemImage: "slider.horizontal.3") { app.sheet = .board(board.id) }
                Button("Delete board", systemImage: "trash", role: .destructive) { store.deleteBoard(board.id) }
            }
        }
    }
}

struct BoardDetail: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    let board: Board
    @State private var lane: TaskStatus? = nil

    var body: some View {
        let all = store.tasks(in: board.id)
        let open = all.filter { !$0.isDone }
        let shown = lane == nil ? open : all.filter { $0.status == lane }
        let boardNotes = store.sortedNotes.filter { $0.boardID == board.id }
        Page {
            HStack(spacing: 6) {
                Button {
                    app.openBoardID = nil
                } label: {
                    Label("Boards", systemImage: "chevron.left")
                }
                .buttonStyle(.synth)
                RoundedRectangle(cornerRadius: 2).fill(skin.hue(board.hue)).frame(width: 8, height: 28)
                Text(board.name)
                    .font(.lato(18, bold: true))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if board.kind == .normal {
                    Button("Edit") { app.sheet = .board(board.id) }
                        .buttonStyle(.synth)
                }
            }
            .padding(.vertical, 2)
            MultiSwitch(options: [SwitchOption(TaskStatus?.none, "Open \(open.count)")]
                            + TaskStatus.allCases.map { status in SwitchOption(TaskStatus?.some(status), status.short) },
                        selection: $lane, height: 32, fontSize: 10)
            Panel(lane?.label ?? "Open tasks", style: .light) {
                if store.filterIsOn {
                    Text("FILTER ON").font(.lato(9, bold: true)).foregroundStyle(skin.light.titleText)
                }
            } content: {
                if shown.isEmpty {
                    PanelLabel(emptyText, dim: true, size: 13)
                }
                ForEach(shown) { TaskRow(task: $0, showBoard: false) }
                if lane != .done {
                    QuickAdd(placeholder: board.kind == .someday ? "Park an idea" : "Add a task to \(board.name)") { title in
                        if var t = store.addTask(title, board: board.id), let lane, lane != .fresh {
                            t.status = lane
                            store.update(t)
                        }
                    }
                }
            }
            if board.kind == .normal {
                Panel("Notes on this board") {
                    Button("+ Note") {
                        let note = store.addNote(boardID: board.id)
                        app.sheet = .note(note.id)
                    }
                    .buttonStyle(.synthCompact)
                } content: {
                    if boardNotes.isEmpty {
                        PanelLabel("Keep reference material and loose thinking for this thread here.", dim: true, size: 12)
                    }
                    ForEach(boardNotes) { NoteCard(note: $0) }
                }
            }
        }
    }

    private var emptyText: String {
        if board.kind == .someday { return "Nothing parked. Ideas wait here until they are ripe." }
        if lane == .done { return "Nothing finished here yet." }
        return "Nothing here. Add a task below."
    }
}

struct BoardEditorSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    let boardID: UUID

    private var board: Binding<Board> {
        Binding(
            get: { store.board(boardID) ?? Board(name: "") },
            set: { store.update($0) }
        )
    }

    var body: some View {
        SheetFrame(title: "Board") {
            if let current = store.board(boardID) {
                Panel("Board") {
                    SynthField(placeholder: "Board name", text: board.name)
                    HStack(spacing: 8) {
                        PanelLabel("Scene", dim: true)
                        MultiSwitch(options: [SwitchOption(SceneSlot.a, "A  \(store.prefs.sceneAName)"), SwitchOption(SceneSlot.b, "B  \(store.prefs.sceneBName)")],
                                    selection: board.scene)
                    }
                    HStack(spacing: 6) {
                        ForEach(0..<Skin.hues.count, id: \.self) { index in
                            Button {
                                board.wrappedValue.hue = index
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
                HStack {
                    PanelLabel("Deleting moves open tasks to the Inbox.", dim: true, size: 11)
                    Spacer()
                    Button("Delete board") {
                        if app.openBoardID == boardID { app.openBoardID = nil }
                        store.deleteBoard(boardID)
                        dismiss()
                    }
                    .buttonStyle(.synth)
                }
                .padding(6)
                .environment(\.panelStyle, .slate)
            } else {
                Panel("Board") { PanelLabel("This board was removed.") }
            }
        }
    }
}
