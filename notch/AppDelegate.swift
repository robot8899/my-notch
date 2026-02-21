import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var remindersService = RemindersService()
    private var appSettings = AppSettings()
    private lazy var todoStore = TodoStore(remindersService: remindersService)
    private var musicController = MusicController()
    private lazy var clipboardMonitor = ClipboardMonitor(settings: appSettings)
    private var weatherService = WeatherService()
    private var fileDropStore = FileDropStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let screen = NotchDetector.notchScreen() else { return }
        setupWindow(on: screen)

        weatherService.startMonitoring()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenDidChange() {
        guard let screen = NotchDetector.notchScreen() else { return }
        setupWindow(on: screen)
    }

    private func setupWindow(on screen: NSScreen) {
        windowController?.window?.close()

        let containerView = NotchContainerView(
            todoStore: todoStore,
            musicController: musicController,
            clipboardMonitor: clipboardMonitor,
            weatherService: weatherService,
            fileDropStore: fileDropStore,
            onWindowFrameUpdate: { [weak self] size in
                self?.windowController?.updateWindowFrame(size: size)
            },
            onOpenSettings: { [weak self] in
                self?.showSettingsWindow()
            },
            notchHeight: NotchDetector.notchHeight(on: screen),
            notchWidth: NotchDetector.notchWidth(on: screen)
        )

        windowController = NotchWindowController(rootView: containerView)
        windowController?.fileDropStore = fileDropStore
        windowController?.showWindow(nil)
    }

    private func showSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(settings: appSettings)
        }
        settingsWindowController?.presentCentered()
    }
}
