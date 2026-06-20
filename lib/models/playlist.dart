// =============================================================================
// FILE: models/playlist.dart
// DESKRIPSI: Model data untuk playlist.
//
// ★ HIGHLIGHT CLOUD ★
// - Data playlist disimpan di tabel 'playlists' di Supabase PostgreSQL.
// - Relasi playlist ↔ track (many-to-many) ada di tabel 'playlist_tracks'.
// =============================================================================

/// Model yang merepresentasikan sebuah playlist di cloud.
///
/// Playlist hanya menyimpan nama. Daftar lagu di dalam playlist
/// dikelola melalui tabel relasi 'playlist_tracks' di Supabase.
class Playlist {
  final String? id;      // Document ID dari koleksi 'playlists'
  final String name;     // Nama playlist
  final List<String> trackIds; // ★ CLOUD: Daftar ID track dalam playlist

  Playlist({
    this.id, 
    required this.name,
    this.trackIds = const [],
  });

  // ★ CLOUD: Konversi → Map untuk INSERT ke Firestore
  Map<String, dynamic> toMap() => {
    'name': name,
    'track_ids': trackIds,
  };

  // ★ CLOUD: Konversi dari Firestore document → object Playlist
  factory Playlist.fromMap(Map<String, dynamic> map, String docId) {
    return Playlist(
      id: docId,
      name: map['name'] ?? '',
      trackIds: List<String>.from(map['track_ids'] ?? []),
    );
  }
}
