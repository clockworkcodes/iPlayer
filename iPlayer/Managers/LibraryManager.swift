import Foundation
import AVFoundation
import Combine

@MainActor
final class LibraryManager: ObservableObject {
    static let shared = LibraryManager()

    @Published var songs: [Song] = []
    @Published var playlists: [Playlist] = []

    private let songsKey = "com.iplayer.songs"
    private let playlistsKey = "com.iplayer.playlists"
    private let favoritesPlaylistName = "Favorites"

    private let fileManager = FileManager.default

    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var musicDirectoryURL: URL {
        let url = documentsURL.appendingPathComponent("Music", isDirectory: true)
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    private init() {
        loadSongs()
        loadPlaylists()
        ensureFavoritesPlaylistExists()
    }

    // MARK: - Song Management

    func importSongs(from urls: [URL]) async -> [Song] {
        var imported: [Song] = []

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            let fileName = url.lastPathComponent
            let uniqueURL = uniqueFileURL(for: fileName)

            // Check if the exact same file is already imported (by absolute path match)
            if let existing = songs.first(where: { $0.fileURL == uniqueURL }) {
                imported.append(existing)
                continue
            }

            // If file exists but doesn't match any song, generate unique name
            var destinationURL = uniqueURL
            if fileManager.fileExists(atPath: destinationURL.path) {
                destinationURL = uniqueFileURL(for: fileName, uniqued: true)
            }

            do {
                try fileManager.copyItem(at: url, to: destinationURL)

                var title = (fileName as NSString).deletingPathExtension
                var artist = "Unknown Artist"
                var duration: TimeInterval = 0

                let asset = AVURLAsset(url: destinationURL)

                // Load duration
                let durationSeconds = try? await asset.load(.duration).seconds
                duration = durationSeconds ?? 0

                // Load metadata
                let metadata = try? await asset.load(.commonMetadata)
                if let metadataItems = metadata {
                    for item in metadataItems {
                        guard let value = try? await item.load(.value) else { continue }
                        switch item.commonKey {
                        case .commonKeyTitle:
                            let str = "\(value)"
                            if !str.isEmpty { title = str }
                        case .commonKeyArtist:
                            let str = "\(value)"
                            if !str.isEmpty { artist = str }
                        default:
                            break
                        }
                    }
                }

                let song = Song(
                    title: title,
                    artist: artist,
                    duration: duration.isNaN || duration.isInfinite ? 0 : duration,
                    fileURL: destinationURL
                )

                songs.append(song)
                imported.append(song)
                saveSongs()
            } catch {
                print("Failed to import \(fileName): \(error.localizedDescription)")
            }
        }

        return imported
    }

    func removeSong(_ song: Song) {
        try? fileManager.removeItem(at: song.fileURL)
        songs.removeAll { $0.id == song.id }

        // Clean up player if it was playing this song
        if AudioManager.shared.currentSong?.id == song.id {
            AudioManager.shared.next()
        }

        for i in playlists.indices {
            playlists[i].removeSong(song.id)
        }

        saveSongs()
        savePlaylists()
    }

    func removeSongs(at offsets: IndexSet) {
        let toRemove = offsets.map { songs[$0] }
        for song in toRemove {
            removeSong(song)
        }
    }

    /// Generates a unique file URL, appending a number suffix if the file exists.
    private func uniqueFileURL(for fileName: String, uniqued: Bool = false) -> URL {
        let baseURL = musicDirectoryURL.appendingPathComponent(fileName)
        guard uniqued || fileManager.fileExists(atPath: baseURL.path) else { return baseURL }

        let ext = (fileName as NSString).pathExtension
        let nameWithoutExt = (fileName as NSString).deletingPathExtension

        var counter = 1
        while true {
            let uniqueName = "\(nameWithoutExt) (\(counter)).\(ext)"
            let url = musicDirectoryURL.appendingPathComponent(uniqueName)
            if !fileManager.fileExists(atPath: url.path) {
                return url
            }
            counter += 1
        }
    }

    func toggleFavorite(for songID: UUID) {
        guard let index = songs.firstIndex(where: { $0.id == songID }) else { return }
        songs[index].isFavorite.toggle()
        updateFavoritesPlaylist()
        saveSongs()
    }

