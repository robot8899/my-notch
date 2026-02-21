import Foundation

struct TodoItem: Identifiable, Codable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var reminderID: String?

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, createdAt: Date = Date(), reminderID: String? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.reminderID = reminderID
    }
}
