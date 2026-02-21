import EventKit
import Foundation

@Observable
class RemindersService {
    let eventStore = EKEventStore()
    private(set) var accessGranted = false

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            await MainActor.run { accessGranted = granted }
            return granted
        } catch {
            await MainActor.run { accessGranted = false }
            return false
        }
    }

    func fetchReminders() async -> [EKReminder] {
        guard accessGranted else { return [] }

        let calendars = eventStore.calendars(for: .reminder)
        guard let defaultCal = eventStore.defaultCalendarForNewReminders(),
              calendars.contains(where: { $0.calendarIdentifier == defaultCal.calendarIdentifier }) else {
            return []
        }

        let predicate = eventStore.predicateForReminders(in: [defaultCal])
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    func createReminder(title: String) -> EKReminder? {
        guard accessGranted else { return nil }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        do {
            try eventStore.save(reminder, commit: true)
            return reminder
        } catch {
            return nil
        }
    }

    func toggleReminder(identifier: String, isCompleted: Bool) {
        guard accessGranted,
              let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }

        reminder.isCompleted = isCompleted
        try? eventStore.save(reminder, commit: true)
    }

    func deleteReminder(identifier: String) {
        guard accessGranted,
              let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }

        try? eventStore.remove(reminder, commit: true)
    }

    // Callback set by TodoStore to trigger sync
    var onStoreChanged: (() -> Void)?

    @objc private func storeChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.onStoreChanged?()
        }
    }
}
