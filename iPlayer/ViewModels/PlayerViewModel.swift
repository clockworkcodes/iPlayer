import Foundation
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {
    static let shared = PlayerViewModel()

    @Published var isShowingFullPlayer = false

    private let audioManager = AudioManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupBindings()
    }

    private func setupBindings() {
        audioManager.$currentSong
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var currentSong: Song? {
        audioManager.currentSong
    }

    var isPlaying: Bool {
        audioManager.isPlaying
    }

    var currentTime: TimeInterval {
        audioManager.currentTime
    }

    var duration: TimeInterval {
        audioManager.duration
    }

    var progress: Double {
        guard audioManager.duration > 0 else { return 0 }
        return audioManager.currentTime / audioManager.duration
    }

    var currentTimeString: String {
        formatTime(audioManager.currentTime)
    }

    var remainingTimeString: String {
        let remaining = max(0, audioManager.duration - audioManager.currentTime)
        return "-\(formatTime(remaining))"
    }

    var durationString: String {
        formatTime(audioManager.duration)
    }

    var isShuffled: Bool {
        audioManager.isShuffled
    }

    var repeatMode: AudioManager.RepeatMode {
        audioManager.repeatMode
    }

    func play(song: Song, from queue: [Song]? = nil) {
        audioManager.play(song: song, from: queue)
    }

    func playFromBeginning(queue: [Song], startIndex: Int = 0) {
        audioManager.playFromBeginning(queue: queue, startIndex: startIndex)
    }

    func playPlaylist(songs: [Song], shuffled: Bool = false) {
        audioManager.playPlaylist(songs: songs, shuffled: shuffled)
    }

    func togglePlayPause() {
        audioManager.togglePlayPause()
    }

    func next() {
        audioManager.next()
    }

    func previous() {
        audioManager.previous()
    }

    func seek(to time: TimeInterval) {
        audioManager.seek(to: time)
    }

    func toggleShuffle() {
        audioManager.toggleShuffle()
    }

    func cycleRepeatMode() {
        audioManager.cycleRepeatMode()
    }

    var currentQueue: [Song] {
        audioManager.currentQueue
    }

    var currentQueueIndex: Int {
        audioManager.currentQueueIndex
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN, !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
