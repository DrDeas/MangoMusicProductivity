import Foundation

enum SampleData {
    /// What a brand-new install starts with: a few boards and tasks that show how the app works.
    static func firstRun(calendar: Calendar = .current, now: Date = Date()) -> Snapshot {
        let today = Day(now, calendar: calendar)
        let inbox = Board(name: "Inbox", hue: 1, scene: .a, kind: .inbox, createdAt: now)
        let work = Board(name: "Work", hue: 0, scene: .a, createdAt: now)
        let home = Board(name: "Home", hue: 4, scene: .b, createdAt: now)
        let ideas = Board(name: "Ideas", hue: 2, scene: .b, createdAt: now)
        let someday = Board(name: "Someday", hue: 5, scene: .a, kind: .someday, createdAt: now)

        var welcome = MangoTask(title: "Tap the light to finish this task", boardID: inbox.id, due: today, createdAt: now)
        welcome.estimate = 5
        welcome.energy = .low
        welcome.why = "Small wins build momentum."

        var plan = MangoTask(title: "Plan tomorrow in the Sequencer", boardID: work.id, due: today, createdAt: now)
        plan.estimate = 15
        plan.steps = [Step(title: "Open SEQ"), Step(title: "Tap + on a task to place it"), Step(title: "Drag the block to adjust")]

        var deep = MangoTask(title: "One hour of deep work", boardID: work.id, due: today, createdAt: now)
        deep.estimate = 60
        deep.energy = .high

        var tidy = MangoTask(title: "Ten-minute tidy", boardID: home.id, createdAt: now)
        tidy.estimate = 15
        tidy.energy = .low
        tidy.repeatRule = .weekly
        tidy.due = today.adding(days: 1, calendar: calendar)

        let trip = MangoTask(title: "Weekend trip somewhere warm", boardID: someday.id, createdAt: now)

        var note = Note(title: "How EveryMango2 works", createdAt: now, updatedAt: now)
        note.body = """
        CAPTURE first, sort later. The REC bar takes any thought.
        ROUTE each thought: Today, a board, Someday, or a note.
        SEQ is your day. Place tasks as blocks and drag to adjust.
        Scenes A and B split your boards, for example Work and Life.
        The Filter hides long or high-energy tasks on low days.
        """
        note.pinned = true

        return Snapshot(
            boards: [inbox, work, home, ideas, someday],
            tasks: [welcome, plan, deep, tidy, trip],
            thoughts: [Thought(text: "Route me: swipe or tap the arrow", createdAt: now)],
            notes: [note],
            blocks: [],
            focusIDs: [deep.id]
        )
    }
}
