import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case main, dump, seq, boards, cal
    var id: String { rawValue }

    var label: String {
        switch self {
        case .main: return "Main"
        case .dump: return "Dump"
        case .seq: return "Seq"
        case .boards: return "Boards"
        case .cal: return "Cal"
        }
    }

    var symbol: String {
        switch self {
        case .main: return "dial.medium"
        case .dump: return "square.and.pencil"
        case .seq: return "chart.bar.xaxis"
        case .boards: return "slider.vertical.3"
        case .cal: return "calendar"
        }
    }
}

enum AppSheet: Identifiable {
    case task(UUID)
    case note(UUID)
    case block(UUID)
    case board(UUID)
    case settings
    case focus
    case search
    case calendars
    case newEvent(Day, Int)
    case event(String)

    var id: String {
        switch self {
        case .task(let id): return "task-\(id)"
        case .note(let id): return "note-\(id)"
        case .block(let id): return "block-\(id)"
        case .board(let id): return "board-\(id)"
        case .settings: return "settings"
        case .focus: return "focus"
        case .search: return "search"
        case .calendars: return "calendars"
        case .newEvent(let day, let minute): return "new-\(day)-\(minute)"
        case .event(let id): return "event-\(id)"
        }
    }
}

/// App-level state: the store, the services, and where the user currently is.
@Observable
final class AppModel {
    let store: MangoStore
    let calendar = CalendarService()

    var tab: AppTab = .main
    /// The day shown in the header's browser; shared by the dashboard, sequencer and calendar.
    var day: Day
    var sheet: AppSheet?
    var openBoardID: UUID?

    @ObservationIgnored private var observer: StoreObserver?
    @ObservationIgnored private var pendingSave: DispatchWorkItem?

    static var stateURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("EveryMango2", isDirectory: true).appendingPathComponent("state.json")
    }

    init() {
        let url = AppModel.stateURL
        let snapshot: Snapshot
        if FileManager.default.fileExists(atPath: url.path) {
            if let loaded = try? Persistence.load(from: url) {
                snapshot = loaded
            } else {
                // Keep the unreadable file rather than overwrite it.
                let aside = url.deletingLastPathComponent().appendingPathComponent("state-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: url, to: aside)
                snapshot = SampleData.firstRun()
            }
        } else {
            snapshot = SampleData.firstRun()
        }
        let loadedStore = MangoStore(snapshot: snapshot)
        let today = loadedStore.today
        store = loadedStore
        day = today
        Haptics.enabled = loadedStore.prefs.haptics
        calendar.setHidden(loadedStore.prefs.hiddenCalendarIDs)
        calendar.ensureLoaded(around: today)
        observer = StoreObserver(store: loadedStore) { [weak self] in
            self?.scheduleSave()
        }
    }

    var skin: Skin { store.prefs.darkSkin ? .dark : .classic }
    var isToday: Bool { day == store.today }

    private func scheduleSave() {
        Haptics.enabled = store.prefs.haptics
        calendar.setHidden(store.prefs.hiddenCalendarIDs)
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        try? Persistence.save(store.snapshot, to: AppModel.stateURL)
        Notifier.shared.sync(store: store)
    }

    func select(_ newDay: Day) {
        day = newDay
        calendar.ensureLoaded(around: newDay)
    }

    func shiftDay(by days: Int) {
        select(day.adding(days: days, calendar: store.calendar))
    }

    func open(board id: UUID) {
        openBoardID = id
        tab = .boards
        sheet = nil
    }

    /// Places a task on the selected day, steering around calendar events.
    func schedule(_ taskID: UUID, on day: Day) {
        let busy = store.prefs.showCalendarInSequencer ? calendar.busy(on: day) : []
        if store.schedule(taskID, on: day, busy: busy) != nil { Haptics.success() }
    }

    func startFocus(taskID: UUID?, title: String? = nil) {
        Notifier.shared.requestPermission()
        store.startFocus(taskID: taskID, title: title)
        sheet = .focus
    }
}

enum DayText {
    static func title(_ day: Day, today: Day, calendar: Calendar = .current) -> String {
        let delta = day.days(since: today, calendar: calendar)
        switch delta {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default: return format(day, "EEEE", calendar)
        }
    }

    static func format(_ day: Day, _ template: String, _ calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.setLocalizedDateFormatFromTemplate(template)
        return f.string(from: day.date(atMinute: 720, calendar: calendar))
    }

    /// "Wed 18 Nov" in the user's locale.
    static func short(_ day: Day, _ calendar: Calendar = .current) -> String {
        format(day, "EEE d MMM", calendar)
    }

    static func dueChip(_ day: Day, today: Day, gentle: Bool, calendar: Calendar = .current) -> String {
        let delta = day.days(since: today, calendar: calendar)
        if delta == 0 { return "Today" }
        if delta == 1 { return "Tomorrow" }
        if delta < 0 { return Gentle.late(days: -delta, gentle: gentle) }
        if delta < 7 { return format(day, "EEE", calendar) }
        return format(day, "d MMM", calendar)
    }

    static func ago(_ date: Date, now: Date) -> String {
        let s = Int(now.timeIntervalSince(date))
        if s < 60 { return "just now" }
        if s < 3600 { return "\(s / 60)m ago" }
        if s < 86_400 { return "\(s / 3600)h ago" }
        return "\(s / 86_400)d ago"
    }
}
