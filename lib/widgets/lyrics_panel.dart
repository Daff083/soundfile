// =============================================================================
// FILE: widgets/lyrics_panel.dart
// DESKRIPSI: Panel slide-in untuk menampilkan dan mengedit lirik.
//
// ★ HIGHLIGHT CLOUD:
// - Saat menyimpan lirik, data dikirim ke Supabase via updateTrack()
// - Lirik tersinkronisasi di cloud — bisa diakses dari device manapun
// =============================================================================

import 'package:flutter/material.dart';
import '../models/track.dart';
import '../models/lyric_line.dart';
import '../services/firebase_service.dart';
import '../services/audio_manager.dart';

/// Panel lirik dengan dua mode: View (tampilkan lirik sinkron) dan Edit.
class LyricsPanel extends StatefulWidget {
  final VoidCallback onClose;
  const LyricsPanel({super.key, required this.onClose});

  @override
  State<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<LyricsPanel> {
  final TextEditingController _lyricCtrl = TextEditingController();
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Track?>(
      valueListenable: currentTrackNotifier,
      builder: (context, track, _) {
        if (track == null) return const SizedBox();
        if (_lyricCtrl.text.isEmpty && track.lyrics.isNotEmpty) {
          _lyricCtrl.text = track.lyrics;
        }

        final parsed = parseLRC(track.lyrics);
        final hasTimeTags = parsed.isNotEmpty;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header: Judul + Tombol Edit/Close ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Lyrics',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isEditing ? Icons.check : Icons.edit,
                            color: _isEditing
                                ? Theme.of(context).primaryColor
                                : Colors.white54,
                          ),
                          onPressed: () async {
                            if (_isEditing) {
                              // ★ CLOUD: Simpan lirik ke database Supabase
                              final updated = Track(
                                id: track.id,
                                title: track.title,
                                artist: track.artist,
                                audioUrl: track.audioUrl,
                                coverUrl: track.coverUrl,
                                lyrics: _lyricCtrl.text,
                              );
                              await FirebaseService.updateTrack(updated);
                              currentTrackNotifier.value = updated;
                            }
                            setState(() => _isEditing = !_isEditing);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                  ],
                ),

                // --- Mode Edit ---
                if (_isEditing) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Paste LRC format like [00:15.30] Text here to sync.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(
                      controller: _lyricCtrl,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Paste LRC text here...',
                      ),
                    ),
                  ),
                ]
                // --- Mode View (Lirik Sinkron) ---
                else ...[
                  const SizedBox(height: 20),
                  Expanded(
                    child: hasTimeTags
                        ? StreamBuilder<Duration>(
                            stream: audioPlayer.positionStream,
                            builder: (context, snapshot) {
                              final pos = snapshot.data ?? Duration.zero;
                              return ListView.builder(
                                itemCount: parsed.length,
                                itemBuilder: (context, index) {
                                  final line = parsed[index];
                                  final isNext = index + 1 < parsed.length
                                      ? pos >= line.time && pos < parsed[index + 1].time
                                      : pos >= line.time;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      line.text,
                                      style: TextStyle(
                                        fontSize: isNext ? 22 : 18,
                                        fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                                        color: isNext
                                            ? Theme.of(context).primaryColor
                                            : Colors.white30,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          )
                        : SingleChildScrollView(
                            child: Text(
                              track.lyrics.isEmpty
                                  ? "No lyrics found. Click edit to add."
                                  : track.lyrics,
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.8,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
