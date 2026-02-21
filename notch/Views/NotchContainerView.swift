import SwiftUI

enum NotchTab: String, CaseIterable {
    case todo = "待办"
    case clipboard = "剪切板"
    case fileDrop = "暂存"
    case music = "音乐"
    case status = "状态"

    var icon: String {
        switch self {
        case .todo: return "checkmark.square"
        case .status: return "gauge"
        case .music: return "music.note"
        case .clipboard: return "doc.on.clipboard"
        case .fileDrop: return "tray.and.arrow.down"
        }
    }
}

struct NotchContainerView: View {
    var todoStore: TodoStore
    var musicController: MusicController
    var clipboardMonitor: ClipboardMonitor
    var weatherService: WeatherService
    var fileDropStore: FileDropStore
    var onWindowFrameUpdate: (CGSize) -> Void
    var onOpenSettings: () -> Void
    var notchHeight: CGFloat
    var notchWidth: CGFloat = 210

    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var selectedTab: NotchTab = .status
    @State private var collapseTask: DispatchWorkItem?
    @State private var windowResizeTask: DispatchWorkItem?
    @State private var currentTime = ""
    @State private var currentDate = ""
    @State private var timer: Timer?
    @State private var showWeather = false
    @State private var carouselTimer: Timer?

    // Compact: narrow wings extending slightly beyond the notch
    private let compactWingExtra: CGFloat = 40 // each side extends 40pt beyond notch
    private var compactWidth: CGFloat { notchWidth + compactWingExtra * 2 }

    private let expandedWidth: CGFloat = 380
    private var expandedContentHeight: CGFloat { contentHeight(for: selectedTab) }
    private var expandedTotalHeight: CGFloat { notchHeight + expandedContentHeight }
    private let expandedTopInsetExtra: CGFloat = 18

    private let compactBottomPadding: CGFloat = 10

    private let maxContentHeight: CGFloat = 220
    private var maxExpandedHeight: CGFloat { notchHeight + maxContentHeight }
    private var expandedWindowSize: CGSize { CGSize(width: expandedWidth, height: maxExpandedHeight) }
    private var compactWindowSize: CGSize { CGSize(width: compactWidth, height: notchHeight + compactBottomPadding) }

    private var shouldUseExpandedFrame: Bool {
        isExpanded || fileDropStore.isDragSessionActive
    }

    private var currentFrameSize: CGSize {
        if shouldUseExpandedFrame {
            return CGSize(width: expandedWidth, height: expandedTotalHeight)
        } else {
            return CGSize(width: compactWidth, height: notchHeight + compactBottomPadding)
        }
    }

    private var musicIsPlaying: Bool {
        musicController.title != nil && musicController.isPlaying
    }

    private func cancelCollapseTask() {
        collapseTask?.cancel()
        collapseTask = nil
    }

    private func cancelWindowResizeTask() {
        windowResizeTask?.cancel()
        windowResizeTask = nil
    }

    private func performExpand() {
        cancelCollapseTask()
        cancelWindowResizeTask()
        onWindowFrameUpdate(expandedWindowSize)
        withAnimation {
            isExpanded = true
        }
    }

    private func scheduleCollapse(after delay: TimeInterval = 0.3) {
        cancelCollapseTask()
        cancelWindowResizeTask()
        let task = DispatchWorkItem {
            withAnimation {
                isExpanded = false
            }
            let resizeTask = DispatchWorkItem {
                onWindowFrameUpdate(compactWindowSize)
            }
            windowResizeTask = resizeTask
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: resizeTask)
        }
        collapseTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func switchToNextTab() {
        let all = NotchTab.allCases
        guard let idx = all.firstIndex(of: selectedTab) else { return }
        selectedTab = all[(idx + 1) % all.count]
    }

    private func switchToPreviousTab() {
        let all = NotchTab.allCases
        guard let idx = all.firstIndex(of: selectedTab) else { return }
        selectedTab = all[(idx - 1 + all.count) % all.count]
    }

