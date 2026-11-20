import SwiftUI

/// DUMP: everything captured and not yet sorted, plus free-form notes.
struct DumpView: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    @State private var mode = 0

    var body: some View {
        Page {
            MultiSwitch(options: [SwitchOption(0, "Brain dump (\(store.thoughts.count))"), SwitchOption(1, "Notes (\(store.notes.count))")],
                        selection: $mode, height: 34, fontSize: 12)
            if mode == 0 {
                thoughts
            } else {
                notes
            }
        }
    }

    @ViewBuilder
    private var thoughts: some View {
        if store.thoughts.isEmpty {
            Panel("Brain dump", style: .light) {
                PanelLabel("Empty. Use the REC bar at the top of any screen to capture a thought, then come here to route it.", dim: true, size: 13)
            }
        }
        ForEach(store.thoughts) { thought in
            ThoughtCard(thought: thought)
        }
    }

    @ViewBuilder
    private var notes: some View {
        Button("New note") {
            store.pruneEmptyNotes()
            let note = store.addNote()
            app.sheet = .note(note.id)
        }
        .buttonStyle(.synthProminent)
        .padding(.vertical, 2)
        ForEach(store.sortedNotes) { note in
            NoteCard(note: note)
        }
    }
}

/// One captured thought with its routing row: the app's "modulation routing".
struct ThoughtCard: View {
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    let thought: Thought

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(thought.text)
                    .font(.lato(15))
                    .foregroundStyle(skin.navy.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    store.deleteThought(thought.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(skin.navy.subtext)
                        .frame(width: 32, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete thought")
            }
            HStack(spacing: 4) {
                Text("ROUTE")
                    .font(.lato(9, bold: true))
                    .foregroundStyle(skin.navy.subtext)
                ModButton(title: "Today", state: .armed) { store.route(thought.id, to: .today) }
                Menu {
                    ForEach(store.visibleBoards.filter { $0.kind != .someday }) { board in
                        Button(board.name) { store.route(thought.id, to: .board(board.id)) }
                    }
                } label: {
                    Text("Board \u{25BE}")
                        .font(.lato(11, bold: true))
                        .foregroundStyle(skin.modUsed)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(skin.modFill)
                        .overlay(Rectangle().strokeBorder(skin.modUsed, lineWidth: 1))
                }
                ModButton(title: "Someday", state: .unused) { store.route(thought.id, to: .someday) }
                ModButton(title: "Note", state: .unused) { store.route(thought.id, to: .note) }
            }
            Text(DayText.ago(thought.createdAt, now: store.now()))
                .font(.lato(10))
                .foregroundStyle(skin.navy.subtext.opacity(0.8))
        }
        .padding(10)
        .background(skin.navy.fill)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(skin.navy.border, lineWidth: 1))
    }
}

struct NoteCard: View {
    @Environment(AppModel.self) private var app
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    let note: Note

    var body: some View {
        Button {
            app.sheet = .note(note.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if note.pinned {
                        Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(skin.accent)
                    }
                    Text(note.displayTitle)
                        .font(.lato(15, bold: true))
                        .foregroundStyle(skin.light.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let board = store.board(note.boardID) {
                        Text(board.name)
                            .font(.lato(10, bold: true))
                            .foregroundStyle(Skin.onHue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 2).fill(skin.hue(board.hue)))
                    }
                }
                if !note.body.isEmpty && !note.title.isEmpty {
                    Text(note.body)
                        .font(.lato(13))
                        .foregroundStyle(skin.light.subtext)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Text(DayText.ago(note.updatedAt, now: store.now()))
                    .font(.lato(10))
                    .foregroundStyle(skin.light.subtext.opacity(0.8))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(skin.light.fill)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(skin.light.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(note.pinned ? "Unpin" : "Pin", systemImage: "pin") {
                var n = note
                n.pinned.toggle()
                store.update(n)
            }
            Button("Delete", systemImage: "trash", role: .destructive) { store.deleteNote(note.id) }
        }
    }
}

struct NoteEditorSheet: View {
    @Environment(MangoStore.self) private var store
    @Environment(\.skin) private var skin
    @Environment(\.dismiss) private var dismiss
    let noteID: UUID
    @FocusState private var bodyFocused: Bool

    private var note: Binding<Note> {
        Binding(
            get: { store.notes.first { $0.id == noteID } ?? Note() },
            set: { store.update($0) }
        )
    }

    var body: some View {
        SheetFrame(title: "Note") {
            if store.notes.contains(where: { $0.id == noteID }) {
                Panel("Note", style: .light) {
                    SynthField(placeholder: "Title", text: note.title)
                    TextEditor(text: note.body)
                        .font(.lato(15))
                        .foregroundStyle(skin.isDark ? Color(hex: 0xE5E5E5) : Color.black)
                        .scrollContentBackground(.hidden)
                        .focused($bodyFocused)
                        .frame(minHeight: 260)
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 3).fill(skin.isDark ? Color(hex: 0x131313) : Color.white))
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(skin.isDark ? Color(hex: 0x3C3C3C) : Color(hex: 0xA0A0A0), lineWidth: 1))
                }
                Panel("Filing") {
                    MenuField(label: "Board", value: store.board(note.wrappedValue.boardID)?.name ?? "None") {
                        Button("None") { note.wrappedValue.boardID = nil }
                        ForEach(store.boards.filter { $0.kind == .normal }) { board in
                            Button(board.name) { note.wrappedValue.boardID = board.id }
                        }
                    }
                    HStack {
                        LatchButton(label: "Pinned", isOn: note.pinned)
                        Spacer()
                        Button("Delete note") {
                            store.deleteNote(noteID)
                            dismiss()
                        }
                        .buttonStyle(.synth)
                    }
                }
            } else {
                Panel("Note") { PanelLabel("This note was removed.") }
            }
        }
        .onAppear {
            if note.wrappedValue.body.isEmpty && note.wrappedValue.title.isEmpty { bodyFocused = true }
        }
        .onDisappear { store.pruneEmptyNotes() }
    }
}
