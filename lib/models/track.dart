// =============================================================================
// FILE: models/track.dart
// DESKRIPSI: Model data untuk sebuah lagu (track).
//
// ★ HIGHLIGHT CLOUD ★
// - Field [audioUrl] menyimpan URL publik dari Supabase Storage (bucket 'audio')
//   sehingga audio bisa di-streaming langsung dari cloud.
// - Field [coverUrl] menyimpan URL publik dari Supabase Storage (bucket 'covers')
//   sehingga gambar cover bisa ditampilkan dari cloud.
// - Method [toMap()] mengonversi object → Map untuk INSERT ke Supabase PostgreSQL.
// - Factory [fromMap()] mengonversi Map dari Supabase → object Dart.
// =============================================================================

/// Model yang merepresentasikan satu lagu di aplikasi.
///
/// Setiap track memiliki metadata (title, artist, lyrics) dan dua URL cloud:
/// - [audioUrl]: URL file audio di Supabase Storage → untuk streaming
/// - [coverUrl]: URL gambar cover di Supabase Storage → untuk tampilan UI
class Track {
  final String? id;    // Primary key dari dokumen 'tracks' di Firestore
  final String title;  // Judul lagu
  final String artist; // Nama artis
  final String audioUrl;  // ★ CLOUD: URL publik audio dari Firebase Storage
  final String coverUrl;  // ★ CLOUD: URL publik cover dari Firebase Storage
  final String lyrics;    // Lirik lagu (format LRC atau plain text)

  Track({
    this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    required this.coverUrl,
    this.lyrics = '',
  });

  // ---------------------------------------------------------------------------
  // ★ CLOUD: Konversi object → Map untuk INSERT/UPDATE ke Firestore
  // ---------------------------------------------------------------------------
  // Catatan: 'id' biasanya tidak dimasukkan sebagai field data, melainkan sebagai ID dokumen.
  // Tapi bisa disimpan jika dibutuhkan. Di sini kita simpan yang lain.
  Map<String, dynamic> toMap() => {
    'title': title,
    'artist': artist,
    'audio_url': audioUrl,
    'cover_url': coverUrl,
    'lyrics': lyrics,
  };

  // ---------------------------------------------------------------------------
  // ★ CLOUD: Konversi Map dari Firestore → object Track
  // ---------------------------------------------------------------------------
  factory Track.fromMap(Map<String, dynamic> map, String docId) => Track(
    id: docId,
    title: map['title'] ?? '',
    artist: map['artist'] ?? 'Unknown Artist',
    audioUrl: map['audio_url'] ?? '',
    coverUrl: map['cover_url'] ?? '',
    lyrics: map['lyrics'] ?? '',
  );
}
