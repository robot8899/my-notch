import SwiftUI

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
                if hovering && isExpanded {
                    cancelCollapseTask()
                    cancelWindowResizeTask()
                } else if !hovering && isExpanded && !fileDropStore.isDragSessionActive {
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
                if fileDropStore.lastDropZone == .stage && !fileDropStore.items.isEmpty {
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
        .contentShape(Rectangle())
        .onTapGesture {
            performExpand()
        }
    }

    // MARK: - Drag Hover Overlay

    private var dragHoverOverlay: some View {
        HStack(spacing: 0) {
            // 左侧：暂存
            VStack(spacing: 4) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 20, weight: .medium))
                Text("暂存")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(fileDropStore.activeDropZone == .stage
                ? .blue.opacity(0.9) : .white.opacity(0.3))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 分隔线
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(width: 1)
                .padding(.vertical, 12)

            // 右侧：投送
            VStack(spacing: 4) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20, weight: .medium))
                Text("投送")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(fileDropStore.activeDropZone == .airdrop
                ? .blue.opacity(0.9) : .white.opacity(0.3))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, notchHeight)
        .animation(.easeInOut(duration: 0.15), value: fileDropStore.activeDropZone)
    }

    // MARK: - Expanded

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
                    FileDropContentView(store: fileDropStore)
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
