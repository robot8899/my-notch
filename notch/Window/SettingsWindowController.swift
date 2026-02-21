import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    private static let windowWidth: CGFloat = 320
    private static let windowHeight: CGFloat = 280

    convenience init(settings: AppSettings) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.windowWidth, height: Self.windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentMinSize = NSSize(width: Self.windowWidth, height: Self.windowHeight)
        window.contentMaxSize = NSSize(width: Self.windowWidth, height: Self.windowHeight)

        let rootView = SettingsModalView(settings: settings) { [weak window] in
            window?.close()
        }
        window.contentView = NSHostingView(rootView: rootView)

        self.init(window: window)
    }

    func presentCentered() {
        guard let window else { return }
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let origin = NSPoint(
                x: frame.midX - Self.windowWidth / 2,
                y: frame.midY - Self.windowHeight / 2
            )
            window.setFrameOrigin(origin)
        } else {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}
