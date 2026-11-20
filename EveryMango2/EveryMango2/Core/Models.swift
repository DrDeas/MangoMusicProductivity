import Foundation

/// The two "scenes" of the instrument. Each board lives in one; the scene switch filters the whole app.
enum SceneSlot: String, Codable, CaseIterable, Identifiable {
    case a, b
    var id: String { rawValue }
    var letter: String { rawValue.uppercased() }
}

enum SceneMode: String, Codable, CaseIterable, Identifiable {
    case a, b, dual
    var id: String { rawValue }

    func shows(_ slot: SceneSlot) -> Bool {
        switch self {
        case .dual: return true
        case .a: return slot == .a
        case .b: return slot == .b
        }
    }
}

enum Energy: String, Codable, CaseIterable, Identifiable, Comparable {
    case low, medium, high
    var id: String { rawValue }
    var rank: Int { self == .low ? 1 : (self == .medium ? 2 : 3) }
    var label: String { self == .low ? "Low" : (self == .medium ? "Med" : "High") }
    static func < (a: Energy, b: Energy) -> Bool { a.rank < b.rank }
}

enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case fresh = "new", working, stuck, done
    var id: String { rawValue }
    var label: String {
        switch self {
        case .fresh: return "Not started"
        case .working: return "Working"
        case .stuck: return "Stuck"
        case .done: return "Done"
        }
    }
    var short: String {
        switch self {
        case .fresh: return "New"
        case .working: return "Working"
        case .stuck: return "Stuck"
        case .done: return "Done"
        }
    }
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekdays, weekly, monthly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Off"
        case .daily: return "Every day"
        case .weekdays: return "Weekdays"
        case .weekly: return "Every week"
        case .monthly: return "Every month"
        }
    }

    /// The next due day strictly after `day`.
    func next(after day: Day, calendar: Calendar = .current) -> Day? {
        switch self {
        case .none: return nil
        case .daily: return day.adding(days: 1, calendar: calendar)
        case .weekly: return day.adding(days: 7, calendar: calendar)
        case .monthly: return day.adding(months: 1, calendar: calendar)
        case .weekdays:
            var d = day.adding(days: 1, calendar: calendar)
            while d.isWeekend(calendar: calendar) { d = d.adding(days: 1, calendar: calendar) }
            return d
        }
    }
}

/// The time estimates a task can have. Stepped, like a synth's stepped slider.
enum Estimate {
    static let steps = [5, 15, 30, 45, 60, 90, 120, 180, 240]
    static let quickWin = 15

    static func nearestIndex(to minutes: Int) -> Int {
        var best = 0
        for (i, s) in steps.enumerated() where abs(s - minutes) < abs(steps[best] - minutes) { best = i }
        return best
    }
}

struct Step: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var done = false
}

struct MangoTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var boardID: UUID
    var status: TaskStatus = .fresh
    var notes = ""
    var why = ""
    var stuckNote = ""
    var estimate = 30
    var energy: Energy = .medium
    var due: Day?
    var repeatRule: RepeatRule = .none
    var steps: [Step] = []
    var createdAt = Date()
    var completedAt: Date?
    /// How many times a Fresh Start has carried this task forward.
    var carried = 0
    var focusSessions = 0

    var isDone: Bool { status == .done }
    var isQuickWin: Bool { estimate <= Estimate.quickWin }
    var stepProgress: Double {
        steps.isEmpty ? (isDone ? 1 : 0) : Double(steps.filter(\.done).count) / Double(steps.count)
    }
}

struct Board: Identifiable, Codable, Hashable {
    enum Kind: String, Codable { case normal, inbox, someday }

    var id = UUID()
    var name: String
    /// Index into the skin's channel colours.
    var hue = 0
    var scene: SceneSlot = .a
    var kind: Kind = .normal
    var createdAt = Date()
}

/// One brain-dump entry: captured now, routed later.
struct Thought: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var createdAt = Date()
}

struct Note: Identifiable, Codable, Hashable {
    var id = UUID()
    var title = ""
    var body = ""
    var boardID: UUID?
    var pinned = false
    var createdAt = Date()
    var updatedAt = Date()

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let first = body.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return first.isEmpty ? "Untitled note" : first
    }
}

/// A block of time on a day. May be linked to a task, or stand alone ("Lunch").
struct TimeBlock: Identifiable, Codable, Hashable {
    var id = UUID()
    var day: Day
    /// Minutes since midnight.
    var start: Int
    var length: Int
    var title: String
    var taskID: UUID?
    var hue = 0
    var done = false
    /// Identifier of the device-calendar event this block was copied to, if any.
    var eventID: String?

    var end: Int { start + length }
    var span: Span { Span(start: start, end: end) }
}

struct Prefs: Codable, Hashable {
    var darkSkin = false
    var sceneAName = "Work"
    var sceneBName = "Life"
    var sceneMode: SceneMode = .dual
    /// Visible range of the sequencer, minutes since midnight.
    var dayStart = 7 * 60
    var dayEnd = 22 * 60
    /// Hours you want to plan per day; drives the load meter.
    var capacityHours = 6.0
    var gentle = true
    var haptics = true
    var blockAlerts = false
    var focus = FocusPlan()
    var energyToday: Energy?
    var energyDay: Day?
    var hiddenCalendarIDs: [String] = []
    var showCalendarInSequencer = true
    /// Filter section: longest task to show (nil = open) and highest energy to show.
    var cutoffMinutes: Int?
    var energyCeiling: Energy?
    var hasSeenWelcome = false

    func sceneName(_ slot: SceneSlot) -> String { slot == .a ? sceneAName : sceneBName }
}

/// Everything the app persists, in one Codable value.
struct Snapshot: Codable, Equatable {
    var version = 1
    var boards: [Board] = []
    var tasks: [MangoTask] = []
    var thoughts: [Thought] = []
    var notes: [Note] = []
    var blocks: [TimeBlock] = []
    /// Up to three task ids: the "oscillators" on the dashboard.
    var focusIDs: [UUID] = []
    var prefs = Prefs()
    var focusRun: FocusRun?
}

/// Where a brain-dump thought can be sent.
enum Route: Equatable {
    case today
    case board(UUID)
    case someday
    case note
}

/// Softer language for late things. "3 days overdue" becomes "3d ago".
enum Gentle {
    static func late(days: Int, gentle: Bool) -> String {
        if gentle { return days == 1 ? "from yesterday" : "\(days)d ago" }
        return days == 1 ? "1 day overdue" : "\(days) days overdue"
    }

    static func carriedTitle(gentle: Bool) -> String { gentle ? "Carried over" : "Overdue" }

    static let cheers = [
        "Done. One more mango in the basket.",
        "Nice, that one's ripe.",
        "Lovely. You did the thing.",
        "Finished. Small wins add up.",
        "Sweet. On to whatever feels right next.",
    ]
}
