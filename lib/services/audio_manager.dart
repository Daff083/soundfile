// =============================================================================
// FILE: services/audio_manager.dart
// DESKRIPSI: Global audio player dan state management.
//
// ★ HIGHLIGHT CLOUD ★
// - [playTracks()] menerima URL cloud dari Firebase Storage, lalu
//   AudioSource.uri() melakukan streaming langsung dari URL tersebut.
//   Tidak ada file lokal — semua audio diputar dari cloud!
// =============================================================================

import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import '../models/track.dart';

// =============================================================================
// GLOBAL STATE
// =============================================================================
// Variabel global agar audio player bisa diakses dari mana saja (semua widget).

/// Instance audio player tunggal untuk seluruh aplikasi.
final AudioPlayer audioPlayer = AudioPlayer();

/// Track yang sedang diputar saat ini.
final ValueNotifier<Track?> currentTrackNotifier = ValueNotifier(null);

/// Daftar track (queue/antrian) yang sedang diputar.
final ValueNotifier<List<Track>> currentQueueNotifier = ValueNotifier([]);

/// Trigger untuk refresh UI ketika data berubah (misal: setelah upload/delete).
final ValueNotifier<int> uiRefreshTrigger = ValueNotifier(0);

// =============================================================================
// ★ CLOUD STREAMING — Memutar audio dari URL Firebase Storage
// =============================================================================

/// Memutar daftar track dari cloud.
///
/// ★ CLOUD: Setiap [track.audioUrl] adalah URL publik dari Firebase Storage.
/// AudioSource.uri() akan melakukan HTTP streaming langsung dari URL tersebut.
/// Flutter tidak perlu mendownload file — audio di-stream secara real-time.
///
/// Alur:
/// 1. Simpan daftar track ke [currentQueueNotifier] (untuk UI)
/// 2. Buat [ConcatenatingAudioSource] dari semua URL cloud
/// 3. Set audio source dan mulai putar dari [startIndex]
/// 4. Loop mode = all (ulangi semua track setelah selesai)
Future<void> playTracks(List<Track> tracks, int startIndex) async {
  currentQueueNotifier.value = tracks;

  // Buat playlist dari URL-URL cloud
  final playlist = ConcatenatingAudioSource(
    children: tracks.map((t) {
      // ★ CLOUD: Uri.parse(t.audioUrl) → streaming dari Firebase Storage
      return AudioSource.uri(
        Uri.parse(t.audioUrl),
        tag: t.title,
      );
    }).toList(),
  );

  await audioPlayer.setAudioSource(playlist, initialIndex: startIndex);
  await audioPlayer.setLoopMode(LoopMode.all);
  await audioPlayer.play();
}