    private func expandToMusic() {
        cancelCollapseTask()
        cancelWindowResizeTask()
        onWindowFrameUpdate(expandedWindowSize)
        withAnimation {
            selectedTab = .music
            isExpanded = true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Background shape
                NotchShape(bottomRadius: shouldUseExpandedFrame ? 26 : 12)
                    .fill(.black)
                    .shadow(color: .black.opacity(0), radius: 0, y: 0)

                if fileDropStore.isDragSessionActive {
                    dragHoverOverlay
                        .transition(.opacity)
                } else if isExpanded {
                    expandedContent
                        .padding(.top, notchHeight + expandedTopInsetExtra)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                } else {
                    compactContent
                        .transition(.opacity)
                }
            }
            .frame(
                width: shouldUseExpandedFrame ? expandedWidth : compactWidth,
                height: shouldUseExpandedFrame ? expandedTotalHeight : notchHeight
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.78), value: isExpanded)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: selectedTab)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: fileDropStore.isDragSessionActive)
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    if !isExpanded {
                        performExpand()
                    } else {
                        cancelCollapseTask()
                        cancelWindowResizeTask()
                    }
                } else if isExpanded && !fileDropStore.isDragSessionActive {
                    scheduleCollapse()
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            startClock()
            onWindowFrameUpdate(compactWindowSize)
            carouselTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    showWeather.toggle()
                }
            }
        }
        .onChange(of: fileDropStore.isDragSessionActive) {
            if fileDropStore.isDragSessionActive && !isExpanded {
                performExpand()
            } else if !fileDropStore.isDragSessionActive {
                if !fileDropStore.items.isEmpty {
                    cancelCollapseTask()
                    cancelWindowResizeTask()
                    onWindowFrameUpdate(expandedWindowSize)
                    withAnimation {
                        selectedTab = .fileDrop
                        isExpanded = true
                    }
                } else if isExpanded && !isHovering {
                    scheduleCollapse(after: 0)
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            carouselTimer?.invalidate()
            cancelCollapseTask()
            cancelWindowResizeTask()
        }
    }

    private func contentHeight(for tab: NotchTab) -> CGFloat {
        switch tab {
        case .clipboard, .fileDrop:
            return 220
        case .music, .status, .todo:
            return 145
        }
    }

    // MARK: - Clock

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt
    }()

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M/d EEE"
        return fmt
    }()

    private func startClock() {
        updateTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateTime()
        }
    }

    private func updateTime() {
        currentTime = Self.timeFormatter.string(from: Date())
        currentDate = Self.dateFormatter.string(from: Date())
    }

    // MARK: - Compact
    // Narrow wings alongside the physical notch

    private var compactContent: some View {
        HStack(spacing: 0) {
            // Left wing
            Group {
                if musicIsPlaying && !showWeather {
                    // 音乐封面
                    MiniArtworkView(artwork: musicController.artwork)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            expandToMusic()
                        }
                        .transition(.opacity)
                } else if showWeather {
                    WeatherIconView(weatherService: weatherService)
                        .transition(.opacity)
                } else {
                    CalendarIconView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showWeather)
            .frame(width: compactWingExtra, alignment: .center)

            Spacer().frame(width: notchWidth)

            // Right wing
            Group {
                if musicIsPlaying && !showWeather {
                    // 音频条
                    AudioBarsView()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            expandToMusic()
                        }
                        .transition(.opacity)
                } else {
                    Text(currentTime)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showWeather)
            .frame(width: compactWingExtra, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Drag Hover Overlay

    private var dragHoverOverlay: some View {
        HStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.blue.opacity(0.9))
            Text("释放以暂存")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.blue.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Expanded

    private var fileDropContent: some View {
        VStack(spacing: 0) {
            if fileDropStore.items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.25))
                    Text("拖拽文件到刘海区域即可暂存")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Spacer()
                    Button("清空") {
                        fileDropStore.clearAll()
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(fileDropStore.items) { item in
                            FileDropRowView(item: item, store: fileDropStore)
                        }
                    }
                }
            }
        }
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .todo:
                    TodoView(store: todoStore)
                case .status:
                    StatusView(weatherService: weatherService, onOpenSettings: onOpenSettings)
                case .music:
                    MusicView(controller: musicController)
                case .clipboard:
                    ClipboardView(monitor: clipboardMonitor)
                case .fileDrop:
                    fileDropContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                HorizontalSwipeDetector(
                    onSwipeLeft: { withAnimation(.easeInOut(duration: 0.2)) { switchToNextTab() } },
                    onSwipeRight: { withAnimation(.easeInOut(duration: 0.2)) { switchToPreviousTab() } }
                )
            )

            // Tab indicator bar
            HStack(spacing: 6) {
                ForEach(NotchTab.allCases, id: \.self) { tab in
                    Capsule()
                        .fill(.white.opacity(selectedTab == tab ? 0.8 : 0.2))
                        .frame(width: selectedTab == tab ? 24 : 8, height: 3)
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
            }
            .padding(.top, 6)
        }
    }
}

// MARK: - Marquee Text

struct MarqueeText: View {
    let text: String
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let needsScroll = textWidth > geo.size.width
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize()
                .background(GeometryReader { textGeo in
                    Color.clear.onAppear {
                        textWidth = textGeo.size.width
                        containerWidth = geo.size.width
                    }
                })
                .offset(x: needsScroll ? offset : 0)
                .onAppear {
                    guard needsScroll else { return }
                    startScrolling()
                }
                .onChange(of: text) {
                    offset = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if textWidth > containerWidth {
                            startScrolling()
                        }
                    }
                }
        }
        .clipped()
        .frame(height: 14)
    }

    private func startScrolling() {
        let distance = textWidth - containerWidth + 20
        withAnimation(.linear(duration: Double(distance) / 30).delay(1).repeatForever(autoreverses: true)) {
            offset = -distance
        }
    }
}

// MARK: - Mini Artwork

struct MiniArtworkView: View {
    let artwork: NSImage?

    var body: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Audio Bars Animation

struct AudioBarsView: View {
    let barCount = 4
    let maxHeight: CGFloat = 14
    let barWidth: CGFloat = 2.5
    let spacing: CGFloat = 1.5

    @State private var heights: [CGFloat] = []
    @State private var animationTimer: Timer?

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.75))
                    .frame(width: barWidth, height: heights.indices.contains(i) ? heights[i] : 3)
            }
        }
        .frame(height: maxHeight, alignment: .bottom)
        .onAppear { startAnimating() }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    private func startAnimating() {
        heights = (0..<barCount).map { _ in CGFloat.random(in: 3...maxHeight) }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                heights = (0..<barCount).map { _ in CGFloat.random(in: 3...maxHeight) }
            }
        }
    }
}

// MARK: - Calendar Icon

struct CalendarIconView: View {
    private static let monthFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "MMM"
        return fmt
    }()

    private var monthString: String {
        Self.monthFormatter.string(from: Date()).uppercased()
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: Date()))"
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(monthString)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.red.opacity(0.8))
            Text(dayNumber)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .offset(y: -1)
        }
        .frame(width: 28, height: 24)
    }
}

// MARK: - Horizontal Swipe Detector

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
