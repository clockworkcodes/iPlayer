# iPlayer — Local Music Player

A minimal, Apple Music–style iOS music player built with SwiftUI.

## Requirements

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+

## Features

- **Import Music** — Import MP3, M4A, and WAV files via the system file picker
- **Library** — Browse all imported songs with search, favorites, and swipe-to-delete
- **Full-Screen Player** — Apple Music–style player with artwork, progress slider, shuffle, repeat, and lock-screen controls
- **Playlists** — Create, rename, delete playlists; add/remove songs
- **Favorites** — Tap the heart to favorite songs; auto-managed Favorites playlist
- **Mini Player** — Persistent compact player at the bottom of the screen
- **Background Playback** — Audio continues when the app is in the background
- **Lock Screen Controls** — Play, pause, next, previous, and seek from the lock screen
- **Dark Mode** — Full Light/Dark mode support

## Setup

1. Open **Xcode**
2. Create a new **iOS App** project:
   - Name: **iPlayer**
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Minimum Deployment: **iOS 17.0**
3. Add all Swift source files from the `iPlayer/` directory to the project
4. Add the `Info.plist` — or ensure these entries exist in your target's Info tab:
   - `Required background modes` → `App plays audio or streams audio/video using AirPlay`
5. Set the launch screen in `Assets.xcassets`
6. Build and run (⌘R)

## Architecture

```
iPlayer/
├── iPlayerApp.swift          # App entry point, audio session setup
├── ContentView.swift         # Tab view + Mini Player overlay
├── Info.plist                # App configuration
├── Assets.xcassets/          # App icons and colors
├── Models/
│   ├── Song.swift            # Song model
│   └── Playlist.swift        # Playlist model
├── Managers/
│   ├── AudioManager.swift    # AVAudioPlayer playback, queue, remote controls
│   └── LibraryManager.swift  # Data persistence (UserDefaults + JSON)
├── ViewModels/
│   ├── LibraryViewModel.swift  # Library and playlist state
│   └── PlayerViewModel.swift   # Player state and formatted output
├── Views/
│   ├── LibraryView.swift       # Song library with search
│   ├── PlayerView.swift        # Full-screen player
│   ├── PlaylistListView.swift  # Playlist collection
│   ├── PlaylistDetailView.swift # Single playlist content
│   ├── MiniPlayerView.swift    # Compact player bar
│   ├── SongArtworkView.swift   # Artwork with gradient fallback
│   ├── EmptyStateView.swift    # Reusable empty state
│   └── SettingsView.swift      # Settings and info
└── Helpers/
    └── Extensions.swift        # Color, TimeInterval, UTType helpers
```

## Data Storage

- Music files are stored in the app's **Documents/Music/** directory
- Song and playlist metadata is persisted via **UserDefaults + JSON**
- All data persists across app restarts

## Tech Stack

- **SwiftUI** — Full UI
- **AVFoundation** — Audio playback, metadata reading, artwork extraction
- **MediaPlayer** — Lock screen controls and Now Playing info
- **FileManager** — Local file storage
