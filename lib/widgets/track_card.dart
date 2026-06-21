// =============================================================================
// FILE: widgets/track_card.dart
// DESKRIPSI: Widget kartu untuk menampilkan satu track di grid library.
//
// ★ HIGHLIGHT CLOUD:
// - Gambar cover dimuat dari URL Supabase Storage via [Image.network()]
// - Tombol delete memanggil [SupabaseService.deleteTrack()] → hapus dari cloud
// - Tombol edit bisa upload cover baru ke Supabase Storage
// - Tombol add-to-playlist memanggil [SupabaseService.addTrackToPlaylist()]
// =============================================================================

import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/track.dart';
import '../services/firebase_service.dart';
import '../services/audio_manager.dart';

/// Widget kartu untuk satu track — menampilkan cover, judul, artis,
/// serta tombol aksi (play, edit, delete, add to playlist).
class TrackCard extends StatelessWidget {
  final Track track;
  final List<Track> queue;
  final int index;

  const TrackCard({
    super.key,
    required this.track,
    required this.queue,
    required this.index,
  });

  // ---------------------------------------------------------------------------
  // DIALOG: Edit Track (update metadata + upload cover baru ke cloud)
  // ---------------------------------------------------------------------------
  Future<void> _editTrack(BuildContext context) async {
    final titleCtrl = TextEditingController(text: track.title);
    final artistCtrl = TextEditingController(text: track.artist);
    String newCover = track.coverUrl;
    Uint8List? newCoverBytes;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF111111),
            title: const Text('Edit Track'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tap untuk pilih gambar cover baru
                  GestureDetector(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        withData: true, // Penting untuk Flutter Web
                      );
                      if (result != null && result.files.first.path != null) {
                        // ★ FIX: Di desktop, bytes bisa null → baca dari path
                        Uint8List? bytes = result.files.first.bytes;
                        bytes ??= await File(result.files.first.path!).readAsBytes();
                        setModalState(() {
                          newCoverBytes = bytes;
                          newCover = result.files.first.name;
                        });
                      }
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: newCoverBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(newCoverBytes!, fit: BoxFit.cover),
                            )
                          : newCover.isNotEmpty && newCover.startsWith('http')
                              // ★ CLOUD: Load cover dari URL Supabase Storage
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    newCover,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.add_a_photo,
                                      color: Colors.white54,
                                      size: 32,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.add_a_photo, color: Colors.white54, size: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  TextField(
                    controller: artistCtrl,
                    decoration: const InputDecoration(labelText: 'Artist'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () async {
                  String finalCoverUrl = track.coverUrl;

                  // ★ CLOUD: Upload cover baru ke Firebase Storage jika ada
                  if (newCoverBytes != null) {
                    finalCoverUrl = await FirebaseService.uploadCover(
                      newCover.replaceAll(' ', '_'),
                      newCoverBytes!,
                    );
                  }

                  // ★ CLOUD: Update metadata track di database Firebase
                  final updated = Track(
                    id: track.id,
                    title: titleCtrl.text,
                    artist: artistCtrl.text,
                    audioUrl: track.audioUrl,
                    coverUrl: finalCoverUrl,
                    lyrics: track.lyrics,
                  );
                  await FirebaseService.updateTrack(updated);

                  // Refresh UI
                  uiRefreshTrigger.value++;
                  Navigator.pop(ctx);
                },
                child: Text(
                  'Save',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DIALOG: Add Track to Playlist
  // ---------------------------------------------------------------------------
  void _addToPlaylistDialog(BuildContext context) async {
    // ★ CLOUD: Ambil daftar playlist dari Firebase
    final playlists = await FirebaseService.getAllPlaylists();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Add to Playlist'),
        content: SizedBox(
          width: double.maxFinite,
          child: playlists.isEmpty
              ? const Text(
                  'Belum ada playlist. Buat dulu di tab Playlists.',
                  style: TextStyle(color: Colors.white54),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (c, i) => ListTile(
                    title: Text(playlists[i].name),
                    onTap: () async {
                      // ★ CLOUD: Tambah relasi di tabel playlist_tracks
                      await FirebaseService.addTrackToPlaylist(
                        playlists[i].id!,
                        track.id!,
                      );
                      Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added to ${playlists[i].name}')),
                        );
                      }
                    },
                  ),
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD: Tampilan kartu track
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Area Cover Image ---
          Expanded(
            child: Stack(
              children: [
                // ★ CLOUD: Cover image dimuat dari URL Supabase Storage
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: track.coverUrl.isNotEmpty
                      ? Image.network(
                          track.coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _fallbackIcon(),
                        )
                      : _fallbackIcon(),
                ),

                // Tombol aksi (kanan atas)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      _actionBtn(Icons.playlist_add, () => _addToPlaylistDialog(context)),
                      const SizedBox(width: 4),
                      _actionBtn(Icons.edit, () => _editTrack(context)),
                      const SizedBox(width: 4),
                      _actionBtn(Icons.delete, () async {
                        // ★ CLOUD: Hapus track dari database Firebase
                        await FirebaseService.deleteTrack(track.id!);
                        uiRefreshTrigger.value++;
                      }),
                    ],
                  ),
                ),

                // Tombol play (kanan bawah)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    // ★ CLOUD: playTracks() akan streaming dari URL cloud
                    onTap: () => playTracks(queue, index),
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      radius: 22,
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 30),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- Area Teks (judul + artis) ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  track.artist,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _fallbackIcon() => Container(
    color: const Color(0xFF1A1A1A),
    child: const Center(child: Icon(Icons.music_note, color: Colors.white24, size: 48)),
  );

  Widget _actionBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        backgroundColor: Colors.black87,
        radius: 16,
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
