import Foundation

/// A calendar day with no time-of-day and no time zone, so "due Friday" stays Friday wherever you travel.
struct Day: Hashable, Codable, Comparable, CustomStringConvertible {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }

    static func today(calendar: Calendar = .current, now: Date = Date()) -> Day {
        Day(now, calendar: calendar)
    }

    static func < (a: Day, b: Day) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Midnight at the start of this day.
    func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }

    /// The moment `minutes` after midnight on this day.
    func date(atMinute minutes: Int, calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: minutes / 60, minute: minutes % 60))
            ?? date(calendar: calendar)
    }

    func adding(days: Int, calendar: Calendar = .current) -> Day {
        // Noon avoids daylight-saving edges.
        let noon = date(atMinute: 12 * 60, calendar: calendar)
        return Day(calendar.date(byAdding: .day, value: days, to: noon) ?? noon, calendar: calendar)
    }

    func adding(months: Int, calendar: Calendar = .current) -> Day {
        let noon = date(atMinute: 12 * 60, calendar: calendar)
        return Day(calendar.date(byAdding: .month, value: months, to: noon) ?? noon, calendar: calendar)
    }

    /// Whole days from `other` to this day (positive when this day is later).
    func days(since other: Day, calendar: Calendar = .current) -> Int {
        let a = other.date(atMinute: 12 * 60, calendar: calendar)
        let b = date(atMinute: 12 * 60, calendar: calendar)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// 1 = Sunday ... 7 = Saturday.
    func weekday(calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: date(atMinute: 12 * 60, calendar: calendar))
    }

    func isWeekend(calendar: Calendar = .current) -> Bool {
        let w = weekday(calendar: calendar)
        return w == 1 || w == 7
    }

    var firstOfMonth: Day { Day(year: year, month: month, day: 1) }

    /// First day of the week containing this day, honouring the calendar's first weekday.
    func startOfWeek(calendar: Calendar = .current) -> Day {
        let offset = (weekday(calendar: calendar) - calendar.firstWeekday + 7) % 7
        return adding(days: -offset, calendar: calendar)
    }

    /// The seven days of the week containing this day.
    func week(calendar: Calendar = .current) -> [Day] {
        let start = startOfWeek(calendar: calendar)
        return (0..<7).map { start.adding(days: $0, calendar: calendar) }
    }

    /// Six rows of seven days covering this day's month, padded with neighbouring months.
    func monthGrid(calendar: Calendar = .current) -> [Day] {
        let start = firstOfMonth.startOfWeek(calendar: calendar)
        return (0..<42).map { start.adding(days: $0, calendar: calendar) }
    }
}

/// Minutes since midnight, formatted for people.
enum Clock {
    static func label(_ minutes: Int, uses24Hour: Bool = false) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        let h = m / 60, mm = m % 60
        if uses24Hour { return String(format: "%02d:%02d", h, mm) }
        let h12 = h % 12 == 0 ? 12 : h % 12
        let suffix = h < 12 ? "AM" : "PM"
        return mm == 0 ? "\(h12) \(suffix)" : String(format: "%d:%02d %@", h12, mm, suffix)
    }

    static func duration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    static func minutes(of date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func snap(_ minutes: Int, to grid: Int = 15) -> Int {
        guard grid > 0 else { return minutes }
        return Int((Double(minutes) / Double(grid)).rounded()) * grid
    }
}
