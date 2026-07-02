import SwiftUI

struct PlaylistDetailView: View {
    @EnvironmentObject private var libraryVM: LibraryViewModel
    @Environment(\.dismiss) private var dismiss

    let playlistID: UUID
    @State private var showingSongPicker = false
    @State private var selectedSongs: Set<UUID> = []

    init(playlist: Playlist) {
        self.playlistID = playlist.id
    }

    private var currentPlaylist: Playlist? {
        libraryVM.playlists.first { $0.id == playlistID }
    }

    private var songs: [Song] {
        guard let playlist = currentPlaylist else { return [] }
        return libraryVM.songsInPlaylist(playlist)
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle(currentPlaylist?.name ?? "Playlist")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }

                    if let playlist = currentPlaylist, !playlist.isBuiltIn {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingSongPicker = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingSongPicker) {
                    songPickerSheet
                }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if currentPlaylist == nil {
            EmptyStateView(
                title: "Playlist Not Found",
                subtitle: "This playlist may have been deleted",
                systemImage: "questionmark.circle"
            )
        } else if songs.isEmpty {
            EmptyStateView(
                title: "Empty Playlist",
                subtitle: "Add songs to this playlist",
                systemImage: "text.badge.plus",
                actionTitle: "Add Songs",
                action: { showingSongPicker = true }
            )
        } else {
            listContent
        }
    }

    private var listContent: some View {
        List {
            Section {
                Button {
                    if let playlist = currentPlaylist {
                        libraryVM.playPlaylist(playlist)
                        dismiss()
                    }
                } label: {
                    Label("Play All", systemImage: "play.fill")
                        .font(.headline)
                        .foregroundStyle(.accent)
                }

                Button {
                    if let playlist = currentPlaylist {
                        libraryVM.playPlaylist(playlist, shuffled: true)
                        dismiss()
                    }
                } label: {
                    Label("Shuffle Play", systemImage: "shuffle")
                        .font(.headline)
                        .foregroundStyle(.accent)
                }
            }

            Section("\(songs.count) Song\(songs.count != 1 ? "s" : "")") {
                ForEach(songs) { song in
                    SongRowView(song: song)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            libraryVM.playerViewModel.play(song: song, from: songs)
                            dismiss()
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                libraryVM.removeSongFromPlaylist(songID: song.id, playlistID: playlistID)
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                        }
                }
                .onDelete { offsets in
                    let toRemove = offsets.map { songs[$0] }
                    for song in toRemove {
                        libraryVM.removeSongFromPlaylist(songID: song.id, playlistID: playlistID)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var songPickerSheet: some View {
        if let playlist = currentPlaylist {
            NavigationStack {
                let availableSongs = libraryVM.songsNotInPlaylist(playlist)

                Group {
                    if availableSongs.isEmpty {
                        EmptyStateView(
                            title: "All Songs Added",
                            subtitle: "All songs in your library are already in this playlist",
                            systemImage: "checkmark.circle"
                        )
                    } else {
                        List(availableSongs) { song in
                            HStack {
                                SongRowView(song: song)

                                Spacer()

                                if selectedSongs.contains(song.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.accent)
                                        .font(.title3)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedSongs.contains(song.id) {
                                    selectedSongs.remove(song.id)
                                } else {
                                    selectedSongs.insert(song.id)
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("Add Songs")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            selectedSongs.removeAll()
                            showingSongPicker = false
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add (\(selectedSongs.count))") {
                            for songID in selectedSongs {
                                libraryVM.addSongToPlaylist(songID: songID, playlistID: playlist.id)
                            }
                            selectedSongs.removeAll()
                            showingSongPicker = false
                        }
                        .disabled(selectedSongs.isEmpty)
                    }
                }
            }
        }
    }
}
