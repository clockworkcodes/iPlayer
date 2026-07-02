import Foundation

struct Song: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var artist: String
    var duration: TimeInterval
    var fileURL: URL
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        title: String,
        artist: String = "Unknown Artist",
        duration: TimeInterval,
        fileURL: URL,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.fileURL = fileURL
        self.isFavorite = isFavorite
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
