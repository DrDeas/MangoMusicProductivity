import Foundation
import Observation

/// The single source of truth for the app. Views read it directly and call its methods to change things.
@Observable
final class MangoStore {
    var boards: [Board] = []
    var tasks: [MangoTask] = []
    var thoughts: [Thought] = []
    var notes: [Note] = []
    var blocks: [TimeBlock] = []
    var focusIDs: [UUID] = []
    var prefs = Prefs()
    var focusRun: FocusRun?

    /// One level of undo for destructive actions. Not persisted.
    var undoLabel: String?
    /// A short message for the UI to flash. Not persisted.
    var toast: String?

    @ObservationIgnored private var undoSnapshot: Snapshot?
    @ObservationIgnored private var lastPickID: UUID?
    @ObservationIgnored private var cheerIndex = 0
    @ObservationIgnored var calendar: Calendar
    @ObservationIgnored var now: () -> Date

    static let focusLimit = 3

    init(snapshot: Snapshot = Snapshot(), calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
        restore(snapshot)
        ensureSystemBoards()
    }

    // MARK: Snapshot

    var snapshot: Snapshot {
        Snapshot(boards: boards, tasks: tasks, thoughts: thoughts, notes: notes, blocks: blocks,
                 focusIDs: focusIDs, prefs: prefs, focusRun: focusRun)
    }

    func restore(_ s: Snapshot) {
        boards = s.boards
        tasks = s.tasks
        thoughts = s.thoughts
        notes = s.notes
        blocks = s.blocks
        focusIDs = s.focusIDs
        prefs = s.prefs
        focusRun = s.focusRun
    }

    private func checkpoint(_ label: String) {
        undoSnapshot = snapshot
        undoLabel = label
    }

    func undo() {
        guard let s = undoSnapshot else { return }
        let keepPrefs = prefs
        restore(s)
        prefs = keepPrefs
        undoSnapshot = nil
        undoLabel = nil
    }

    func dismissUndo() {
        undoSnapshot = nil
        undoLabel = nil
    }

    // MARK: Time

    var today: Day { Day(now(), calendar: calendar) }
    var nowMinutes: Int { Clock.minutes(of: now(), calendar: calendar) }

    // MARK: Boards

    private func ensureSystemBoards() {
        if !boards.contains(where: { $0.kind == .inbox }) {
            boards.insert(Board(name: "Inbox", hue: 1, scene: .a, kind: .inbox), at: 0)
        }
        if !boards.contains(where: { $0.kind == .someday }) {
            boards.append(Board(name: "Someday", hue: 5, scene: .a, kind: .someday))
        }
    }

    var inboxBoard: Board { boards.first { $0.kind == .inbox } ?? boards[0] }
    var somedayBoard: Board { boards.first { $0.kind == .someday } ?? boards[boards.count - 1] }

    func board(_ id: UUID?) -> Board? {
        guard let id else { return nil }
        return boards.first { $0.id == id }
    }

    /// Boards for the current scene. System boards belong to both scenes.
    var visibleBoards: [Board] {
        boards.filter { $0.kind != .normal || prefs.sceneMode.shows($0.scene) }
    }

    var topicBoards: [Board] { visibleBoards.filter { $0.kind == .normal } }

    @discardableResult
    func addBoard(name: String, scene: SceneSlot? = nil, hue: Int? = nil) -> Board {
        let slot = scene ?? (prefs.sceneMode == .b ? .b : .a)
        let board = Board(name: name.isEmpty ? "New board" : name,
                          hue: hue ?? (boards.filter { $0.kind == .normal }.count % 8), scene: slot)
        let index = boards.firstIndex { $0.kind == .someday } ?? boards.count
        boards.insert(board, at: index)
        return board
    }

    func update(_ board: Board) {
        if let i = boards.firstIndex(where: { $0.id == board.id }) { boards[i] = board }
    }

    /// Deletes a topic board. Its open tasks move to the Inbox so nothing is lost by accident.
    func deleteBoard(_ id: UUID) {
        guard let board = board(id), board.kind == .normal else { return }
        checkpoint("Deleted \(board.name)")
        let inbox = inboxBoard.id
        tasks.removeAll { $0.boardID == id && $0.isDone }
        for i in tasks.indices where tasks[i].boardID == id { tasks[i].boardID = inbox }
        for i in notes.indices where notes[i].boardID == id { notes[i].boardID = nil }
        boards.removeAll { $0.id == id }
    }

