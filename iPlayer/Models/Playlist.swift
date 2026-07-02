import Foundation

struct Playlist: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var songIDs: [UUID]
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        name: String,
        songIDs: [UUID] = [],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.songIDs = songIDs
        self.isBuiltIn = isBuiltIn
    }

    mutating func addSong(_ id: UUID) {
        guard !songIDs.contains(id) else { return }
        songIDs.append(id)
    }

    mutating func removeSong(_ id: UUID) {
        songIDs.removeAll { $0 == id }
    }

    var songCount: Int {
        songIDs.count
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
}
