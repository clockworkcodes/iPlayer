import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()

    @Published var currentSong: Song?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isShuffled = false
    @Published var repeatMode: RepeatMode = .off

    enum RepeatMode: Int, CaseIterable {
        case off = 0
        case all = 1
        case one = 2

        var iconName: String {
            switch self {
            case .off: return "repeat"
            case .all: return "repeat"
            case .one: return "repeat.1"
            }
        }
    }

    private var player: AVAudioPlayer?
    private var queue: [Song] = []
    private var originalQueue: [Song] = []
    private var currentIndex = 0
    private var shuffledIndices: [Int] = []
    private var updateTimer: Timer?
    /// Monotonic counter to discard stale artwork-load Tasks.
    private var nowPlayingGeneration = 0

    private override init() {
        super.init()
        setupRemoteCommands()
        setupInterruptionHandler()
    }

    // MARK: - Playback Control

    func play(song: Song? = nil, from songs: [Song]? = nil) {
        if let song = song {
            if let queueSongs = songs {
                queue = queueSongs
                originalQueue = queueSongs
                currentIndex = queueSongs.firstIndex(of: song) ?? 0
            } else {
                queue = [song]
                originalQueue = [song]
                currentIndex = 0
            }

            if isShuffled {
                generateShuffledIndices()
            }

            playCurrent()
        } else if currentSong != nil {
            player?.play()
            isPlaying = true
            startTimer()
            updateNowPlaying()
        }
    }

    func playFromBeginning(queue songs: [Song], startIndex: Int = 0) {
        guard !songs.isEmpty else { return }
        queue = songs
        originalQueue = songs
        currentIndex = startIndex

        if isShuffled {
            generateShuffledIndices()
        }

        playCurrent()
    }

    func playPlaylist(songs: [Song], shuffled: Bool = false) {
        guard !songs.isEmpty else { return }
        queue = songs
        originalQueue = songs

        if shuffled {
            isShuffled = true
            generateShuffledIndices()
        }

        currentIndex = 0
        playCurrent()
    }

    func togglePlayPause() {
        guard currentSong != nil else { return }

        if isPlaying {
            player?.pause()
            isPlaying = false
            stopTimer()
        } else {
            guard let p = player else {
                // Player was stopped at end of queue — replay last song
                if let song = currentSong {
                    play(song: song, from: queue.isEmpty ? nil : queue)
                }
                return
            }
            p.play()
            isPlaying = true
            startTimer()
        }
        updateNowPlaying()
    }

    func stop() {
        player?.stop()
        isPlaying = false
        stopTimer()
        currentTime = 0
        currentSong = nil
        queue = []
        originalQueue = []
        shuffledIndices = []
        updateNowPlaying()
    }

    func next() {
        guard !queue.isEmpty else { return }

        if repeatMode == .one {
            restartCurrent()
            return
        }

        if isShuffled {
            advanceShuffled()
        } else {
            advanceNormal()
        }
    }

    func previous() {
        guard !queue.isEmpty else { return }

        if currentTime > 2.0 {
            player?.currentTime = 0
            currentTime = 0
            updateNowPlaying()
            return
        }

        if isShuffled {
            retreatShuffled()
        } else {
            retreatNormal()
        }
    }

    private func restartCurrent() {
        player?.currentTime = 0
        currentTime = 0
        player?.play()
        isPlaying = true
        startTimer()
        updateNowPlaying()
    }

    private func advanceNormal() {
        let next = currentIndex + 1
        if next < queue.count {
            currentIndex = next
            playCurrent()
        } else if repeatMode == .all {
            currentIndex = 0
            playCurrent()
        } else {
            endOfQueue()
        }
    }

    private func retreatNormal() {
        let prev = currentIndex - 1
        if prev >= 0 {
            currentIndex = prev
            playCurrent()
        } else if repeatMode == .all {
            currentIndex = queue.count - 1
            playCurrent()
        }
    }

    private func advanceShuffled() {
        guard !shuffledIndices.isEmpty else {
            generateShuffledIndices()
            return
        }

        if let position = shuffledIndices.firstIndex(of: currentIndex) {
            let next = position + 1
            if next < shuffledIndices.count {
                currentIndex = shuffledIndices[next]
                playCurrent()
            } else if repeatMode == .all {
                generateShuffledIndices()
                currentIndex = shuffledIndices.first ?? 0
                playCurrent()
            } else {
                endOfQueue()
            }
        } else {
            generateShuffledIndices()
            currentIndex = shuffledIndices.first ?? 0
            playCurrent()
        }
    }

    private func retreatShuffled() {
        guard !shuffledIndices.isEmpty else { return }

        if let position = shuffledIndices.firstIndex(of: currentIndex) {
            let prev = position - 1
            if prev >= 0 {
                currentIndex = shuffledIndices[prev]
                playCurrent()
            } else if repeatMode == .all {
                currentIndex = shuffledIndices.last ?? 0
                playCurrent()
            }
        }
    }

    /// End of queue — keep the last song visible in paused state.
    private func endOfQueue() {
        isPlaying = false
        stopTimer()
        if let p = player {
            p.stop()
            p.currentTime = 0
        }
        currentTime = 0
        updateNowPlaying()
    }

    private func playCurrent() {
        guard currentIndex >= 0, currentIndex < queue.count else { return }

        let song = queue[currentIndex]
        currentSong = song
        duration = song.duration

        player?.delegate = nil
        player?.stop()

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: song.fileURL)
            newPlayer.delegate = self
            newPlayer.prepareToPlay()
            newPlayer.play()
            player = newPlayer
            isPlaying = true
            currentTime = 0
            startTimer()
            updateNowPlaying()
        } catch {
            print("Failed to play \(song.title): \(error.localizedDescription)")
            // Advance to next song without recursion
            skipToNextAfterFailure()
        }
    }

    /// Non-recursive fallback — advances queue when a file can't be played.
    private func skipToNextAfterFailure() {
        // If we've exhausted all songs, stop
        let maxAttempts = queue.count
        var attempts = 0

        while attempts < maxAttempts {
            attempts += 1
            currentIndex += 1

            if currentIndex >= queue.count {
                if repeatMode == .all {
                    currentIndex = 0
                } else {
                    currentSong = nil
                    isPlaying = false
                    stopTimer()
                    currentTime = 0
                    updateNowPlaying()
                    return
                }
            }

            let nextSong = queue[currentIndex]
            currentSong = nextSong
            duration = nextSong.duration

            do {
                let newPlayer = try AVAudioPlayer(contentsOf: nextSong.fileURL)
                newPlayer.delegate = self
                newPlayer.prepareToPlay()
                newPlayer.play()
                player = newPlayer
                isPlaying = true
                currentTime = 0
                startTimer()
                updateNowPlaying()
                return
            } catch {
                print("Failed to play \(nextSong.title): \(error.localizedDescription)")
                // Continue to next
            }
        }

        // All songs failed
        currentSong = nil
        isPlaying = false
        stopTimer()
        currentTime = 0
        updateNowPlaying()
    }

    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, duration))
        player?.currentTime = clamped
        currentTime = clamped
        updateNowPlaying()
    }

    // MARK: - Queue

    var currentQueue: [Song] {
        queue
    }

    var currentQueueIndex: Int {
        currentIndex
    }

    // MARK: - Shuffle

    func toggleShuffle() {
        isShuffled.toggle()

        if isShuffled {
            generateShuffledIndices()
        } else {
            queue = originalQueue
            if let current = currentSong, let originalIndex = originalQueue.firstIndex(of: current) {
                currentIndex = originalIndex
            }
        }
    }

    private func generateShuffledIndices() {
        let count = queue.count
        guard count > 0 else { return }

        shuffledIndices = Array(0..<count).shuffled()
        if let currentPos = shuffledIndices.firstIndex(of: currentIndex) {
            shuffledIndices.remove(at: currentPos)
            shuffledIndices.insert(currentIndex, at: 0)
        }
    }

    // MARK: - Repeat

    func cycleRepeatMode() {
        let allCases = RepeatMode.allCases
        let idx = allCases.firstIndex(of: repeatMode) ?? 0
        repeatMode = allCases[(idx + 1) % allCases.count]
    }

    // MARK: - Now Playing

    private func updateNowPlaying() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        nowPlayingGeneration += 1
        let currentGen = nowPlayingGeneration

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]

        // Set immediately without artwork
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Load artwork asynchronously
        Task {
            let asset = AVURLAsset(url: song.fileURL)
            if let data = try? await loadArtwork(from: asset),
               let image = UIImage(data: data) {
                // Only apply if no newer update has been made
                guard currentGen == self.nowPlayingGeneration else { return }
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }

    private func loadArtwork(from asset: AVURLAsset) async throws -> Data? {
        let metadata = try await asset.load(.commonMetadata)
        for item in metadata {
            if item.commonKey == .commonKeyArtwork {
                return try await item.load(.dataValue)
            }
        }
        return nil
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player, self.isPlaying else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.next()
            }
            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.previous()
            }
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }

    private func setupInterruptionHandler() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            Task { @MainActor in
                self.isPlaying = false
                self.stopTimer()
            }
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                Task { @MainActor in
                    self.player?.play()
                    self.isPlaying = true
                    self.startTimer()
                    self.updateNowPlaying()
                }
            }
        @unknown default:
            break
        }
    }

    // Singleton — deinit never called. Timer/observer cleanup handled by lifecycle.
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            if flag {
                self.next()
            }
        }
    }
}
