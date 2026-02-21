import Foundation

struct ClipboardItem: Identifiable, Codable {
    var id: UUID
    var content: String
    var imageFileName: String?
    var timestamp: Date
    var type: ClipboardItemType

    init(id: UUID = UUID(), content: String, timestamp: Date, type: ClipboardItemType) {
        self.id = id
        self.content = content
        self.imageFileName = nil
        self.timestamp = timestamp
        self.type = type
    }

    init(id: UUID = UUID(), imageFileName: String, timestamp: Date) {
        self.id = id
        self.content = ""
        self.imageFileName = imageFileName
        self.timestamp = timestamp
        self.type = .image
    }

    // MARK: - Image Storage

    static var imageStorageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("notchDrop/ClipboardImages", isDirectory: true)
    }

    var imageURL: URL? {
        guard let imageFileName else { return nil }
        return Self.imageStorageDirectory.appendingPathComponent(imageFileName)
    }

    var imageData: Data? {
        guard let imageURL, FileManager.default.fileExists(atPath: imageURL.path) else { return nil }
        return try? Data(contentsOf: imageURL)
    }
}

enum ClipboardItemType: String, Codable {
    case text
    case url
    case image
}
