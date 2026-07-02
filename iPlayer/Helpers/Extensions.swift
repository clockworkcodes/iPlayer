import SwiftUI
import AVFoundation

// MARK: - View Extensions

extension View {
    func playerBackground() -> some View {
        self.background(
            LinearGradient(
                colors: [
                    .black.opacity(0.6),
                    .clear,
                    .clear,
                    .black.opacity(0.3),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - Color Extensions

extension Color {
    static var appleMusicRed: Color {
        Color(red: 0.98, green: 0.24, blue: 0.24)
    }

    static var appleMusicPink: Color {
        Color(red: 0.91, green: 0.24, blue: 0.42)
    }

    static var appleMusicOrange: Color {
        Color(red: 0.96, green: 0.47, blue: 0.13)
    }

    static var playlistGradientStart: Color {
        Color(red: 0.6, green: 0.2, blue: 0.8)
    }

    static var playlistGradientEnd: Color {
        Color(red: 0.2, green: 0.5, blue: 0.9)
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    var formattedTime: String {
        guard !self.isNaN, !self.isInfinite else { return "0:00" }
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - UTType Extensions

extension UTType {
    static var mp3: UTType {
        UTType(filenameExtension: "mp3") ?? .audio
    }

    static var m4a: UTType {
        UTType(filenameExtension: "m4a") ?? .audio
    }

    static var wav: UTType {
        UTType(filenameExtension: "wav") ?? .audio
    }
}

// MARK: - URL Extensions

extension URL {
    var isAudioFile: Bool {
        let ext = pathExtension.lowercased()
        return ["mp3", "m4a", "wav", "aac", "flac", "alac"].contains(ext)
    }
}

// MARK: - AVAudioSession Extensions

extension AVAudioSession {
    static func configurePlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}
