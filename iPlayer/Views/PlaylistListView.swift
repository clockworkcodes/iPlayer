import SwiftUI

enum PlaylistSheet: Identifiable {
    case newPlaylist
    case playlistDetail(Playlist)

    var id: String {
        switch self {
        case .newPlaylist: return "new"
        case .playlistDetail(let p): return p.id.uuidString
        }
    }
}

struct PlaylistListView: View {
    @EnvironmentObject private var libraryVM: LibraryViewModel
    @State private var activeSheet: PlaylistSheet?
    @State private var newPlaylistName = ""
    @State private var playlistToRename: Playlist?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            Group {
                if shouldShowEmptyState {
                    EmptyStateView(
                        title: "No Playlists",
                        subtitle: "Create playlists to organize your music",
                        systemImage: "music.note.list",
                        actionTitle: "Create Playlist",
                        action: { activeSheet = .newPlaylist }
                    )
                } else {
                    listContent
                }
            }
            .navigationTitle("Playlists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        activeSheet = .newPlaylist
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .newPlaylist:
                    newPlaylistSheet
                case .playlistDetail(let playlist):
                    PlaylistDetailView(playlist: playlist)
                        .environmentObject(libraryVM)
                }
            }
            .alert("Rename Playlist", isPresented: .init(
                get: { playlistToRename != nil },
                set: { if !$0 { playlistToRename = nil } }
            )) {
                TextField("Playlist Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    playlistToRename = nil
                }
                Button("Rename") {
                    if let playlist = playlistToRename, !renameText.isEmpty {
                        libraryVM.renamePlaylist(playlist, newName: renameText)
                    }
                    playlistToRename = nil
                }
            } message: {
                Text("Enter a new name for this playlist.")
            }
        }
    }

    private var shouldShowEmptyState: Bool {
        let userPlaylists = libraryVM.userPlaylists
        let favorites = libraryVM.favoritesPlaylist
        return userPlaylists.isEmpty && (favorites == nil || favorites!.songIDs.isEmpty)
    }

    private var listContent: some View {
        List {
            if let favorites = libraryVM.favoritesPlaylist, !favorites.songIDs.isEmpty {
                Section {
                    playlistRow(favorites, isBuiltIn: true)
                }
            }

            if !libraryVM.userPlaylists.isEmpty {
                Section("My Playlists") {
                    ForEach(libraryVM.userPlaylists) { playlist in
                        playlistRow(playlist, isBuiltIn: false)
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { libraryVM.userPlaylists[$0] }
                        for playlist in toDelete {
                            libraryVM.deletePlaylist(playlist)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func playlistRow(_ playlist: Playlist, isBuiltIn: Bool) -> some View {
        Button {
            activeSheet = .playlistDetail(playlist)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(playlistIconColor(for: playlist))
                        .frame(width: 52, height: 52)

                    Image(systemName: isBuiltIn ? "heart.fill" : "music.note.list")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(playlist.songCount) song\(playlist.songCount != 1 ? "s" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if !isBuiltIn {
                Button(role: .destructive) {
                    libraryVM.deletePlaylist(playlist)
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    playlistToRename = playlist
                    renameText = playlist.name
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(.orange)
            }
        }
    }

    private func playlistIconColor(for playlist: Playlist) -> Color {
        if playlist.name == "Favorites" {
            return .pink
        }
        let colors: [Color] = [.blue, .purple, .green, .orange, .teal, .indigo, .mint, .red]
        let hash = playlist.id.uuidString.utf8.reduce(0) { $0 + Int($1) }
        return colors[hash % colors.count]
    }

    private var newPlaylistSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)

                    Text("New Playlist")
                        .font(.title2.weight(.semibold))
                }
                .padding(.top, 32)

                TextField("Playlist Name", text: $newPlaylistName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 32)
                    .autocorrectionDisabled()

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newPlaylistName = ""
                        activeSheet = nil
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        let playlist = libraryVM.createPlaylist(name: name)
                        newPlaylistName = ""
                        // Dismiss create sheet, then open the new playlist
                        activeSheet = .playlistDetail(playlist)
                    }
                    .disabled(newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}

#Preview {
    PlaylistListView()
        .environmentObject(LibraryViewModel.shared)
        .environmentObject(PlayerViewModel.shared)
}
