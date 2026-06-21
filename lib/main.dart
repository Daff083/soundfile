// =============================================================================
//
// ╔═══════════════════════════════════════════════════════════════════════════╗
// ║                         SOUNDCANVAS FLUTTER                             ║
// ║                    Cloud Music Player with Supabase                     ║
// ╚═══════════════════════════════════════════════════════════════════════════╝
//
// FILE: main.dart
// DESKRIPSI: Entry point aplikasi — inisialisasi Supabase Cloud dan layout utama.
//
// ★★★ HIGHLIGHT CLOUD ★★★
// - Supabase.initialize() menghubungkan app ke backend cloud
// - Import audio dari komputer → Upload ke Supabase Storage → Simpan metadata ke DB
//
// STRUKTUR FILE (setelah dirapikan):
// ┌─ lib/
// │  ├─ main.dart                          ← File ini (entry point + layout)
// │  ├─ models/
// │  │  ├─ track.dart                      ← Model data track
// │  │  ├─ playlist.dart                   ← Model data playlist
// │  │  └─ lyric_line.dart                 ← Model + parser lirik LRC
// │  ├─ services/
// │  │  ├─ supabase_service.dart           ← ★ INTI CLOUD (CRUD + Storage)
// │  │  └─ audio_manager.dart              ← Audio player + cloud streaming
// │  ├─ screens/
// │  │  ├─ library_view.dart               ← Halaman Cloud Library
// │  │  └─ playlist_view.dart              ← Halaman Playlist + Detail
// │  └─ widgets/
// │     ├─ track_card.dart                 ← Widget kartu track
// │     ├─ floating_player.dart            ← Widget player mengambang
// │     └─ lyrics_panel.dart               ← Widget panel lirik
// └─ pubspec.yaml                          ← Dependencies (supabase_flutter, dll)
// =============================================================================

import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'models/track.dart';
import 'models/playlist.dart';
import 'services/firebase_service.dart';
import 'services/audio_manager.dart';
import 'screens/library_view.dart';
import 'screens/playlist_view.dart';
import 'widgets/floating_player.dart';
import 'widgets/lyrics_panel.dart';

// =============================================================================
// ★ CLOUD INITIALIZATION — Entry Point Aplikasi
// =============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ★ CLOUD: Inisialisasi koneksi ke Firebase Cloud
  // Catatan: Pastikan Anda telah menjalankan `flutterfire configure`
  // untuk men-generate file konfigurasi yang dibutuhkan.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed. Please run 'flutterfire configure'.");
  }

  // Listener: update track yang sedang diputar ketika index berubah
  audioPlayer.currentIndexStream.listen((index) {
    if (index != null && currentQueueNotifier.value.isNotEmpty) {
      if (index < currentQueueNotifier.value.length) {
        currentTrackNotifier.value = currentQueueNotifier.value[index];
      }
    }
  });

  runApp(const SoundCanvasApp());
}

// =============================================================================
// APP THEME & ROOT WIDGET
// =============================================================================

/// Root widget — konfigurasi tema dark premium.
class SoundCanvasApp extends StatelessWidget {
  const SoundCanvasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundCanvas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: const Color(0xFF00E5FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00B3CC),
          surface: Color(0xFF111111),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const MainLayout(),
    );
  }
}

// =============================================================================
// MAIN LAYOUT — Struktur utama halaman
// =============================================================================

