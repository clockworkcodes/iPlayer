import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var libraryVM: LibraryViewModel
    @State private var showingClearLibraryAlert = false
    @State private var showingClearPlaylistsAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Library Section
                Section("Library") {
                    HStack {
                        Label("Storage Used", systemImage: "externaldrive")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(libraryVM.totalLibrarySize)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Total Songs", systemImage: "music.note")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(libraryVM.songCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showingClearLibraryAlert = true
                    } label: {
                        Label("Clear Library", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }

                // Playlists Section
                Section("Playlists") {
                    HStack {
                        Label("Total Playlists", systemImage: "music.note.list")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(libraryVM.playlists.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showingClearPlaylistsAlert = true
                    } label: {
                        Label("Clear Playlists", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(libraryVM.appVersion) (\(libraryVM.buildNumber))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Compatibility", systemImage: "iphone")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("iOS 17.0+")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Developer", systemImage: "person")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("iPlayer")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Support Section
                Section {
                    Link(destination: URL(string: "https://www.apple.com/feedback/")!) {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Clear Library", isPresented: $showingClearLibraryAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    libraryVM.clearLibrary()
                }
            } message: {
                Text("This will remove all imported songs and cannot be undone. Playlists will be preserved.")
            }
            .alert("Clear Playlists", isPresented: $showingClearPlaylistsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    libraryVM.clearPlaylists()
                }
            } message: {
                Text("This will remove all custom playlists. The Favorites playlist will be preserved.")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(LibraryViewModel.shared)
        .environmentObject(PlayerViewModel.shared)
}
