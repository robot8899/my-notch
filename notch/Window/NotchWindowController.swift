import AppKit
import SwiftUI

class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

class NotchDropTargetView: NSView {
    var onDragEntered: ((NSDraggingInfo) -> NSDragOperation)?
    var onDragUpdated: ((NSDraggingInfo) -> NSDragOperation)?
    var onDragExited: (() -> Void)?
    var onPerformDrop: ((NSDraggingInfo) -> Bool)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?(sender) ?? []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragUpdated?(sender) ?? []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onPerformDrop?(sender) ?? false
    }
}

class NotchWindowController: NSWindowController {
    private static let supportedDragTypes: [NSPasteboard.PasteboardType] = [.fileURL, .URL, .tiff, .png]

    private var currentContentSize: CGSize = .zero
    private var dropTargetView: NotchDropTargetView?

    var fileDropStore: FileDropStore? {
        didSet { configureDragCallbacks() }
    }

    convenience init<Content: View>(rootView: Content) {
        let panel = NotchPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar + 1
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = false
        let dropTarget = NotchDropTargetView(frame: .zero)
        dropTarget.registerForDraggedTypes(Self.supportedDragTypes)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = dropTarget.bounds
        hostingView.autoresizingMask = [.width, .height]
        dropTarget.addSubview(hostingView)
        panel.contentView = dropTarget

        self.init(window: panel)
        self.dropTargetView = dropTarget
    }

    func updateWindowFrame(size: CGSize) {
        guard let panel = window else { return }
        guard let screen = NotchDetector.notchScreen() else { return }
        currentContentSize = size
        let screenFrame = screen.frame
        let x = screenFrame.midX - size.width / 2
        let y = screenFrame.maxY - size.height
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    func repositionWindow() {
        guard currentContentSize.width > 0 else { return }
        updateWindowFrame(size: currentContentSize)
    }

    // MARK: - Drag Callbacks

    private func configureDragCallbacks() {
        dropTargetView?.onDragEntered = { [weak self] sender in
            self?.handleDragEntered(sender) ?? []
        }
        dropTargetView?.onDragUpdated = { [weak self] sender in
            self?.handleDragUpdated(sender) ?? []
        }
        dropTargetView?.onDragExited = { [weak self] in
            self?.handleDragExited()
        }
        dropTargetView?.onPerformDrop = { [weak self] sender in
            self?.handlePerformDrop(sender) ?? false
        }

    }

    // MARK: - Drag Handling

    private func handleDragEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if fileDropStore?.isDragSessionActive == true {
            return .copy
        }

        let urls = extractFileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            debugDrag("entered rejected: no local file URLs")
            return []
        }
        fileDropStore?.isDragHovering = true
        fileDropStore?.isDragSessionActive = true
        debugDrag("entered accepted count=\(urls.count)")
        return .copy
    }

    private func handleDragUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if fileDropStore?.isDragSessionActive == true {
            // 根据鼠标 x 位置判断区域（窗口坐标，左半=暂存，右半=投送）
            if let panel = window {
                let location = sender.draggingLocation
                let midX = panel.frame.width / 2
                fileDropStore?.activeDropZone = location.x < midX ? .stage : .airdrop
            }
            return .copy
        }

        let urls = extractFileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            return []
        }
        fileDropStore?.isDragHovering = true
        fileDropStore?.isDragSessionActive = true
        return .copy
    }

    private func handleDragExited() {
        fileDropStore?.isDragHovering = false
        fileDropStore?.isDragSessionActive = false
        fileDropStore?.activeDropZone = .stage
        debugDrag("exited")
    }

    private func handlePerformDrop(_ sender: NSDraggingInfo) -> Bool {
        let urls = extractFileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            debugDrag("drop rejected: no local file URLs")
            handleDragExited()
            return false
        }

        let zone = fileDropStore?.activeDropZone ?? .stage
        fileDropStore?.lastDropZone = zone

        switch zone {
        case .stage:
            let acceptedCount = fileDropStore?.addFiles(from: urls) ?? 0
            debugDrag("drop accepted (stage) incoming=\(urls.count) accepted=\(acceptedCount)")
        case .airdrop:
            fileDropStore?.airdropFiles(from: urls)
            debugDrag("drop accepted (airdrop) count=\(urls.count)")
        }

        handleDragExited()
        return true
    }

    private func extractFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []

        if let directURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] {
            urls.append(contentsOf: directURLs.filter(\.isFileURL))
        }

        if urls.isEmpty {
            for item in pasteboard.pasteboardItems ?? [] {
                let raw = item.string(forType: .fileURL) ?? item.string(forType: .URL)
                guard let raw, let url = URL(string: raw), url.isFileURL else { continue }
                urls.append(url)
            }
        }

        var seenPaths = Set<String>()
        return urls.filter { url in
            let path = url.standardizedFileURL.path
            return seenPaths.insert(path).inserted
        }
    }

    private func debugDrag(_ message: String) {
#if DEBUG
        print("[NotchDrag] \(message)")
#endif
    }
}
