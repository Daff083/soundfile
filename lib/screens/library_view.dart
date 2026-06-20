// =============================================================================
// FILE: screens/library_view.dart
// DESKRIPSI: Halaman utama "Cloud Library" — menampilkan semua track dari cloud.
//
// ★ HIGHLIGHT CLOUD:
// - Data tracks diambil dari Firebase Firestore via FirebaseService.getAllTracks()]
// - FutureBuilder menunggu response dari cloud sebelum menampilkan grid
// - Setiap track yang ditampilkan mempunyai URL audio & cover dari cloud
// =============================================================================

import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/firebase_service.dart';
import '../services/audio_manager.dart';
import '../widgets/track_card.dart';

/// Halaman library yang menampilkan semua track dari Supabase cloud
/// dalam bentuk grid card.
class LibraryView extends StatelessWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: uiRefreshTrigger,
      builder: (context, _, __) {
        // ★ CLOUD: Mengambil semua track dari Firebase Firestore
        return FutureBuilder<List<Track>>(
          future: FirebaseService.getAllTracks(),
          builder: (context, snapshot) {
            // --- State: Loading (menunggu response dari cloud) ---
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
              );
            }

            // --- State: Error (gagal koneksi ke cloud) ---
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.white24, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // --- State: Data kosong ---
            final tracks = snapshot.data!;
            if (tracks.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_upload_outlined, color: Colors.white24, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Cloud library kosong.',
                      style: TextStyle(color: Colors.white54, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Klik "Import MP3" untuk upload lagu ke cloud.',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            // --- State: Data berhasil dimuat dari cloud ---
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                childAspectRatio: 0.75,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                return TrackCard(
                  track: tracks[index],
                  queue: tracks,
                  index: index,
                );
              },
            );
          },
        );
      },
    );
  }
}
