import SwiftUI
import AVFoundation

// Simple memory cache for artwork data keyed by song ID
private actor ArtworkCache {
    static let shared = ArtworkCache()
    private var cache: [UUID: Data] = [:]

    func get(for key: UUID) -> Data? { cache[key] }

    func set(_ data: Data, for key: UUID) { cache[key] = data }
}

struct SongArtworkView: View {
    let song: Song
    var size: CGFloat = 280

    @State private var artworkData: Data? = nil

    private let gradientColors: [Color] = [
        Color(red: 0.8, green: 0.2, blue: 0.4),
        Color(red: 0.4, green: 0.2, blue: 0.8),
        Color(red: 0.2, green: 0.6, blue: 0.9),
    ]

    var body: some View {
        Group {
            if let data = artworkData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.25))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
        .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        .task(id: song.id) {
            await loadArtwork()
        }
    }

    private func loadArtwork() async {
        // Check cache first
        if let cached = await ArtworkCache.shared.get(for: song.id) {
            artworkData = cached
            return
        }

        let asset = AVURLAsset(url: song.fileURL)
        guard let metadata = try? await asset.load(.commonMetadata) else { return }

        for item in metadata where item.commonKey == .commonKeyArtwork {
            if let data = try? await item.load(.dataValue) {
                await ArtworkCache.shared.set(data, for: song.id)
                artworkData = data
                return
            }
        }
    }
}
