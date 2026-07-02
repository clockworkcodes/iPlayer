import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @EnvironmentObject private var audioManager: AudioManager
    @State private var showingPlayer = false

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 12) {
                // Tap the artwork + info area to open full player
                Button {
                    showingPlayer = true
                } label: {
                    HStack(spacing: 12) {
                        artworkView
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(playerViewModel.currentSong?.title ?? "No Song Playing")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(playerViewModel.currentSong?.artist ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Play/Pause
                Button {
                    playerViewModel.togglePlayPause()
                } label: {
                    Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                // Forward
                Button {
                    playerViewModel.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .sheet(isPresented: $showingPlayer) {
                PlayerView()
                    .environmentObject(playerViewModel)
                    .environmentObject(audioManager)
            }
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let song = playerViewModel.currentSong {
            SongArtworkView(song: song, size: 44)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)

                Image(systemName: "music.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
