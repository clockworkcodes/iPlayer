import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var playerVM: PlayerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    backgroundGradient
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Handle
                        Capsule()
                            .fill(.tertiary)
                            .frame(width: 36, height: 5)
                            .padding(.top, 12)

                        Spacer()

                        // Artwork
                        let artworkSize = min(geometry.size.width - 64, 360)
                        if let song = playerVM.currentSong {
                            SongArtworkView(song: song, size: artworkSize)
                                .padding(.horizontal, 32)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.quaternary)
                                    .frame(width: artworkSize, height: artworkSize)

                                Image(systemName: "music.note")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        // Song Info
                        if let song = playerVM.currentSong {
                            VStack(spacing: 4) {
                                Text(song.title)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(song.artist)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 32)
                        }

                        // Progress
                        VStack(spacing: 6) {
                            Slider(
                                value: Binding(
                                    get: { isDragging ? dragProgress : playerVM.progress },
                                    set: { newValue in
                                        dragProgress = newValue
                                    }
                                ),
                                in: 0...1,
                                onEditingChanged: { editing in
                                    if editing {
                                        isDragging = true
                                    } else {
                                        isDragging = false
                                        let time = dragProgress * playerVM.duration
                                        playerVM.seek(to: time)
                                    }
                                }
                            )
                            .tint(.primary)

                            HStack {
                                Text(isDragging ? formatTime(dragProgress * playerVM.duration) : playerVM.currentTimeString)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(isDragging ? formatTime((1 - dragProgress) * playerVM.duration) : playerVM.remainingTimeString)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 16)

                        // Controls
                        HStack(spacing: 0) {
                            Button {
                                playerVM.toggleShuffle()
                            } label: {
                                Image(systemName: "shuffle")
                                    .font(.title2)
                                    .foregroundStyle(playerVM.isShuffled ? Color.accentColor : Color.secondary)
                                    .frame(width: 52, height: 52)
                            }

                            Spacer()

                            Button {
                                playerVM.previous()
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.title2)
                                    .foregroundStyle(.primary)
                                    .frame(width: 52, height: 52)
                            }

                            Spacer()

                            Button {
                                playerVM.togglePlayPause()
                            } label: {
                                Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 64))
                                    .foregroundStyle(.primary)
                            }

                            Spacer()

                            Button {
                                playerVM.next()
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.title2)
                                    .foregroundStyle(.primary)
                                    .frame(width: 52, height: 52)
                            }

                            Spacer()

                            Button {
                                playerVM.cycleRepeatMode()
                            } label: {
                                Image(systemName: playerVM.repeatMode.iconName)
                                    .font(.title2)
                                    .foregroundStyle(playerVM.repeatMode != .off ? Color.accentColor : Color.secondary)
                                    .frame(width: 52, height: 52)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Spacer()
                            .frame(height: 20)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private var backgroundGradient: some View {
        let topColor: Color = colorScheme == .dark
            ? .black.opacity(0.8)
            : .primary.opacity(0.08)

        return LinearGradient(
            colors: [
                topColor,
                .clear,
                .clear,
                .primary.opacity(0.05),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN, !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
