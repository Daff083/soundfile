// =============================================================================
// FILE: widgets/floating_player.dart
// DESKRIPSI: Widget player musik mengambang di bagian bawah layar.
//
// ★ HIGHLIGHT CLOUD:
// - Cover image dimuat dari URL Firebase Storage via Image.network()
// - Audio streaming langsung dari cloud (dikelola oleh AudioManager)
// =============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import '../services/audio_manager.dart';

/// Widget floating player — menampilkan info track, kontrol playback,
/// progress bar, dan volume slider.
class FloatingPlayer extends StatelessWidget {
  final VoidCallback onToggleLyrics;

  const FloatingPlayer({super.key, required this.onToggleLyrics});

  /// Format durasi ke string "m:ss"
  String format(Duration d) =>
      "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Track?>(
      valueListenable: currentTrackNotifier,
      builder: (context, track, child) {
        // Sembunyikan jika tidak ada track yang diputar
        if (track == null) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A).withOpacity(0.9),
            borderRadius: BorderRadius.circular(45),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(45),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // =============================
                    // KIRI: Info Track
                    // =============================
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          // ★ CLOUD: Cover dari URL Firebase Storage
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: track.coverUrl.isNotEmpty
                                ? Image.network(
                                    track.coverUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => _dummyCover(56),
                                  )
                                : _dummyCover(56),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                    ),

                    // =============================
                    // TENGAH: Kontrol Playback + Progress Bar
                    // =============================
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Baris tombol kontrol
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Shuffle
                              StreamBuilder<bool>(
                                stream: audioPlayer.shuffleModeEnabledStream,
                                builder: (context, snapshot) {
                                  final isShuffle = snapshot.data ?? false;
                                  return IconButton(
                                    icon: Icon(
                                      Icons.shuffle,
                                      color: isShuffle
                                          ? Theme.of(context).primaryColor
                                          : Colors.white54,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        audioPlayer.setShuffleModeEnabled(!isShuffle),
                                  );
                                },
                              ),

                              // Previous
                              IconButton(
                                icon: const Icon(Icons.skip_previous_rounded,
                                    color: Colors.white, size: 28),
                                onPressed: () => audioPlayer.seekToPrevious(),
                              ),

                              // Play/Pause
                              StreamBuilder<bool>(
                                stream: audioPlayer.playingStream,
                                builder: (context, snapshot) {
                                  final playing = snapshot.data ?? false;
                                  return GestureDetector(
                                    onTap: () => playing
                                        ? audioPlayer.pause()
                                        : audioPlayer.play(),
                                    child: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: Theme.of(context).primaryColor,
                                      child: Icon(
                                        playing
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.black,
                                        size: 30,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Next
                              IconButton(
                                icon: const Icon(Icons.skip_next_rounded,
                                    color: Colors.white, size: 28),
                                onPressed: () => audioPlayer.seekToNext(),
                              ),

                              // Loop Mode
                              StreamBuilder<LoopMode>(
                                stream: audioPlayer.loopModeStream,
                                builder: (context, snapshot) {
                                  final mode = snapshot.data ?? LoopMode.off;
                                  return IconButton(
                                    icon: Icon(
                                      mode == LoopMode.off
                                          ? Icons.repeat
                                          : (mode == LoopMode.one
                                              ? Icons.repeat_one
                                              : Icons.repeat_on),
                                      color: mode == LoopMode.off
                                          ? Colors.white54
                                          : Theme.of(context).primaryColor,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      if (mode == LoopMode.off) {
                                        audioPlayer.setLoopMode(LoopMode.all);
                                      } else if (mode == LoopMode.all) {
                                        audioPlayer.setLoopMode(LoopMode.one);
                                      } else {
                                        audioPlayer.setLoopMode(LoopMode.off);
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ),

                          // Progress Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: StreamBuilder<Duration>(
                              stream: audioPlayer.positionStream,
                              builder: (context, snapshot) {
                                final pos = snapshot.data ?? Duration.zero;
                                final dur = audioPlayer.duration ?? Duration.zero;
                                return Row(
                                  children: [
                                    Text(
                                      format(pos),
                                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderThemeData(
                                          trackHeight: 2,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                          activeTrackColor: Theme.of(context).primaryColor,
                                          inactiveTrackColor: Colors.white24,
                                          thumbColor: Colors.white,
                                        ),
                                        child: Slider(
                                          value: pos.inSeconds.toDouble().clamp(
                                            0.0,
                                            dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0,
                                          ),
                                          max: dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0,
                                          onChanged: (v) =>
                                              audioPlayer.seek(Duration(seconds: v.toInt())),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      format(dur),
                                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // =============================
                    // KANAN: Lyrics + Volume
                    // =============================
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.lyrics_outlined, color: Colors.white54),
                            onPressed: onToggleLyrics,
                            tooltip: 'Lyrics',
                          ),
                          const Icon(Icons.volume_up_rounded, color: Colors.white54, size: 18),
                          Expanded(
                            child: StreamBuilder<double>(
                              stream: audioPlayer.volumeStream,
                              builder: (context, snapshot) {
                                return SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                    activeTrackColor: Theme.of(context).primaryColor,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: Colors.white,
                                  ),
                                  child: Slider(
                                    value: snapshot.data ?? 1.0,
                                    onChanged: (v) => audioPlayer.setVolume(v),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Placeholder cover jika tidak ada gambar
  Widget _dummyCover(double size) => Container(
    color: Colors.white10,
    width: size,
    height: size,
    child: Icon(Icons.music_note, color: Colors.white24, size: size / 2),
  );
}