/// Layout utama aplikasi: Sidebar + Content + Lyrics Panel + Floating Player.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _activeMenu = 0;       // 0 = Library, 1 = Playlists
  bool _showLyrics = false;  // Toggle panel lirik
  Playlist? _selectedPlaylist;
  bool _isImporting = false;  // Loading state saat upload ke cloud

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.8, -0.5),
                radius: 1.5,
                colors: [Color(0xFF0F2027), Color(0xFF050505)],
              ),
            ),
          ),

          // Layer 2: Sidebar + Content
          Row(
            children: [
              // --- Sidebar Navigation ---
              Container(
                width: 80,
                color: Colors.black.withOpacity(0.5),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Icon(Icons.graphic_eq, color: Theme.of(context).primaryColor, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'CLOUD',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _sideIcon(Icons.library_music, 0),  // Library
                    _sideIcon(Icons.queue_music, 1),     // Playlists
                    const Spacer(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // --- Main Content Area ---
              Expanded(child: _buildMainContent()),
            ],
          ),

          // Layer 3: Slide-in Lyrics Panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            right: _showLyrics ? 0 : -350,
            top: 0,
            bottom: 110,
            width: 350,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                border: const Border(left: BorderSide(color: Colors.white10)),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: LyricsPanel(
                onClose: () => setState(() => _showLyrics = false),
              ),
            ),
          ),

          // Layer 4: Floating Player (bawah)
          Positioned(
            bottom: 30,
            left: 100,
            right: 32,
            child: FloatingPlayer(
              onToggleLyrics: () => setState(() => _showLyrics = !_showLyrics),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTENT BUILDER
  // ---------------------------------------------------------------------------
  Widget _buildMainContent() {
    // Jika sedang melihat detail playlist
    if (_activeMenu == 1 && _selectedPlaylist != null) {
      return PlaylistDetailView(
        playlist: _selectedPlaylist!,
        onBack: () => setState(() => _selectedPlaylist = null),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Header ---
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _activeMenu == 0 ? 'Cloud Library' : 'Your Playlists',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  // Badge koneksi Firebase
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCA28).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done, size: 12, color: Color(0xFFFFCA28)),
                        SizedBox(width: 4),
                        Text(
                          'Firebase Connected',
                          style: TextStyle(fontSize: 11, color: Color(0xFFFFCA28)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Tombol Import MP3 (hanya di Library)
              if (_activeMenu == 0)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _isImporting ? 'Uploading...' : 'Import MP3',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // ★ CLOUD: Tombol ini memulai proses upload ke Supabase
                  onPressed: _isImporting ? null : _importAudioToCloud,
                ),
            ],
          ),
        ),

        // --- Content (Library atau Playlists) ---
        Expanded(
          child: _activeMenu == 0
              ? const LibraryView()
              : PlaylistView(
                  onPlaylistTap: (p) => setState(() => _selectedPlaylist = p),
                ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SIDEBAR ICON
  // ---------------------------------------------------------------------------
  Widget _sideIcon(IconData icon, int index) {
    final isActive = _activeMenu == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeMenu = index;
          _selectedPlaylist = null;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: isActive ? Theme.of(context).primaryColor : Colors.white54,
          size: 28,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ★ CLOUD: IMPORT AUDIO — Upload file dari komputer ke Supabase Cloud
  // ---------------------------------------------------------------------------
  //
  // ALUR LENGKAP:
  // 1. User klik "Import MP3"
  // 2. FilePicker membuka dialog pemilihan file (support multi-select)
  // 3. Setiap file yang dipilih:
  //    a. Upload bytes audio ke Firebase Storage (folder 'audio')
  //    b. Dapatkan URL publik dari storage
  //    c. Insert metadata (judul, artis, URL) ke koleksi 'tracks' di Firestore
  // 4. Refresh UI untuk menampilkan track baru
  //
  Future<void> _importAudioToCloud() async {
    try {
      // Step 1: Pilih file audio dari komputer
      // withData: true → penting untuk Flutter Web (mendapat bytes)
      // Di desktop (Windows/macOS/Linux), file.bytes bisa null → pakai file.path
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        withData: true,
      );

      if (result != null) {
        setState(() => _isImporting = true);

        int successCount = 0;

        for (var file in result.files) {
          // ★ FIX: Di Windows desktop, file.bytes seringkali null.
          // Solusi: baca bytes dari file.path jika bytes null.
          Uint8List? fileBytes = file.bytes;

          if (fileBytes == null && file.path != null) {
            // Desktop platform: baca file dari disk
            try {
              fileBytes = await File(file.path!).readAsBytes();
              debugPrint('Read ${file.name} from path: ${file.path} (${fileBytes.length} bytes)');
            } catch (readError) {
              debugPrint('Error reading file ${file.name}: $readError');
              continue; // Skip file ini, lanjut ke file berikutnya
            }
          }

          if (fileBytes != null && fileBytes.isNotEmpty) {
            // Step 2: ★ CLOUD — Upload file audio ke Firebase Storage
            final audioUrl = await FirebaseService.uploadAudio(
              file.name.replaceAll(' ', '_'),
              fileBytes,
            );

            // Step 3: ★ CLOUD — Simpan metadata ke database Firebase
            String fileName = file.name
                .replaceAll('.mp3', '')
                .replaceAll('.wav', '')
                .replaceAll('.m4a', '')
                .replaceAll('.ogg', '')
                .replaceAll('.flac', '');

            final newTrack = Track(
              title: fileName,
              artist: 'Unknown Artist',
              audioUrl: audioUrl, // ← URL cloud, bukan path lokal!
              coverUrl: '',
            );
            await FirebaseService.insertTrack(newTrack);
            successCount++;
          } else {
            debugPrint('Skipped ${file.name}: no bytes available (bytes=null, path=${file.path})');
          }
        }

        // Step 4: Refresh UI
        uiRefreshTrigger.value++;
        setState(() => _isImporting = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$successCount dari ${result.files.length} file berhasil diupload ke cloud!'),
              backgroundColor: successCount > 0 ? const Color(0xFF00E5FF) : Colors.orangeAccent,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isImporting = false);
      debugPrint("Import Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}