import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var playerVM: PlayerViewModel
    @EnvironmentObject private var libraryVM: LibraryViewModel
    @EnvironmentObject private var audioManager: AudioManager

    private let miniPlayerHeight: CGFloat = 60

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                LibraryView()
                    .environmentObject(libraryVM)
                    .environmentObject(playerVM)
                    .environmentObject(audioManager)
                    .tabItem {
                        Label("Library", systemImage: "music.note.house.fill")
                    }

                PlaylistListView()
                    .environmentObject(libraryVM)
                    .environmentObject(playerVM)
                    .environmentObject(audioManager)
                    .tabItem {
                        Label("Playlists", systemImage: "music.note.list")
                    }

                SettingsView()
                    .environmentObject(libraryVM)
                    .environmentObject(playerVM)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
            // Push tab content up when mini player is visible so it doesn't overlap
            .safeAreaInset(edge: .bottom) {
                if playerVM.currentSong != nil {
                    Spacer().frame(height: miniPlayerHeight)
                }
            }

            // Mini Player
            if playerVM.currentSong != nil {
                VStack(spacing: 0) {
                    // Progress bar like Apple Music
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(.quaternary)
                                .frame(height: 2)

                            Rectangle()
                                .fill(.accent)
                                .frame(width: geometry.size.width * playerVM.progress, height: 2)
                        }
                    }
                    .frame(height: 2)

                    MiniPlayerView()
                        .environmentObject(playerVM)
                        .environmentObject(audioManager)
                }
                .frame(height: miniPlayerHeight + 2)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.interactiveSpring(response: 0.3), value: playerVM.currentSong != nil)
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryViewModel.shared)
        .environmentObject(PlayerViewModel.shared)
        .environmentObject(AudioManager.shared)
}
