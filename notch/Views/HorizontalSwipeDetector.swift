import SwiftUI

struct HorizontalSwipeDetector: NSViewRepresentable {
    var onSwipeLeft: () -> Void
    var onSwipeRight: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            context.coordinator.handleScroll(event)
            return event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onSwipeLeft = onSwipeLeft
        context.coordinator.onSwipeRight = onSwipeRight
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
            coordinator.monitor = nil
        }
    }

    class Coordinator {
        var onSwipeLeft: () -> Void
        var onSwipeRight: () -> Void
        var monitor: Any?
        private var accX: CGFloat = 0
        private var accY: CGFloat = 0
        private var isTracking = false
        private var hasFired = false
        private let threshold: CGFloat = 20
        private var lastSwipeTime: Date = .distantPast
        private let cooldown: TimeInterval = 0.35

        init(onSwipeLeft: @escaping () -> Void, onSwipeRight: @escaping () -> Void) {
            self.onSwipeLeft = onSwipeLeft
            self.onSwipeRight = onSwipeRight
        }

        func handleScroll(_ event: NSEvent) {
            if event.phase == .began {
                accX = 0
                accY = 0
                isTracking = true
                hasFired = false
            }

            guard isTracking else { return }

            accX += event.scrollingDeltaX
            accY += event.scrollingDeltaY

            if event.phase == .ended || event.phase == .cancelled {
                defer {
                    isTracking = false
                    accX = 0
                    accY = 0
                }
                guard !hasFired,
                      abs(accX) > abs(accY),
                      abs(accX) > threshold,
                      Date().timeIntervalSince(lastSwipeTime) > cooldown else { return }
                hasFired = true
                lastSwipeTime = Date()
                if accX < 0 {
                    onSwipeLeft()
                } else {
                    onSwipeRight()
                }
            }
        }
    }
}
