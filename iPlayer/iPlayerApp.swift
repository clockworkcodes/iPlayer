import SwiftUI
import AVFoundation

@main
struct iPlayerApp: App {
    @StateObject private var libraryManager = LibraryManager.shared
    @StateObject private var audioManager = AudioManager.shared
    @StateObject private var playerViewModel = PlayerViewModel.shared

    init() {
        configureAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(libraryManager)
                .environmentObject(audioManager)
                .environmentObject(playerViewModel)
                .preferredColorScheme(nil)
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
}
