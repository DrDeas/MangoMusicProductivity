import XCTest
@testable import MangoCore

final class MangoCoreTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        c.firstWeekday = 1
        return c
    }()

    /// Wednesday 18 Nov 2026, 10:10 local.
    var clock = Date()

    func makeStore(_ snapshot: Snapshot = Snapshot()) -> MangoStore {
        clock = cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 10, minute: 10))!
        return MangoStore(snapshot: snapshot, calendar: cal, now: { [unowned self] in self.clock })
    }

    // MARK: Day

    func testDayArithmetic() {
        let d = Day(year: 2026, month: 11, day: 18)
        XCTAssertEqual(d.adding(days: 13, calendar: cal), Day(year: 2026, month: 12, day: 1))
        XCTAssertEqual(d.adding(days: -18, calendar: cal), Day(year: 2026, month: 10, day: 31))
        XCTAssertEqual(Day(year: 2026, month: 1, day: 31).adding(months: 1, calendar: cal), Day(year: 2026, month: 2, day: 28))
        XCTAssertEqual(Day(year: 2026, month: 12, day: 1).days(since: d, calendar: cal), 13)
        XCTAssertEqual(d.weekday(calendar: cal), 4)
        XCTAssertLessThan(d, Day(year: 2027, month: 1, day: 1))
        XCTAssertEqual(d.description, "2026-11-18")
    }

    func testDaylightSavingDoesNotSkipDays() {
        // US clocks change on 1 Nov 2026 and 8 Mar 2026.
        XCTAssertEqual(Day(year: 2026, month: 10, day: 31).adding(days: 2, calendar: cal), Day(year: 2026, month: 11, day: 2))
        XCTAssertEqual(Day(year: 2026, month: 3, day: 7).adding(days: 1, calendar: cal), Day(year: 2026, month: 3, day: 8))
        XCTAssertEqual(Day(year: 2026, month: 3, day: 9).days(since: Day(year: 2026, month: 3, day: 7), calendar: cal), 2)
    }

    func testMonthGridAndWeek() {
        let grid = Day(year: 2026, month: 11, day: 18).monthGrid(calendar: cal)
        XCTAssertEqual(grid.count, 42)
        XCTAssertEqual(grid.first, Day(year: 2026, month: 11, day: 1)) // 1 Nov 2026 is a Sunday
        XCTAssertEqual(grid.last, Day(year: 2026, month: 12, day: 12))
        var monday = cal
        monday.firstWeekday = 2
        XCTAssertEqual(Day(year: 2026, month: 11, day: 18).monthGrid(calendar: monday).first, Day(year: 2026, month: 10, day: 26))
        let week = Day(year: 2026, month: 11, day: 18).week(calendar: cal)
        XCTAssertEqual(week.first, Day(year: 2026, month: 11, day: 15))
        XCTAssertEqual(week.last, Day(year: 2026, month: 11, day: 21))
    }

    func testClock() {
        XCTAssertEqual(Clock.label(0), "12 AM")
        XCTAssertEqual(Clock.label(9 * 60 + 5), "9:05 AM")
        XCTAssertEqual(Clock.label(12 * 60), "12 PM")
        XCTAssertEqual(Clock.label(13 * 60 + 30, uses24Hour: true), "13:30")
        XCTAssertEqual(Clock.duration(45), "45m")
        XCTAssertEqual(Clock.duration(90), "1h 30m")
        XCTAssertEqual(Clock.snap(67), 60)
        XCTAssertEqual(Clock.snap(68), 75)
    }

    // MARK: Scheduling

    func testFreeSlot() {
        let busy = [Span(start: 540, end: 600), Span(start: 615, end: 660)]
        XCTAssertEqual(Scheduling.freeSlot(length: 30, busy: busy, earliest: 480, dayEnd: 1320), 480)
        XCTAssertEqual(Scheduling.freeSlot(length: 30, busy: busy, earliest: 535, dayEnd: 1320), 660)
        XCTAssertEqual(Scheduling.freeSlot(length: 15, busy: busy, earliest: 541, dayEnd: 1320), 600)
        XCTAssertNil(Scheduling.freeSlot(length: 120, busy: [Span(start: 0, end: 1300)], earliest: 0, dayEnd: 1320))
        XCTAssertEqual(Scheduling.freeSlot(length: 60, busy: [], earliest: 607, dayEnd: 1320), 615)
    }

    func testColumns() {
        let layout = Scheduling.columns([
            (id: "a", span: Span(start: 0, end: 60)),
            (id: "b", span: Span(start: 30, end: 90)),
            (id: "c", span: Span(start: 60, end: 120)),
            (id: "d", span: Span(start: 200, end: 230)),
        ])
        XCTAssertEqual(layout["a"], .init(column: 0, columns: 2))
        XCTAssertEqual(layout["b"], .init(column: 1, columns: 2))
        XCTAssertEqual(layout["c"], .init(column: 0, columns: 2))
        XCTAssertEqual(layout["d"], .init(column: 0, columns: 1))
        XCTAssertEqual(Scheduling.coveredMinutes([Span(start: 0, end: 60), Span(start: 30, end: 90), Span(start: 200, end: 230)]), 120)
    }

    // MARK: Recurrence

    func testRepeatRules() {
        let fri = Day(year: 2026, month: 11, day: 20)
        XCTAssertEqual(RepeatRule.weekdays.next(after: fri, calendar: cal), Day(year: 2026, month: 11, day: 23))
        XCTAssertEqual(RepeatRule.daily.next(after: fri, calendar: cal), Day(year: 2026, month: 11, day: 21))
        XCTAssertEqual(RepeatRule.weekly.next(after: fri, calendar: cal), Day(year: 2026, month: 11, day: 27))
        XCTAssertEqual(RepeatRule.monthly.next(after: fri, calendar: cal), Day(year: 2026, month: 12, day: 20))
        XCTAssertNil(RepeatRule.none.next(after: fri, calendar: cal))
    }

    // MARK: Store

    func testSystemBoardsAlwaysExist() {
        let store = makeStore()
        XCTAssertEqual(store.inboxBoard.kind, .inbox)
        XCTAssertEqual(store.somedayBoard.kind, .someday)
        let work = store.addBoard(name: "Work")
        XCTAssertEqual(store.boards.map(\.kind), [.inbox, .normal, .someday])
        store.deleteBoard(store.inboxBoard.id)
        XCTAssertEqual(store.boards.count, 3)
        let t = store.addTask("Keep me", board: work.id)!
        store.deleteBoard(work.id)
        XCTAssertEqual(store.task(t.id)?.boardID, store.inboxBoard.id)
        store.undo()
        XCTAssertEqual(store.task(t.id)?.boardID, work.id)
    }

    func testCompleteRepeatingTaskSpawnsNext() {
        let store = makeStore()
        var t = store.addTask("Water plants", due: store.today)!
        t.repeatRule = .weekly
        t.steps = [Step(title: "Fill can", done: true)]
        store.update(t)
        store.toggleFocus(t.id)
        store.setStatus(t.id, .done)

        XCTAssertEqual(store.tasks.count, 2)
        XCTAssertEqual(store.wins(on: store.today).map(\.id), [t.id])
        XCTAssertTrue(store.focusIDs.isEmpty)
        let next = store.tasks.first { $0.id != t.id }!
        XCTAssertEqual(next.due, Day(year: 2026, month: 11, day: 25))
        XCTAssertEqual(next.status, .fresh)
        XCTAssertEqual(next.repeatRule, .weekly)
        XCTAssertEqual(next.steps.map(\.done), [false])
        XCTAssertEqual(store.task(t.id)?.repeatRule, RepeatRule.none)

        store.undo()
        XCTAssertEqual(store.tasks.count, 1)
        XCTAssertEqual(store.task(t.id)?.isDone, false)
    }

    func testLateRepeatingTaskResumesFromToday() {
        let store = makeStore()
        var t = store.addTask("Daily walk", due: store.today.adding(days: -5, calendar: cal))!
        t.repeatRule = .daily
        store.update(t)
        store.toggleDone(t.id)
        XCTAssertEqual(store.tasks.last?.due, Day(year: 2026, month: 11, day: 19))
    }

    func testFreshStartAndCarriedOver() {
        let store = makeStore()
        let late = store.addTask("Late", due: store.today.adding(days: -3, calendar: cal))!
        let parked = store.addTask("Parked", board: store.somedayBoard.id, due: store.today.adding(days: -3, calendar: cal))!
        store.addTask("Today", due: store.today)
        XCTAssertEqual(store.carriedOver.map(\.id), [late.id])
        XCTAssertEqual(store.freshStart(), 1)
        XCTAssertTrue(store.carriedOver.isEmpty)
        XCTAssertEqual(store.task(late.id)?.due, store.today)
        XCTAssertEqual(store.task(late.id)?.carried, 1)
        XCTAssertEqual(store.task(parked.id)?.carried, 0)
        store.undo()
        XCTAssertEqual(store.carriedOver.count, 1)
        XCTAssertEqual(Gentle.late(days: 3, gentle: true), "3d ago")
        XCTAssertEqual(Gentle.late(days: 3, gentle: false), "3 days overdue")
    }

    func testScenesAndFilter() {
        let store = makeStore()
        let work = store.addBoard(name: "Work", scene: .a)
        let home = store.addBoard(name: "Home", scene: .b)
        var long = store.addTask("Long", board: work.id, due: store.today)!
        long.estimate = 120
        long.energy = .high
        store.update(long)
        var quick = store.addTask("Quick", board: home.id, due: store.today)!
        quick.estimate = 5
        quick.energy = .low
        store.update(quick)

        XCTAssertEqual(store.tasks(due: store.today).count, 2)
        store.prefs.sceneMode = .b
        XCTAssertEqual(store.tasks(due: store.today).map(\.title), ["Quick"])
        XCTAssertEqual(store.topicBoards.map(\.name), ["Home"])
        XCTAssertEqual(store.visibleBoards.map(\.kind), [.inbox, .normal, .someday])
        store.prefs.sceneMode = .dual
        store.prefs.cutoffMinutes = 15
        XCTAssertEqual(store.tasks(due: store.today).map(\.title), ["Quick"])
        store.prefs.cutoffMinutes = nil
        store.prefs.energyCeiling = .medium
        XCTAssertEqual(store.tasks(due: store.today).map(\.title), ["Quick"])
        XCTAssertTrue(store.filterIsOn)
    }

    func testFocusSlotsAreLimitedToThree() {
        let store = makeStore()
        let ids = (1...4).map { store.addTask("T\($0)")!.id }
        XCTAssertTrue(store.toggleFocus(ids[0]))
        XCTAssertTrue(store.toggleFocus(ids[1]))
        XCTAssertTrue(store.toggleFocus(ids[2]))
        XCTAssertFalse(store.toggleFocus(ids[3]))
        store.toggleDone(ids[0])
        XCTAssertTrue(store.toggleFocus(ids[3]))
        XCTAssertEqual(store.focusTasks.map(\.id), [ids[1], ids[2], ids[3]])
        XCTAssertTrue(store.toggleFocus(ids[3]))
        XCTAssertEqual(store.focusIDs.count, 2)
    }

    func testPickOneRespectsEnergyAndRotates() {
        let store = makeStore()
        var hard = store.addTask("Hard", due: store.today)!
        hard.energy = .high
        store.update(hard)
        var easyA = store.addTask("Easy A", due: store.today)!
        easyA.energy = .low
        store.update(easyA)
        var easyB = store.addTask("Easy B")!
        easyB.energy = .low
        store.update(easyB)
        store.addTask("Parked", board: store.somedayBoard.id)

        XCTAssertEqual(store.pickOne(energy: .low)?.title, "Easy A")
        XCTAssertEqual(store.pickOne(energy: .low)?.title, "Easy B")
        XCTAssertEqual(store.pickOne(energy: .low)?.title, "Easy A")
        store.toggleFocus(hard.id)
        XCTAssertEqual(store.pickOne(energy: .high)?.title, "Hard")
        store.setEnergy(.low)
        XCTAssertEqual(store.energyToday, .low)
        clock = clock.addingTimeInterval(86_400)
        XCTAssertNil(store.energyToday)
    }

    func testRouting() {
        let store = makeStore()
        let work = store.addBoard(name: "Work")
        XCTAssertNil(store.capture("   "))
        let a = store.capture("Call the bank\nask about fees")!
        let b = store.capture("Learn to sail")!
        let c = store.capture("Loose idea")!
        let d = store.capture("Board thing")!
        XCTAssertEqual(store.thoughts.first?.id, d.id)

        store.route(a.id, to: .today)
        let task = store.tasks.first { $0.title == "Call the bank" }
        XCTAssertEqual(task?.due, store.today)
        XCTAssertEqual(task?.notes, "ask about fees")
        XCTAssertEqual(task?.boardID, store.inboxBoard.id)
        store.route(b.id, to: .someday)
        XCTAssertEqual(store.tasks.first { $0.title == "Learn to sail" }?.boardID, store.somedayBoard.id)
        store.route(c.id, to: .note)
        XCTAssertEqual(store.notes.first?.body, "Loose idea")
        XCTAssertEqual(store.notes.first?.displayTitle, "Loose idea")
        store.route(d.id, to: .board(work.id))
        XCTAssertEqual(store.tasks(in: work.id).map(\.title), ["Board thing"])
        XCTAssertTrue(store.thoughts.isEmpty)
        store.undo()
        XCTAssertEqual(store.thoughts.map(\.id), [d.id])
        XCTAssertTrue(store.tasks(in: work.id).isEmpty)
    }

    func testSchedulingBlocks() {
        let store = makeStore()
        var t = store.addTask("Write report")!
        t.estimate = 60
        store.update(t)
        let lunch = store.addBlock(day: store.today, start: 10 * 60 + 30, length: 30, title: "Call")

        // Now is 10:10, so the first aligned start is 10:15, but the 10:30 block and an 11:00 event are in the way.
        let block = store.schedule(t.id, on: store.today, busy: [Span(start: 660, end: 720)])
        XCTAssertEqual(block?.start, 12 * 60)
        XCTAssertEqual(store.task(t.id)?.due, store.today)
        XCTAssertEqual(store.plannedMinutes(on: store.today), 90)
        XCTAssertEqual(store.load(on: store.today), 0.25, accuracy: 0.001)
        XCTAssertTrue(store.unscheduled(on: store.today).isEmpty)

        // Tomorrow starts at the configured day start.
        let tomorrow = store.today.adding(days: 1, calendar: cal)
        let other = store.addTask("Other", due: tomorrow)!
        XCTAssertEqual(store.unscheduled(on: tomorrow).map(\.id), [other.id])
        XCTAssertEqual(store.schedule(other.id, on: tomorrow)?.start, 7 * 60)

        store.moveBlock(lunch.id, toStart: 23 * 60 + 53)
        XCTAssertEqual(store.block(lunch.id)?.start, 1440 - 30)
        store.resizeBlock(lunch.id, length: 4)
        XCTAssertEqual(store.block(lunch.id)?.length, 15)

        store.toggleBlockDone(block!.id)
        XCTAssertEqual(store.task(t.id)?.isDone, true)
        XCTAssertEqual(store.doneMinutes(on: store.today), 60)
        store.toggleBlockDone(block!.id)
        XCTAssertEqual(store.block(block!.id)?.done, false)

        store.deleteTask(t.id)
        XCTAssertNil(store.block(block!.id))
        store.undo()
        XCTAssertNotNil(store.block(block!.id))
    }

    func testFullDayHasNoSlot() {
        let store = makeStore()
        store.addBlock(day: store.today, start: 7 * 60, length: 15 * 60, title: "Everything")
        let t = store.addTask("Squeeze")!
        XCTAssertNil(store.schedule(t.id, on: store.today))
        XCTAssertNotNil(store.toast)
    }

    func testMoveBoards() {
        let store = makeStore()
        let a = store.addBoard(name: "A"), b = store.addBoard(name: "B"), c = store.addBoard(name: "C")
        store.moveBoards(from: IndexSet(integer: 0), to: 3, within: store.topicBoards)
        XCTAssertEqual(store.topicBoards.map(\.id), [b.id, c.id, a.id])
        XCTAssertEqual(store.boards.first?.kind, .inbox)
        XCTAssertEqual(store.boards.last?.kind, .someday)
    }

    // MARK: Focus timer

    func testFocusPlanPhases() {
        let plan = FocusPlan(focusMinutes: 25, breakMinutes: 5, rounds: 3, longBreakMinutes: 20)
        XCTAssertEqual(plan.phases.map(\.kind), [.focus, .rest, .focus, .rest, .focus, .longRest])
        XCTAssertEqual(plan.totalSeconds, (75 + 10 + 20) * 60)
        XCTAssertEqual(plan.envelope.first?.x, 0)
        XCTAssertEqual(plan.envelope.last?.x ?? 0, 1, accuracy: 0.0001)
        XCTAssertTrue(zip(plan.envelope, plan.envelope.dropFirst()).allSatisfy { $0.x <= $1.x })
    }

    func testFocusRunLifecycle() {
        let store = makeStore()
        store.prefs.focus = FocusPlan(focusMinutes: 10, breakMinutes: 2, rounds: 2, longBreakMinutes: 5)
        let t = store.addTask("Deep")!
        store.startFocus(taskID: t.id)
        XCTAssertEqual(store.task(t.id)?.status, .working)

        clock = clock.addingTimeInterval(4 * 60)
        var pos = store.focusRun!.position(at: clock)
        XCTAssertEqual(pos.phase.kind, .focus)
        XCTAssertEqual(pos.remaining, 6 * 60)

        store.pauseFocus()
        clock = clock.addingTimeInterval(30 * 60)
        XCTAssertEqual(store.focusRun!.position(at: clock).remaining, 6 * 60)
        XCTAssertTrue(store.focusRun!.upcomingPhaseEnds(after: clock).isEmpty)
        store.resumeFocus()
        XCTAssertEqual(store.focusRun!.upcomingPhaseEnds(after: clock).count, 4)
        XCTAssertEqual(store.focusRun!.upcomingPhaseEnds(after: clock).first?.date, clock.addingTimeInterval(6 * 60))

        clock = clock.addingTimeInterval(6 * 60 + 30)
        store.tickFocus()
        pos = store.focusRun!.position(at: clock)
        XCTAssertEqual(pos.phase.kind, .rest)
        XCTAssertEqual(store.task(t.id)?.focusSessions, 1)

        store.skipFocusPhase()
        XCTAssertEqual(store.focusRun!.position(at: clock).phase.round, 2)
        XCTAssertEqual(store.focusRun!.position(at: clock).remaining, 10 * 60)

        clock = clock.addingTimeInterval(60 * 60)
        store.tickFocus()
        XCTAssertNil(store.focusRun)
        XCTAssertEqual(store.task(t.id)?.focusSessions, 2)
    }

    // MARK: Persistence

    func testSnapshotRoundTrip() throws {
        let seeded = SampleData.firstRun(calendar: cal, now: cal.date(from: DateComponents(year: 2026, month: 11, day: 18))!)
        let store = makeStore(seeded)
        store.addBlock(day: store.today, start: 600, length: 45, title: "Block")
        store.startFocus()
        store.prefs.cutoffMinutes = 15
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mango-\(UUID().uuidString)/state.json")
        try Persistence.save(store.snapshot, to: url)
        let loaded = try Persistence.load(from: url)
        XCTAssertEqual(loaded, store.snapshot)
        XCTAssertEqual(MangoStore(snapshot: loaded, calendar: cal).boards.count, 5)
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    func testSearch() {
        let store = makeStore()
        store.addTask("Buy mangoes")
        store.capture("mango smoothie recipe")
        var n = store.addNote()
        n.body = "Ripe MANGO notes"
        store.update(n)
        let r = store.search(" mango ")
        XCTAssertEqual([r.tasks.count, r.notes.count, r.thoughts.count], [1, 1, 1])
        store.addNote()
        store.pruneEmptyNotes()
        XCTAssertEqual(store.notes.count, 1)
    }
}
