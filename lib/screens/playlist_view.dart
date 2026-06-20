// =============================================================================
// FILE: screens/playlist_view.dart
// DESKRIPSI: Halaman daftar playlist + detail playlist.
//
// ★ HIGHLIGHT CLOUD:
// - Playlist dibuat/dihapus di Firebase via FirebaseService
// - Track dalam playlist diambil via JOIN query (resource embedding)
// =============================================================================

import 'package:flutter/material.dart';
import '../models/track.dart';
import '../models/playlist.dart';
import '../services/firebase_service.dart';
import '../services/audio_manager.dart';

// =============================================================================
// PLAYLIST VIEW — Daftar semua playlist
// =============================================================================

/// Menampilkan grid semua playlist dari Firebase cloud.
class PlaylistView extends StatelessWidget {
  final Function(Playlist) onPlaylistTap;
  const PlaylistView({super.key, required this.onPlaylistTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: uiRefreshTrigger,
      builder: (context, _, __) {
        // ★ CLOUD: Ambil semua playlist dari Firebase
        return FutureBuilder<List<Playlist>>(
          future: FirebaseService.getAllPlaylists(),
          builder: (context, snapshot) {
            final playlists = snapshot.data ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tombol buat playlist baru
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF222222),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('New Playlist'),
                    onPressed: () => _createPlaylistDialog(context),
                  ),
                ),
                const SizedBox(height: 20),

                // Grid playlist
                Expanded(
                  child: playlists.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.queue_music, color: Colors.white24, size: 64),
                              SizedBox(height: 16),
                              Text(
                                'Belum ada playlist.',
                                style: TextStyle(color: Colors.white54, fontSize: 18),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 24,
                            mainAxisSpacing: 24,
                          ),
                          itemCount: playlists.length,
                          itemBuilder: (context, index) => _PlaylistCard(
                            playlist: playlists[index],
                            onTap: () => onPlaylistTap(playlists[index]),
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Dialog untuk membuat playlist baru → insert ke Firebase cloud
  void _createPlaylistDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Create Playlist'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Playlist Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                // ★ CLOUD: Insert playlist baru ke Firebase
                await FirebaseService.insertPlaylist(ctrl.text);
                uiRefreshTrigger.value++;
                Navigator.pop(context);
              }
            },
            child: Text(
              'Create',
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PLAYLIST CARD — Kartu untuk satu playlist di grid
// =============================================================================

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onTap;
  const _PlaylistCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // ★ CLOUD: Ambil track dalam playlist via JOIN query
      child: FutureBuilder<List<Track>>(
        future: FirebaseService.getTracksForPlaylist(playlist.id!),
        builder: (context, snapshot) {
          String cover = '';
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            cover = snapshot.data!.first.coverUrl;
          }

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5)),
              ],
              // ★ CLOUD: Cover image dari URL Firebase Storage
              image: cover.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(cover),
                      fit: BoxFit.cover,
                      colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.darken),
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (cover.isEmpty)
                  const Icon(Icons.queue_music, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                Text(
                  playlist.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                if (snapshot.hasData && snapshot.data!.isNotEmpty)
                  Text(
                    '${snapshot.data!.length} Tracks',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// PLAYLIST DETAIL VIEW — Menampilkan isi sebuah playlist
// =============================================================================

/// Menampilkan detail sebuah playlist: header, daftar track, tombol play/shuffle.
class PlaylistDetailView extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onBack;

  const PlaylistDetailView({
    super.key,
    required this.playlist,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: uiRefreshTrigger,
      builder: (context, _, __) {
        // ★ CLOUD: Ambil track dalam playlist via JOIN query di Firebase
        return FutureBuilder<List<Track>>(
          future: FirebaseService.getTracksForPlaylist(playlist.id!),
          builder: (context, snapshot) {
            final tracks = snapshot.data ?? [];
            final String cover =
                tracks.isNotEmpty && tracks.first.coverUrl.isNotEmpty
                    ? tracks.first.coverUrl
                    : '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tombol back
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 16),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: onBack,
                  ),
                ),

                // --- Header Playlist ---
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Cover art
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFF181818),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              blurRadius: 20,
                              offset: Offset(0, 10),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        // ★ CLOUD: Cover dari URL Firebase Storage
                        child: cover.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(
                                    Icons.music_note,
                                    size: 80,
                                    color: Colors.white24,
                                  ),
                                ),
                              )
                            : const Icon(Icons.music_note, size: 80, color: Colors.white24),
                      ),
                      const SizedBox(width: 24),
                      // Info playlist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'Cloud Playlist',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              playlist.name,
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1.5,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${tracks.length} songs',
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Tombol Play, Shuffle, Delete ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      // Play
                      GestureDetector(
                        onTap: () {
                          if (tracks.isNotEmpty) playTracks(tracks, 0);
                        },
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 36),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Shuffle
                      IconButton(
                        icon: const Icon(Icons.shuffle, size: 32, color: Colors.white70),
                        onPressed: () async {
                          if (tracks.isNotEmpty) {
                            await audioPlayer.setShuffleModeEnabled(true);
                            playTracks(tracks, 0);
                          }
                        },
                      ),
                      const Spacer(),
                      // Delete playlist
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Hapus Playlist',
                        onPressed: () async {
                          // ★ CLOUD: Hapus playlist dan semua relasinya
                          await FirebaseService.deletePlaylist(playlist.id!);
                          uiRefreshTrigger.value++;
                          onBack();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- Daftar Track dalam Playlist ---
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final t = tracks[index];
                      return ListTile(
                        leading: Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                        title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(t.artist, style: const TextStyle(color: Colors.white54)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                          tooltip: 'Remove from Playlist',
                          onPressed: () async {
                            // ★ CLOUD: Hapus relasi track dari playlist ini
                            await FirebaseService.removeTrackFromPlaylist(
                              playlist.id!,
                              t.id!,
                            );
                            uiRefreshTrigger.value++;
                          },
                        ),
                        // ★ CLOUD: Play streaming dari URL cloud
                        onTap: () => playTracks(tracks, index),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
