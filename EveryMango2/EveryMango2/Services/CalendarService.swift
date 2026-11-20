import SwiftUI
import EventKit

/// Reads (and writes) the calendars already on the phone: iCloud, Google, Exchange, anything iOS syncs.
@Observable
final class CalendarService {
    struct Event: Identifiable, Hashable {
        /// Unique per occurrence, so repeating events can sit in one list.
        let id: String
        let eventID: String
        let title: String
        let start: Date
        let end: Date
        let allDay: Bool
        let calendarID: String
        let calendarTitle: String
        let color: Color
        let location: String
    }

    struct CalendarInfo: Identifiable, Hashable {
        let id: String
        let title: String
        let source: String
        let color: Color
        let writable: Bool
    }

    private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    private(set) var calendars: [CalendarInfo] = []
    private(set) var byDay: [Day: [Event]] = [:]

    @ObservationIgnored let ek = EKEventStore()
    @ObservationIgnored private var loadedFrom: Day?
    @ObservationIgnored private var loadedTo: Day?
    @ObservationIgnored private var hidden: Set<String> = []
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored var calendar: Calendar = .current

    init() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: ek, queue: .main) { [weak self] _ in
            self?.reload()
        }
        if hasAccess { loadCalendars() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    var hasAccess: Bool { status == .fullAccess }
    var wasDenied: Bool { status == .denied || status == .restricted || status == .writeOnly }

    @MainActor
    func requestAccess() async {
        _ = try? await ek.requestFullAccessToEvents()
        status = EKEventStore.authorizationStatus(for: .event)
        if hasAccess {
            loadCalendars()
            reload()
        }
    }

    func refreshStatus() {
        let now = EKEventStore.authorizationStatus(for: .event)
        if now != status {
            status = now
            if hasAccess {
                loadCalendars()
                reload()
            }
        }
    }

    private func loadCalendars() {
        calendars = ek.calendars(for: .event)
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, source: $0.source?.title ?? "",
                                color: Color(cgColor: $0.cgColor), writable: $0.allowsContentModifications) }
            .sorted { ($0.source, $0.title) < ($1.source, $1.title) }
    }

    func setHidden(_ ids: [String]) {
        let set = Set(ids)
        if set != hidden {
            hidden = set
            reload()
        }
    }

    /// Makes sure events are loaded for the months around `day`.
    func ensureLoaded(around day: Day) {
        guard hasAccess else { return }
        if let from = loadedFrom, let to = loadedTo,
           day.adding(days: -40, calendar: calendar) >= from, day.adding(days: 40, calendar: calendar) <= to {
            return
        }
        loadedFrom = day.firstOfMonth.adding(months: -2, calendar: calendar)
        loadedTo = day.firstOfMonth.adding(months: 4, calendar: calendar)
        reload()
    }

    func reload() {
        guard hasAccess, let from = loadedFrom, let to = loadedTo else {
            byDay = [:]
            return
        }
        loadCalendars()
        let shown = ek.calendars(for: .event).filter { !hidden.contains($0.calendarIdentifier) }
        guard !shown.isEmpty else {
            byDay = [:]
            return
        }
        let predicate = ek.predicateForEvents(withStart: from.date(calendar: calendar), end: to.date(calendar: calendar), calendars: shown)
        var result: [Day: [Event]] = [:]
        for e in ek.events(matching: predicate) {
            guard let start = e.startDate, let end = e.endDate else { continue }
            let event = Event(id: "\(e.eventIdentifier ?? UUID().uuidString)-\(start.timeIntervalSince1970)",
                              eventID: e.eventIdentifier ?? "", title: e.title ?? "Untitled",
                              start: start, end: end, allDay: e.isAllDay,
                              calendarID: e.calendar.calendarIdentifier, calendarTitle: e.calendar.title,
                              color: Color(cgColor: e.calendar.cgColor), location: e.location ?? "")
            var day = Day(start, calendar: calendar)
            let last = Day(max(start, end.addingTimeInterval(-1)), calendar: calendar)
            var guardCount = 0
            while day <= last && guardCount < 60 {
                result[day, default: []].append(event)
                day = day.adding(days: 1, calendar: calendar)
                guardCount += 1
            }
        }
        for key in result.keys {
            result[key]?.sort { a, b in
                a.allDay != b.allDay ? a.allDay : (a.start, a.title) < (b.start, b.title)
            }
        }
        byDay = result
    }

    func events(on day: Day) -> [Event] {
        byDay[day] ?? []
    }

    /// The part of an event that falls on `day`, in minutes since midnight.
    func span(of event: Event, on day: Day) -> Span {
        let startDay = Day(event.start, calendar: calendar)
        let endDay = Day(event.end, calendar: calendar)
        let start = startDay < day ? 0 : Clock.minutes(of: event.start, calendar: calendar)
        var end = endDay > day ? 1440 : Clock.minutes(of: event.end, calendar: calendar)
        if end <= start { end = min(1440, start + 15) }
        return Span(start: start, end: end)
    }

    /// Timed events on a day, for the sequencer to schedule around.
    func busy(on day: Day) -> [Span] {
        events(on: day).filter { !$0.allDay }.map { span(of: $0, on: day) }
    }

    func ekEvent(_ eventID: String) -> EKEvent? {
        ek.event(withIdentifier: eventID)
    }

    func newEvent(on day: Day, startMinute: Int) -> EKEvent {
        let e = EKEvent(eventStore: ek)
        e.startDate = day.date(atMinute: startMinute, calendar: calendar)
        e.endDate = day.date(atMinute: min(1439, startMinute + 60), calendar: calendar)
        e.calendar = ek.defaultCalendarForNewEvents
        return e
    }

    /// Copies a time block into the default calendar and returns the new event's identifier.
    func addToCalendar(_ block: TimeBlock) throws -> String {
        let e = EKEvent(eventStore: ek)
        e.title = block.title
        e.startDate = block.day.date(atMinute: block.start, calendar: calendar)
        e.endDate = block.day.date(atMinute: min(block.end, 1439), calendar: calendar)
        e.calendar = ek.defaultCalendarForNewEvents
        try ek.save(e, span: .thisEvent, commit: true)
        return e.eventIdentifier ?? ""
    }
}
