import Foundation
import UserNotifications

/// Local notifications: the end of each focus phase, and (optionally) the start of each time block.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Replaces everything pending with what the store currently calls for.
    func sync(store: MangoStore) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let now = store.now()
        var requests: [UNNotificationRequest] = []

        if let run = store.focusRun {
            let ends = run.upcomingPhaseEnds(after: now)
            for (index, item) in ends.enumerated() {
                let content = UNMutableNotificationContent()
                let isLast = index == ends.count - 1
                switch item.finishing.kind {
                case .focus:
                    content.title = "Focus round \(item.finishing.round) done"
                    content.body = "Time for a break."
                case .rest:
                    content.title = "Break over"
                    content.body = run.title.isEmpty ? "Back to it, gently." : "Back to \(run.title)."
                case .longRest:
                    content.title = "Focus cycle complete"
                    content.body = "Nice work."
                }
                if isLast && item.finishing.kind != .longRest { content.body = "Cycle complete." }
                content.sound = .default
                let interval = max(1, item.date.timeIntervalSince(now))
                requests.append(UNNotificationRequest(identifier: "focus-\(index)", content: content,
                                                      trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)))
            }
        }

        if store.prefs.blockAlerts {
            let today = store.today
            let horizon = today.adding(days: 7, calendar: store.calendar)
            let upcoming = store.blocks
                .filter { !$0.done && $0.day >= today && $0.day <= horizon }
                .map { (block: $0, date: $0.day.date(atMinute: $0.start, calendar: store.calendar)) }
                .filter { $0.date > now }
                .sorted { $0.date < $1.date }
                .prefix(40)
            for item in upcoming {
                let content = UNMutableNotificationContent()
                content.title = item.block.title
                content.body = "\(Clock.label(item.block.start)) for \(Clock.duration(item.block.length))"
                content.sound = .default
                let interval = max(1, item.date.timeIntervalSince(now))
                requests.append(UNNotificationRequest(identifier: "block-\(item.block.id.uuidString)", content: content,
                                                      trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)))
            }
        }

        for request in requests {
            center.add(request, withCompletionHandler: nil)
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
