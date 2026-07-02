import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var libraryVM: LibraryViewModel
    @EnvironmentObject private var playerVM: PlayerViewModel
    @State private var showingFilePicker = false
    @State private var showDeleteConfirmation = false
    @State private var songToDelete: Song?

    var body: some View {
        NavigationStack {
            Group {
                if libraryVM.isEmpty {
                    EmptyStateView(
                        title: "No Songs Yet",
                        subtitle: "Import your favorite music to get started.\niPlayer supports MP3, M4A, and WAV files.",
                        systemImage: "music.note.list",
                        actionTitle: "Add Music",
                        action: { showingFilePicker = true }
                    )
                } else {
                    songList
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFilePicker = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                    }
                }
            }
            .searchable(text: $libraryVM.searchText, placement: .navigationBarDrawer, prompt: "Search Songs")
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.audio, .mp3],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .alert("Import Error", isPresented: .init(
                get: { libraryVM.importError != nil },
                set: { if !$0 { libraryVM.importError = nil } }
            )) {
                Text(libraryVM.importError ?? "Unknown error")
            }
            .alert("Delete Song", isPresented: $showDeleteConfirmation, presenting: songToDelete) { song in
                Button("Cancel", role: .cancel) {
                    songToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    libraryVM.removeSong(song)
                    songToDelete = nil
                }
            } message: { song in
                Text("Are you sure you want to delete \"\(song.title)\"? This cannot be undone.")
            }
        }
    }

    // The displayed songs based on search state
    private var displayedSongs: [Song] {
        libraryVM.searchText.isEmpty ? libraryVM.songs : libraryVM.filteredSongs
    }

    private var songList: some View {
        List {
            ForEach(displayedSongs) { song in
                SongRowView(song: song)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        libraryVM.playSong(song)
                    }
                    .contextMenu {
                        Button {
                            libraryVM.toggleFavorite(for: song.id)
                        } label: {
                            Label(
                                song.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: song.isFavorite ? "heart.fill" : "heart"
                            )
                        }

                        Menu {
                            if libraryVM.userPlaylists.isEmpty {
                                Text("No playlists yet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(libraryVM.userPlaylists) { playlist in
                                Button(playlist.name) {
                                    libraryVM.addSongToPlaylist(songID: song.id, playlistID: playlist.id)
                                }
                            }
                        } label: {
                            Label("Add to Playlist", systemImage: "text.badge.plus")
                        }

                        Divider()

                        Button(role: .destructive) {
                            songToDelete = song
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onDelete { offsets in
                deleteSongs(at: offsets)
            }
        }
        .listStyle(.plain)
    }

    private func deleteSongs(at offsets: IndexSet) {
        let songsToRemove = offsets.map { displayedSongs[$0] }
        for song in songsToRemove {
            libraryVM.removeSong(song)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }
            Task {
                await libraryVM.importSongs(from: urls)
            }
        case .failure(let error):
            if let nsError = error as NSError?, nsError.code == NSUserCancelledError {
                // User cancelled — not an error
                return
            }
            libraryVM.importError = error.localizedDescription
        }
    }
}

// MARK: - Song Row

struct SongRowView: View {
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            SongArtworkView(song: song, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(song.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    if song.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.pink)
                    }
                }

                Text(song.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(song.formattedDuration)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    LibraryView()
        .environmentObject(LibraryViewModel.shared)
        .environmentObject(PlayerViewModel.shared)
        .environmentObject(AudioManager.shared)
}
