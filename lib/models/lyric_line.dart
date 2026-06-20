// =============================================================================
// FILE: models/lyric_line.dart
// DESKRIPSI: Model dan helper function untuk parsing lirik format LRC.
//
// Bagian ini BUKAN cloud — murni logic di sisi client untuk parsing dan
// menampilkan lirik yang sudah disimpan di database Supabase.
// =============================================================================

/// Model satu baris lirik dengan timestamp (dari format LRC).
class LyricLine {
  final Duration time;  // Waktu kapan baris lirik ini muncul
  final String text;    // Isi teks lirik

  LyricLine(this.time, this.text);
}

// =============================================================================
// PARSER LRC
// =============================================================================

/// Parse string lirik berformat LRC menjadi list [LyricLine].
///
/// Contoh format LRC:
/// ```
/// [00:15.30] Ini baris lirik pertama
/// [00:20.50] Ini baris lirik kedua
/// ```
///
/// Regex menangkap: [menit:detik.milidetik] teks
List<LyricLine> parseLRC(String lyrics) {
  if (lyrics.isEmpty) return [];
  final lines = lyrics.split('\n');
  final RegExp regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
  List<LyricLine> result = [];

  for (var line in lines) {
    final match = regex.firstMatch(line);
    if (match != null) {
      final m = int.parse(match.group(1)!);   // menit
      final s = int.parse(match.group(2)!);   // detik
      final msStr = match.group(3)!;
      final ms = int.parse(msStr.length == 2 ? '${msStr}0' : msStr); // milidetik
      final text = match.group(4)!.trim();
      result.add(LyricLine(
        Duration(minutes: m, seconds: s, milliseconds: ms),
        text,
      ));
    }
  }
  return result;
}

/// Cari baris lirik yang sedang aktif berdasarkan posisi audio saat ini.
///
/// Mencari dari bawah ke atas — baris terakhir yang time-nya ≤ currentPos
/// adalah baris yang sedang aktif.
String getCurrentLyric(List<LyricLine> lines, Duration currentPos) {
  if (lines.isEmpty) return '';
  for (int i = lines.length - 1; i >= 0; i--) {
    if (currentPos >= lines[i].time) {
      return lines[i].text;
    }
  }
  return lines.first.text;
}