    // MARK: - Playlist Management

    func createPlaylist(name: String) -> Playlist {
        let playlist = Playlist(name: name)
        playlists.append(playlist)
        savePlaylists()
        return playlist
    }

    func deletePlaylist(_ playlist: Playlist) {
        guard !playlist.isBuiltIn else { return }
        playlists.removeAll { $0.id == playlist.id }
        savePlaylists()
    }

    func renamePlaylist(_ playlist: Playlist, newName: String) {
        guard !playlist.isBuiltIn else { return }
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].name = newName
        savePlaylists()
    }

    func addSongToPlaylist(songID: UUID, playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].addSong(songID)
        savePlaylists()
    }

    func removeSongFromPlaylist(songID: UUID, playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        playlists[index].removeSong(songID)
        savePlaylists()

        // If removing from Favorites, also unfavorite the song
        if playlists[index].name == favoritesPlaylistName {
            if let songIndex = songs.firstIndex(where: { $0.id == songID }) {
                songs[songIndex].isFavorite = false
                saveSongs()
            }
        }
    }

    func songsInPlaylist(_ playlist: Playlist) -> [Song] {
        playlist.songIDs.compactMap { id in
            songs.first { $0.id == id }
        }
    }

    func songsNotInPlaylist(_ playlist: Playlist) -> [Song] {
        songs.filter { !playlist.songIDs.contains($0.id) }
    }

    // MARK: - Favorites

    private func ensureFavoritesPlaylistExists() {
        if !playlists.contains(where: { $0.name == favoritesPlaylistName }) {
            let favorites = Playlist(name: favoritesPlaylistName, isBuiltIn: true)
            playlists.append(favorites)
            savePlaylists()
        }
        updateFavoritesPlaylist()
    }

    func updateFavoritesPlaylist() {
        guard let index = playlists.firstIndex(where: { $0.name == favoritesPlaylistName }) else { return }
        let favoriteIDs = songs.filter { $0.isFavorite }.map { $0.id }
        playlists[index].songIDs = favoriteIDs
        savePlaylists()
    }

    var isFavoritesPlaylistEmpty: Bool {
        guard let index = playlists.firstIndex(where: { $0.name == favoritesPlaylistName }) else { return true }
        return playlists[index].songIDs.isEmpty
    }

    // MARK: - Persistence

    private func saveSongs() {
        guard let data = try? JSONEncoder().encode(songs) else { return }
        UserDefaults.standard.set(data, forKey: songsKey)
    }

    private func savePlaylists() {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        UserDefaults.standard.set(data, forKey: playlistsKey)
    }

    private func loadSongs() {
        guard let data = UserDefaults.standard.data(forKey: songsKey),
              let decoded = try? JSONDecoder().decode([Song].self, from: data) else { return }
        songs = decoded.filter { fileManager.fileExists(atPath: $0.fileURL.path) }
    }

    private func loadPlaylists() {
        guard let data = UserDefaults.standard.data(forKey: playlistsKey),
              let decoded = try? JSONDecoder().decode([Playlist].self, from: data) else { return }
        playlists = decoded
    }

    // MARK: - Cleanup

    var totalLibrarySize: String {
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .totalFileAllocatedSizeKey]
        var total: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: musicDirectoryURL,
            includingPropertiesForKeys: resourceKeys
        ) else { return "0 KB" }

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  let size = values.totalFileAllocatedSize ?? values.fileSize else { continue }
            total += Int64(size)
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }

    func clearLibrary() {
        guard let enumerator = fileManager.enumerator(
            at: musicDirectoryURL,
            includingPropertiesForKeys: nil
        ) else { return }

        for case let fileURL as URL in enumerator {
            try? fileManager.removeItem(at: fileURL)
        }

        songs.removeAll()
        playlists.removeAll { !$0.isBuiltIn }
        saveSongs()
        savePlaylists()
        ensureFavoritesPlaylistExists()
    }

    func clearPlaylists() {
        playlists.removeAll { !$0.isBuiltIn }
        savePlaylists()
    }
}
