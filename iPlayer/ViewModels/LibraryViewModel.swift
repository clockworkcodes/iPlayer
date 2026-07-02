import Foundation
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    static let shared = LibraryViewModel()

    @Published var searchText = ""
    @Published var isShowingFilePicker = false
    @Published var isShowingNewPlaylistSheet = false
    @Published var isShowingAddToPlaylistSheet = false
    @Published var isImporting = false
    @Published var importError: String?

    private let libraryManager = LibraryManager.shared
    let playerViewModel = PlayerViewModel.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        libraryManager.$songs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        libraryManager.$playlists
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Songs

    var songs: [Song] {
        libraryManager.songs
    }

    var filteredSongs: [Song] {
        guard !searchText.isEmpty else { return libraryManager.songs }
        return libraryManager.songs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }

    var songCount: Int {
        libraryManager.songs.count
    }

    var isEmpty: Bool {
        libraryManager.songs.isEmpty
    }

    func importSongs(from urls: [URL]) async {
        isImporting = true
        defer { isImporting = false }

        let imported = await libraryManager.importSongs(from: urls)
        if imported.isEmpty {
            importError = "No songs could be imported. The file format may not be supported."
        }
    }

    func removeSong(_ song: Song) {
        libraryManager.removeSong(song)
    }

    func removeSongs(at offsets: IndexSet) {
        let toRemove = offsets.map { libraryManager.songs[$0] }
        for song in toRemove {
            libraryManager.removeSong(song)
        }
    }

    func toggleFavorite(for songID: UUID) {
        libraryManager.toggleFavorite(for: songID)
    }

    func playSong(_ song: Song) {
        playerViewModel.play(song: song, from: libraryManager.songs)
    }

    // MARK: - Playlists

    var playlists: [Playlist] {
        libraryManager.playlists
    }

    var userPlaylists: [Playlist] {
        libraryManager.playlists.filter { !$0.isBuiltIn }
    }

    var favoritesPlaylist: Playlist? {
        libraryManager.playlists.first { $0.name == "Favorites" }
    }

    func createPlaylist(name: String) -> Playlist {
        libraryManager.createPlaylist(name: name)
    }

    func deletePlaylist(_ playlist: Playlist) {
        libraryManager.deletePlaylist(playlist)
    }

    func renamePlaylist(_ playlist: Playlist, newName: String) {
        libraryManager.renamePlaylist(playlist, newName: newName)
    }

    func addSongToPlaylist(songID: UUID, playlistID: UUID) {
        libraryManager.addSongToPlaylist(songID: songID, playlistID: playlistID)
    }

    func removeSongFromPlaylist(songID: UUID, playlistID: UUID) {
        libraryManager.removeSongFromPlaylist(songID: songID, playlistID: playlistID)
    }

    func songsInPlaylist(_ playlist: Playlist) -> [Song] {
        libraryManager.songsInPlaylist(playlist)
    }

    func songsNotInPlaylist(_ playlist: Playlist) -> [Song] {
        libraryManager.songsNotInPlaylist(playlist)
    }

    func playPlaylist(_ playlist: Playlist, shuffled: Bool = false) {
        let songs = libraryManager.songsInPlaylist(playlist)
        playerViewModel.playPlaylist(songs: songs, shuffled: shuffled)
    }

    // MARK: - Settings

    var totalLibrarySize: String {
        libraryManager.totalLibrarySize
    }

    func clearLibrary() {
        AudioManager.shared.stop()
        libraryManager.clearLibrary()
    }

    func clearPlaylists() {
        libraryManager.clearPlaylists()
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
