import AppKit
import Foundation

// Swift typealias for MediaRemote C function pointers
private typealias MRGetNowPlayingInfo = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
private typealias MRRegisterForNotifications = @convention(c) (DispatchQueue) -> Void
private typealias MRSendCommand = @convention(c) (MRCommand, NSDictionary?) -> Void
private typealias MRGetIsPlaying = @convention(c) (DispatchQueue, @escaping (DarwinBoolean) -> Void) -> Void

@Observable
class MusicController {
    var title: String?
    var artist: String?
    var album: String?
    var artwork: NSImage?
    var duration: Double = 0
    var elapsedTime: Double = 0
    var isPlaying: Bool = false
    var isAvailable: Bool = false

    private var handle: UnsafeMutableRawPointer?
    private var fnGetNowPlayingInfo: MRGetNowPlayingInfo?
    private var fnRegisterForNotifs: MRRegisterForNotifications?
    private var fnSendCommand: MRSendCommand?
    private var fnGetIsPlaying: MRGetIsPlaying?
    private var timer: Timer?

    init() {
        loadFramework()
        guard isAvailable else { return }
        registerNotifications()
        fetchNowPlaying()
        startPolling()
    }

    deinit {
        timer?.invalidate()
        if let handle { dlclose(handle) }
    }

    // MARK: - Public

    func togglePlayPause() {
        fnSendCommand?(kMRCommandTogglePlayPause, nil)
    }

    func nextTrack() {
        fnSendCommand?(kMRCommandNextTrack, nil)
    }

    func previousTrack() {
        fnSendCommand?(kMRCommandPreviousTrack, nil)
    }

    // MARK: - Private

    private func loadFramework() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        guard let h = dlopen(path, RTLD_NOW) else {
            print("[MusicController] Failed to load MediaRemote: \(String(cString: dlerror()))")
            return
        }
        handle = h

        if let sym = dlsym(h, "MRMediaRemoteGetNowPlayingInfo") {
            fnGetNowPlayingInfo = unsafeBitCast(sym, to: MRGetNowPlayingInfo.self)
        }
        if let sym = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            fnRegisterForNotifs = unsafeBitCast(sym, to: MRRegisterForNotifications.self)
        }
        if let sym = dlsym(h, "MRMediaRemoteSendCommand") {
            fnSendCommand = unsafeBitCast(sym, to: MRSendCommand.self)
        }
        if let sym = dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying") {
            fnGetIsPlaying = unsafeBitCast(sym, to: MRGetIsPlaying.self)
        }

        isAvailable = (fnGetNowPlayingInfo != nil && fnGetIsPlaying != nil)
    }

    private func registerNotifications() {
        fnRegisterForNotifs?(.main)

        let nc = NotificationCenter.default
        nc.addObserver(
            self,
            selector: #selector(nowPlayingInfoChanged),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(playingStateChanged),
            name: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification"),
            object: nil
        )
    }

    @objc private func nowPlayingInfoChanged() {
        fetchNowPlaying()
    }

    @objc private func playingStateChanged() {
        fetchIsPlaying()
    }

    private func fetchNowPlaying() {
        fnGetNowPlayingInfo?(.main) { [weak self] info in
            guard let self else { return }

            guard let dict = info else {
                self.title = nil
                self.artist = nil
                self.album = nil
                self.artwork = nil
                self.duration = 0
                self.elapsedTime = 0
                return
            }

            self.title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String
            self.artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String
            self.album = dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String
            self.duration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0
            self.elapsedTime = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0

            if let artworkData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                self.artwork = NSImage(data: artworkData)
            } else {
                self.artwork = nil
            }
        }
        fetchIsPlaying()
    }

    private func fetchIsPlaying() {
        fnGetIsPlaying?(.main) { [weak self] playing in
            self?.isPlaying = playing.boolValue
        }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.isPlaying else { return }
            self.elapsedTime += 1.0
            if self.elapsedTime > self.duration && self.duration > 0 {
                self.elapsedTime = self.duration
            }
        }
    }
}
