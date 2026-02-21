import EventKit
import Foundation

@Observable
class TodoStore {
    private static let storageKey = "notch.todoItems"

    var items: [TodoItem] = []
    private let remindersService: RemindersService?
    private var isSyncing = false

    init(remindersService: RemindersService? = nil) {
        self.remindersService = remindersService
        loadItems()

        if let service = remindersService {
            service.onStoreChanged = { [weak self] in
                self?.syncFromReminders()
            }
            Task {
                let granted = await service.requestAccess()
                if granted {
                    await MainActor.run { self.syncFromReminders() }
                }
            }
        }
    }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let reminderID: String? = if let service = remindersService, service.accessGranted,
           let reminder = service.createReminder(title: trimmed) {
            reminder.calendarItemIdentifier
        } else {
            nil
        }
        let item = TodoItem(title: trimmed, reminderID: reminderID)
        items.insert(item, at: 0)
        saveItems()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isCompleted.toggle()

        if let reminderID = items[index].reminderID {
            remindersService?.toggleReminder(identifier: reminderID, isCompleted: items[index].isCompleted)
        }
        saveItems()
    }

    func delete(_ item: TodoItem) {
        if let reminderID = item.reminderID {
            remindersService?.deleteReminder(identifier: reminderID)
        }
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    // MARK: - Sync

    private func syncFromReminders() {
        guard let service = remindersService, service.accessGranted, !isSyncing else { return }
        isSyncing = true

        Task {
            let reminders = await service.fetchReminders()
            await MainActor.run {
                mergeReminders(reminders)
                isSyncing = false
            }
        }
    }

    private func mergeReminders(_ reminders: [EKReminder]) {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentReminders = reminders.filter { reminder in
            let date = reminder.creationDate ?? Date.distantPast
            return date >= oneWeekAgo || !reminder.isCompleted
        }

        let remoteByID = Dictionary(uniqueKeysWithValues: recentReminders.map { ($0.calendarItemIdentifier, $0) })
        var merged: [TodoItem] = []
        var seenRemoteIDs = Set<String>()

        // Update existing local items
        for var item in items {
            if let rid = item.reminderID, let remote = remoteByID[rid] {
                seenRemoteIDs.insert(rid)
                item.title = remote.title ?? item.title
                item.isCompleted = remote.isCompleted
                merged.append(item)
            } else if item.reminderID == nil {
                // Local-only item (no reminder link), keep it
                merged.append(item)
            }
            // If item has reminderID but not found in filtered set → out of range or deleted, drop it
        }

        // Add new reminders from system
        for reminder in recentReminders {
            let rid = reminder.calendarItemIdentifier
            if !seenRemoteIDs.contains(rid) {
                let newItem = TodoItem(
                    title: reminder.title ?? "",
                    isCompleted: reminder.isCompleted,
                    createdAt: reminder.creationDate ?? Date(),
                    reminderID: rid
                )
                merged.append(newItem)
            }
        }

        items = merged
        saveItems()
    }

    // MARK: - Local Persistence

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else { return }
        items = decoded
    }
}
