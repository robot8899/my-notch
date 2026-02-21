import SwiftUI

struct MusicView: View {
    var controller: MusicController

    var body: some View {
        VStack(spacing: 8) {
            if controller.isAvailable && controller.title != nil {
                nowPlayingView
            } else {
                noMusicView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var nowPlayingView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                // Album art
                if let artwork = controller.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.1))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.title ?? "")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(controller.artist ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()
            }

            // Progress bar
            if controller.duration > 0 {
                VStack(spacing: 2) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(.white.opacity(0.15))
                                .frame(height: 3)

                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(.white.opacity(0.8))
                                .frame(
                                    width: geo.size.width * min(controller.elapsedTime / controller.duration, 1.0),
                                    height: 3
                                )
                        }
                    }
                    .frame(height: 3)

                    HStack {
                        Text(formatTime(controller.elapsedTime))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        Text(formatTime(controller.duration))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            // Controls
            HStack(spacing: 20) {
                Button(action: controller.previousTrack) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button(action: controller.togglePlayPause) {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: controller.nextTrack) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var noMusicView: some View {
        VStack(spacing: 6) {
            Image(systemName: "music.note.list")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.3))
            Text("没有正在播放的音乐")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
