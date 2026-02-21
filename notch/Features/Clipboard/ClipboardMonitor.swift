import AppKit
import Foundation
import Observation

@Observable
class ClipboardMonitor {
    private static let storageKey = "notch.clipboard.items.v1"

    var items: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let settings: AppSettings

    // Concealed type used by password managers
    private let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    private let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]

    init(settings: AppSettings) {
        self.settings = settings

        ensureImageStorageDirectory()
        loadItems()
        pruneExpiredItems()
        saveItems()

        settings.onClipboardRetentionChanged = { [weak self] in
            self?.refreshRetentionPolicy()
        }

        lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()

        if let data = item.imageData {
            pb.setData(data, forType: .png)
        } else {
            pb.setString(item.content, forType: .string)
        }
        lastChangeCount = pb.changeCount
    }

    func clearAll() {
        for item in items {
            if let url = item.imageURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        items.removeAll()
        saveItems()
    }

    func refreshRetentionPolicy() {
        pruneExpiredItems()
        saveItems()
    }

    // MARK: - Private

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        // Skip concealed/password content
        if pb.types?.contains(concealedType) == true { return }

        // Check for image first
        if let types = pb.types, types.contains(where: { imageTypes.contains($0) }),
           let nsImage = NSImage(pasteboard: pb),
           let pngData = nsImage.pngData() {
            // Deduplicate: skip if same image as most recent
            if let first = items.first, first.type == .image, first.imageData == pngData { return }

            let fileName = "\(UUID().uuidString).png"
            let fileURL = ClipboardItem.imageStorageDirectory.appendingPathComponent(fileName)
            do {
                try pngData.write(to: fileURL)
            } catch {
                print("[ClipboardMonitor] Failed to save image: \(error)")
                return
            }

            let item = ClipboardItem(imageFileName: fileName, timestamp: Date())
            items.insert(item, at: 0)
            pruneExpiredItems()
            saveItems()
            return
        }

        // Fall back to text
        guard let content = pb.string(forType: .string), !content.isEmpty else { return }

        // Avoid duplicates of the most recent item
        if let first = items.first, first.content == content { return }

        let type: ClipboardItemType = content.hasPrefix("http://") || content.hasPrefix("https://") ? .url : .text
        let item = ClipboardItem(content: content, timestamp: Date(), type: type)

        items.insert(item, at: 0)
        pruneExpiredItems()
        saveItems()
    }

    private func pruneExpiredItems() {
        guard let retentionDays = settings.clipboardRetentionDays.days,
              let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) else {
            return
        }

        let expired = items.filter { $0.timestamp < cutoff }
        for item in expired {
            if let url = item.imageURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        items.removeAll { $0.timestamp < cutoff }
    }

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        items = decoded
    }

    private func ensureImageStorageDirectory() {
        let dir = ClipboardItem.imageStorageDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

// MARK: - NSImage PNG Helper

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
