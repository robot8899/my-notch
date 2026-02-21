import Foundation

struct FileDropItem: Identifiable, Codable {
    var id: UUID = UUID()
    var originalName: String
    var storedFileName: String
    var fileSize: Int64
    var addedDate: Date
    var expiresDate: Date
    var uti: String

    var isExpired: Bool {
        Date() >= expiresDate
    }

    var storedURL: URL {
        FileDropItem.storageDirectory.appendingPathComponent(storedFileName)
    }

    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var remainingTimeString: String {
        let remaining = expiresDate.timeIntervalSince(Date())
        if remaining <= 0 { return "已过期" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        }
        return "\(minutes)分钟"
    }

    var isExpiringSoon: Bool {
        expiresDate.timeIntervalSince(Date()) < 3600 && !isExpired
    }

    static var storageDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("notchDrop/FileDrop", isDirectory: true)
    }
}
