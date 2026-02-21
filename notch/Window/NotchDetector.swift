import AppKit

enum NotchDetector {
    static let defaultNotchWidth: CGFloat = 210
    static let defaultNotchHeight: CGFloat = 32

    static func hasNotch(on screen: NSScreen) -> Bool {
        guard #available(macOS 12.0, *) else { return false }
        return screen.safeAreaInsets.top > 0
    }

    /// Returns the notch rect in screen coordinates (origin at bottom-left).
    static func notchRect(on screen: NSScreen) -> NSRect {
        let frame = screen.frame
        if hasNotch(on: screen) {
            // Some devices/reporting paths return a smaller top inset than the visual notch depth.
            let notchHeight: CGFloat = max(defaultNotchHeight, screen.safeAreaInsets.top)
            let x = frame.midX - defaultNotchWidth / 2
            let y = frame.maxY - notchHeight
            return NSRect(x: x, y: y, width: defaultNotchWidth, height: notchHeight)
        } else {
            // No notch — place at top center
            let x = frame.midX - defaultNotchWidth / 2
            let y = frame.maxY - defaultNotchHeight
            return NSRect(x: x, y: y, width: defaultNotchWidth, height: defaultNotchHeight)
        }
    }

    /// Returns the physical notch width on the given screen.
    static func notchWidth(on screen: NSScreen) -> CGFloat {
        return notchRect(on: screen).width
    }

    /// Returns the physical notch height on the given screen.
    static func notchHeight(on screen: NSScreen) -> CGFloat {
        return notchRect(on: screen).height
    }

    /// Returns the screen that has a notch, or the main screen as fallback.
    static func notchScreen() -> NSScreen? {
        if let screen = NSScreen.screens.first(where: { hasNotch(on: $0) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }
}
