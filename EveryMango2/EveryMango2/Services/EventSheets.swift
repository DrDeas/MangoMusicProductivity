import SwiftUI
import EventKit
import EventKitUI

/// Apple's own event editor, so creating an event has every option the Calendar app has:
/// repeats, alerts, invitees, travel time, which calendar.
struct EventEditor: UIViewControllerRepresentable {
    let store: EKEventStore
    let event: EKEvent
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: { dismiss() })
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let vc = EKEventEditViewController()
        vc.eventStore = store
        vc.event = event
        vc.editViewDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: () -> Void

        init(dismiss: @escaping () -> Void) {
            self.dismiss = dismiss
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}

/// Apple's event detail screen, with editing and deleting.
struct EventViewer: UIViewControllerRepresentable {
    let event: EKEvent
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: { dismiss() })
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = EKEventViewController()
        vc.event = event
        vc.allowsEditing = true
        vc.allowsCalendarPreview = true
        vc.delegate = context.coordinator
        return UINavigationController(rootViewController: vc)
    }

    func updateUIViewController(_ vc: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, EKEventViewDelegate {
        let dismiss: () -> Void

        init(dismiss: @escaping () -> Void) {
            self.dismiss = dismiss
        }

        func eventViewController(_ controller: EKEventViewController, didCompleteWith action: EKEventViewAction) {
            dismiss()
        }
    }
}