    func moveBoards(from source: IndexSet, to destination: Int, within list: [Board]) {
        var ordered = list
        let moving = source.map { ordered[$0] }
        let insertAt = destination - source.filter { $0 < destination }.count
        ordered.removeAll { b in moving.contains { $0.id == b.id } }
        ordered.insert(contentsOf: moving, at: max(0, min(insertAt, ordered.count)))
        let ids = Set(list.map(\.id))
        var iterator = ordered.makeIterator()
        boards = boards.map { ids.contains($0.id) ? (iterator.next() ?? $0) : $0 }
    }

    func counts(for boardID: UUID) -> (open: Int, done: Int) {
        var open = 0, done = 0
        for t in tasks where t.boardID == boardID {
            if t.isDone { done += 1 } else { open += 1 }
        }
        return (open, done)
    }

    // MARK: Task queries

    func task(_ id: UUID?) -> MangoTask? {
        guard let id else { return nil }
        return tasks.first { $0.id == id }
    }

    private func isVisible(_ t: MangoTask) -> Bool {
        guard let b = board(t.boardID) else { return true }
        return b.kind != .normal || prefs.sceneMode.shows(b.scene)
    }

    /// Open, in the current scene, and not parked in Someday.
    func isActionable(_ t: MangoTask) -> Bool {
        !t.isDone && isVisible(t) && t.boardID != somedayBoard.id
    }

    /// The Filter section: hides tasks longer than the cutoff or needing more energy than the ceiling.
    func passesFilter(_ t: MangoTask) -> Bool {
        if let cutoff = prefs.cutoffMinutes, t.estimate > cutoff { return false }
        if let ceiling = prefs.energyCeiling, t.energy > ceiling { return false }
        return true
    }

    var filterIsOn: Bool { prefs.cutoffMinutes != nil || prefs.energyCeiling != nil }

    func tasks(in boardID: UUID, status: TaskStatus? = nil) -> [MangoTask] {
        tasks.filter { $0.boardID == boardID && (status == nil || $0.status == status) && ($0.isDone || passesFilter($0)) }
    }

    /// Open tasks planned for exactly this day.
    func tasks(due day: Day) -> [MangoTask] {
        tasks.filter { $0.due == day && isActionable($0) && passesFilter($0) }
    }

    /// Open tasks whose day has passed.
    var carriedOver: [MangoTask] {
        let t = today
        return tasks.filter { isActionable($0) && ($0.due.map { $0 < t } ?? false) }
            .sorted { ($0.due ?? t) < ($1.due ?? t) }
    }

    func wins(on day: Day) -> [MangoTask] {
        tasks.filter { t in t.completedAt.map { Day($0, calendar: calendar) == day } ?? false }
    }

    /// Completed-task counts for the last `count` days, oldest first, ending today.
    func winHistory(days count: Int = 7) -> [(day: Day, wins: Int)] {
        let t = today
        var byDay: [Day: Int] = [:]
        for task in tasks {
            if let c = task.completedAt { byDay[Day(c, calendar: calendar), default: 0] += 1 }
        }
        return (0..<count).reversed().map { offset in
            let d = t.adding(days: -offset, calendar: calendar)
            return (d, byDay[d] ?? 0)
        }
    }

    var focusTasks: [MangoTask] { focusIDs.compactMap { task($0) }.filter { !$0.isDone } }

