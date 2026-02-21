import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@Observable
class FileDropStore {
    private static let storageKey = "notch.filedrop.items.v1"

    var items: [FileDropItem] = []
    var isDragHovering = false
    var isDragSessionActive = false

    private var cleanupTimer: Timer?

    init() {
        ensureStorageDirectory()
        loadItems()
        pruneExpiredItems()
        saveItems()
        startCleanupTimer()
    }

    deinit {
        cleanupTimer?.invalidate()
    }

    // MARK: - Public

    @discardableResult
    func addFiles(from urls: [URL]) -> Int {
        // Capture security-scoped access on the main thread before dispatching
        let accessTokens = urls.map { url -> (URL, Bool) in
            let accessing = url.startAccessingSecurityScopedResource()
            return (url, accessing)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var newItems: [FileDropItem] = []
            for (url, accessing) in accessTokens {
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                guard url.isFileURL else { continue }

                let originalName = url.lastPathComponent
                let storedFileName = "\(UUID().uuidString)_\(originalName)"
                let destination = FileDropItem.storageDirectory.appendingPathComponent(storedFileName)

                do {
                    try FileManager.default.copyItem(at: url, to: destination)

                    let attrs = try FileManager.default.attributesOfItem(atPath: destination.path)
                    let fileSize = (attrs[.size] as? Int64) ?? 0

                    let uti = UTType(filenameExtension: url.pathExtension)?.identifier ?? "public.data"
                    let now = Date()
                    let item = FileDropItem(
                        originalName: originalName,
                        storedFileName: storedFileName,
                        fileSize: fileSize,
                        addedDate: now,
                        expiresDate: now.addingTimeInterval(24 * 3600),
                        uti: uti
                    )
                    newItems.append(item)
                } catch {
                    print("[FileDropStore] Failed to copy \(originalName): \(error)")
                }
            }

            DispatchQueue.main.async {
                guard let self, !newItems.isEmpty else { return }
                for newItem in newItems {
                    if let idx = self.items.firstIndex(where: {
                        $0.originalName == newItem.originalName && $0.fileSize == newItem.fileSize
                    }) {
                        let old = self.items.remove(at: idx)
                        try? FileManager.default.removeItem(at: old.storedURL)
                    }
                }
                self.items.insert(contentsOf: newItems, at: 0)
                self.saveItems()
            }
        }
        return urls.count
    }

    func removeItem(_ item: FileDropItem) {
        try? FileManager.default.removeItem(at: item.storedURL)
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func clearAll() {
        for item in items {
            try? FileManager.default.removeItem(at: item.storedURL)
        }
        items.removeAll()
        saveItems()
    }

    func airdrop(_ item: FileDropItem) {
        guard FileManager.default.fileExists(atPath: item.storedURL.path) else { return }
        guard let service = NSSharingService(named: .sendViaAirDrop) else { return }
        service.perform(withItems: [item.storedURL])
    }

    func fileIcon(for item: FileDropItem) -> NSImage {
        if FileManager.default.fileExists(atPath: item.storedURL.path) {
            return NSWorkspace.shared.icon(forFile: item.storedURL.path)
        }
        return NSWorkspace.shared.icon(for: UTType(item.uti) ?? .data)
    }

    // MARK: - Private

    private func ensureStorageDirectory() {
        let dir = FileDropItem.storageDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.pruneExpiredItems()
            self?.saveItems()
        }
    }

    private func pruneExpiredItems() {
        let expired = items.filter { $0.isExpired }
        for item in expired {
            try? FileManager.default.removeItem(at: item.storedURL)
        }
        items.removeAll { $0.isExpired }
    }

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([FileDropItem].self, from: data) else { return }
        items = decoded.filter { FileManager.default.fileExists(atPath: $0.storedURL.path) }
    }
}