    func search(_ query: String) -> (tasks: [MangoTask], notes: [Note], thoughts: [Thought]) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return ([], [], []) }
        return (
            tasks.filter { $0.title.lowercased().contains(q) || $0.notes.lowercased().contains(q) },
            notes.filter { $0.title.lowercased().contains(q) || $0.body.lowercased().contains(q) },
            thoughts.filter { $0.text.lowercased().contains(q) }
        )
    }

    // MARK: Task changes

    @discardableResult
    func addTask(_ title: String, board: UUID? = nil, due: Day? = nil) -> MangoTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let task = MangoTask(title: trimmed, boardID: board ?? inboxBoard.id, due: due, createdAt: now())
        tasks.append(task)
        return task
    }

    func update(_ task: MangoTask) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let old = tasks[i]
        tasks[i] = task
        if old.status != task.status { statusChanged(at: i, from: old.status) }
        if old.title != task.title {
            for b in blocks.indices where blocks[b].taskID == task.id { blocks[b].title = task.title }
        }
    }

    func setStatus(_ id: UUID, _ status: TaskStatus) {
        guard let i = tasks.firstIndex(where: { $0.id == id }), tasks[i].status != status else { return }
        let old = tasks[i].status
        if status == .done { checkpoint("Completed \u{201C}\(tasks[i].title)\u{201D}") }
        tasks[i].status = status
        statusChanged(at: i, from: old)
    }

    func toggleDone(_ id: UUID) {
        guard let t = task(id) else { return }
        setStatus(id, t.isDone ? .fresh : .done)
    }

    private func statusChanged(at i: Int, from old: TaskStatus) {
        let id = tasks[i].id
        if tasks[i].status == .done {
            tasks[i].completedAt = now()
            focusIDs.removeAll { $0 == id }
            for b in blocks.indices where blocks[b].taskID == id { blocks[b].done = true }
            toast = Gentle.cheers[cheerIndex % Gentle.cheers.count]
            cheerIndex += 1
            // A repeating task leaves its next occurrence behind.
            let finished = tasks[i]
            if let next = finished.repeatRule.next(after: max(finished.due ?? today, today), calendar: calendar) {
                var copy = finished
                copy.id = UUID()
                copy.status = .fresh
                copy.completedAt = nil
                copy.due = next
                copy.carried = 0
                copy.focusSessions = 0
                copy.stuckNote = ""
                copy.createdAt = now()
                copy.steps = finished.steps.map { Step(title: $0.title) }
                tasks[i].repeatRule = .none
                tasks.append(copy)
            }
        } else if old == .done {
            tasks[i].completedAt = nil
            for b in blocks.indices where blocks[b].taskID == id { blocks[b].done = false }
        }
    }

    func deleteTask(_ id: UUID) {
        guard let t = task(id) else { return }
        checkpoint("Deleted \u{201C}\(t.title)\u{201D}")
        tasks.removeAll { $0.id == id }
        blocks.removeAll { $0.taskID == id }
        focusIDs.removeAll { $0 == id }
    }

    func move(_ id: UUID, to boardID: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].boardID = boardID
        if boardID == somedayBoard.id {
            tasks[i].due = nil
            focusIDs.removeAll { $0 == id }
            blocks.removeAll { $0.taskID == id && !$0.done }
        }
    }

    func setDue(_ id: UUID, _ day: Day?) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].due = day
    }

    /// Moves everything carried over to today. Yesterday is gone.
    @discardableResult
    func freshStart() -> Int {
        let late = carriedOver
        guard !late.isEmpty else { return 0 }
        checkpoint("Fresh start")
        let t = today
        let ids = Set(late.map(\.id))
        for i in tasks.indices where ids.contains(tasks[i].id) {
            tasks[i].due = t
            tasks[i].carried += 1
        }
        toast = "Fresh start. \(late.count) moved to today."
        return late.count
    }

    /// Adds or removes a task from the three dashboard focus slots. Returns false when the slots are full.
    @discardableResult
    func toggleFocus(_ id: UUID) -> Bool {
        if let i = focusIDs.firstIndex(of: id) {
            focusIDs.remove(at: i)
            return true
        }
        focusIDs.removeAll { task($0)?.isDone ?? true }
        guard focusIDs.count < MangoStore.focusLimit else {
            toast = "All three focus slots are in use."
            return false
        }
        focusIDs.append(id)
        return true
    }

    func isFocused(_ id: UUID) -> Bool { focusIDs.contains(id) }

    /// "Pick one for me": one task that fits the given energy. Asking again offers a different one.
    func pickOne(energy: Energy) -> MangoTask? {
        let t = today
        let pool = tasks.filter { isActionable($0) && $0.energy <= energy }
        let candidates = pool.isEmpty ? tasks.filter { isActionable($0) } : pool
        func score(_ task: MangoTask) -> Int {
            var s = 0
            if focusIDs.contains(task.id) { s += 40 }
            if let due = task.due {
                if due == t { s += 30 } else if due < t { s += 20 } else if due.days(since: t, calendar: calendar) <= 2 { s += 8 }
            }
            if task.status == .working { s += 10 }
            if task.isQuickWin { s += 6 }
            if task.energy == energy { s += 4 }
            if task.status == .stuck { s -= 15 }
            return s
        }
        let ranked = candidates.sorted {
            let a = score($0), b = score($1)
            return a != b ? a > b : $0.createdAt < $1.createdAt
        }
        let choice = ranked.first { $0.id != lastPickID } ?? ranked.first
        lastPickID = choice?.id
        return choice
    }

    func setEnergy(_ energy: Energy?) {
        prefs.energyToday = energy
        prefs.energyDay = energy == nil ? nil : today
    }

    /// Today's energy setting; yesterday's answer does not carry over.
    var energyToday: Energy? { prefs.energyDay == today ? prefs.energyToday : nil }

    // MARK: Brain dump

    @discardableResult
    func capture(_ text: String) -> Thought? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let thought = Thought(text: trimmed, createdAt: now())
        thoughts.insert(thought, at: 0)
        return thought
    }

    func deleteThought(_ id: UUID) {
        guard let t = thoughts.first(where: { $0.id == id }) else { return }
        checkpoint("Deleted \u{201C}\(t.text.prefix(24))\u{201D}")
        thoughts.removeAll { $0.id == id }
    }

    /// Sends a captured thought where it belongs and removes it from the dump.
    func route(_ id: UUID, to route: Route) {
        guard let thought = thoughts.first(where: { $0.id == id }) else { return }
        checkpoint("Routed thought")
        let firstLine = thought.text.split(whereSeparator: \.isNewline).first.map(String.init) ?? thought.text
        let rest = thought.text.dropFirst(firstLine.count).trimmingCharacters(in: .whitespacesAndNewlines)
        switch route {
        case .today:
            if var t = addTask(firstLine, board: inboxBoard.id, due: today) { t.notes = rest; update(t) }
            toast = "Added to today."
        case .board(let boardID):
            if var t = addTask(firstLine, board: boardID) { t.notes = rest; update(t) }
            toast = "Sent to \(board(boardID)?.name ?? "board")."
        case .someday:
            if var t = addTask(firstLine, board: somedayBoard.id) { t.notes = rest; update(t) }
            toast = "Parked in Someday."
        case .note:
            notes.insert(Note(title: rest.isEmpty ? "" : firstLine, body: rest.isEmpty ? thought.text : rest,
                              createdAt: now(), updatedAt: now()), at: 0)
            toast = "Saved as a note."
        }
        thoughts.removeAll { $0.id == id }
    }

    // MARK: Notes

    @discardableResult
    func addNote(boardID: UUID? = nil) -> Note {
        let note = Note(boardID: boardID, createdAt: now(), updatedAt: now())
        notes.insert(note, at: 0)
        return note
    }

    func update(_ note: Note) {
        guard let i = notes.firstIndex(where: { $0.id == note.id }), notes[i] != note else { return }
        var n = note
        if notes[i].title != n.title || notes[i].body != n.body { n.updatedAt = now() }
        notes[i] = n
    }

    func deleteNote(_ id: UUID) {
        guard let n = notes.first(where: { $0.id == id }) else { return }
        checkpoint("Deleted \u{201C}\(n.displayTitle.prefix(24))\u{201D}")
        notes.removeAll { $0.id == id }
    }

    /// Removes notes that were opened and left empty.
    func pruneEmptyNotes() {
        notes.removeAll {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var sortedNotes: [Note] {
        notes.sorted { a, b in a.pinned != b.pinned ? a.pinned : a.updatedAt > b.updatedAt }
    }

    // MARK: Time blocks

    func blocks(on day: Day) -> [TimeBlock] {
        blocks.filter { $0.day == day }.sorted { ($0.start, $0.length) < ($1.start, $1.length) }
    }

    func block(_ id: UUID?) -> TimeBlock? {
        guard let id else { return nil }
        return blocks.first { $0.id == id }
    }

    @discardableResult
    func addBlock(day: Day, start: Int, length: Int, title: String, taskID: UUID? = nil, hue: Int? = nil) -> TimeBlock {
        let len = max(15, length)
        let s = max(0, min(Clock.snap(start), 1440 - len))
        let linked = task(taskID)
        let block = TimeBlock(day: day, start: s, length: len,
                              title: title.isEmpty ? (linked?.title ?? "Block") : title, taskID: taskID,
                              hue: hue ?? board(linked?.boardID)?.hue ?? 0)
        blocks.append(block)
        return block
    }

    /// Places a task in the first free slot of the day. `busy` carries calendar events to avoid.
    /// On today, the slot starts no earlier than now.
    @discardableResult
    func schedule(_ taskID: UUID, on day: Day, busy: [Span] = []) -> TimeBlock? {
        guard let t = task(taskID) else { return nil }
        let length = max(15, t.estimate)
        var earliest = prefs.dayStart
        if day == today { earliest = max(earliest, nowMinutes) }
        let taken = blocks(on: day).map(\.span) + busy
        let end = max(prefs.dayEnd, earliest)
        guard let start = Scheduling.freeSlot(length: length, busy: taken, earliest: earliest, dayEnd: end) else {
            toast = "No room left that day. Drag a block to make space."
            return nil
        }
        if t.due == nil || day == today { setDue(taskID, day) }
        return addBlock(day: day, start: start, length: length, title: t.title, taskID: taskID)
    }

    func update(_ block: TimeBlock) {
        guard let i = blocks.firstIndex(where: { $0.id == block.id }) else { return }
        var b = block
        b.length = max(15, min(b.length, 1440))
        b.start = max(0, min(b.start, 1440 - b.length))
        blocks[i] = b
    }

    func moveBlock(_ id: UUID, toStart start: Int, day: Day? = nil) {
        guard var b = block(id) else { return }
        b.start = Clock.snap(start)
        if let day { b.day = day }
        update(b)
    }

    func resizeBlock(_ id: UUID, length: Int) {
        guard var b = block(id) else { return }
        b.length = max(15, Clock.snap(length))
        update(b)
    }

    func deleteBlock(_ id: UUID) {
        guard let b = block(id) else { return }
        checkpoint("Removed \u{201C}\(b.title)\u{201D}")
        blocks.removeAll { $0.id == id }
    }

    func toggleBlockDone(_ id: UUID) {
        guard let i = blocks.firstIndex(where: { $0.id == id }) else { return }
        if let taskID = blocks[i].taskID, task(taskID) != nil {
            toggleDone(taskID)
        } else {
            blocks[i].done.toggle()
        }
    }

    /// Minutes planned on a day, counting overlapping blocks once.
    func plannedMinutes(on day: Day) -> Int {
        Scheduling.coveredMinutes(blocks(on: day).map(\.span))
    }

    func doneMinutes(on day: Day) -> Int {
        Scheduling.coveredMinutes(blocks(on: day).filter(\.done).map(\.span))
    }

    /// Planned time as a fraction of the daily capacity. Above 1 means over-booked.
    func load(on day: Day) -> Double {
        let capacity = max(0.5, prefs.capacityHours) * 60
        return Double(plannedMinutes(on: day)) / capacity
    }

    /// Open tasks for the day that have no block on it yet. Today also offers carried-over tasks.
    func unscheduled(on day: Day) -> [MangoTask] {
        let placed = Set(blocks(on: day).compactMap(\.taskID))
        var list = tasks(due: day)
        if day == today { list = carriedOver.filter(passesFilter) + list }
        for t in focusTasks where day == today && !list.contains(where: { $0.id == t.id }) { list.append(t) }
        return list.filter { !placed.contains($0.id) }
    }

    // MARK: Focus timer

    func startFocus(taskID: UUID? = nil, title: String? = nil) {
        let name = title ?? task(taskID)?.title ?? "Focus"
        focusRun = FocusRun(plan: prefs.focus, startedAt: now(), taskID: taskID, title: name)
        if let taskID, let t = task(taskID), t.status == .fresh { setStatus(taskID, .working) }
    }

    func pauseFocus() { focusRun?.pause(at: now()) }
    func resumeFocus() { focusRun?.resume(at: now()) }
    func skipFocusPhase() { focusRun?.skip(at: now()); tickFocus() }

    func stopFocus() {
        tickFocus()
        focusRun = nil
    }

    /// Credits finished focus phases to the linked task and clears the run when the cycle ends.
    func tickFocus() {
        guard var run = focusRun else { return }
        let completed = run.completedFocusPhases(at: now())
        if completed > run.credited {
            if let id = run.taskID, let i = tasks.firstIndex(where: { $0.id == id }) {
                tasks[i].focusSessions += completed - run.credited
            }
            run.credited = completed
            focusRun = run
        }
        if run.position(at: now()).finished {
            focusRun = nil
            toast = "Focus cycle complete. Rest well."
        }
    }
}
