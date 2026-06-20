import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/track.dart';
import '../models/playlist.dart';

/// Service class yang menangani SEMUA operasi cloud (Firebase).
///
/// Menggunakan [FirebaseFirestore] untuk database dan [FirebaseStorage] untuk file.
class FirebaseService {
  // =========================================================================
  // ★ CLOUD AUTHENTICATION — Login & Register (Firebase Auth)
  // =========================================================================

  /// Mendapatkan user yang sedang login saat ini.
  static User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Register user baru menggunakan email dan password.
  static Future<UserCredential> signUp(String email, String password) async {
    return await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Login user menggunakan email dan password.
  static Future<UserCredential> signIn(String email, String password) async {
    return await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Logout user dari aplikasi.
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // =========================================================================
  // ★ CLOUD DATABASE — CRUD TRACKS (Firestore)
  // =========================================================================

  /// ★ INSERT — Menambahkan track baru ke Firestore.
  static Future<void> insertTrack(Track track) async {
    await FirebaseFirestore.instance.collection('tracks').add(track.toMap());
  }

  /// ★ SELECT — Mengambil semua track dari Firestore.
  static Future<List<Track>> getAllTracks() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('tracks')
        // Order by creation time if we add a timestamp, for now just get them
        .get();
    
    return snapshot.docs.map((doc) => Track.fromMap(doc.data(), doc.id)).toList();
  }

  /// ★ UPDATE — Memperbarui data track di Firestore.
  static Future<void> updateTrack(Track track) async {
    if (track.id == null) return;
    await FirebaseFirestore.instance
        .collection('tracks')
        .doc(track.id)
        .update(track.toMap());
  }

  /// ★ DELETE — Menghapus track dari Firestore.
  static Future<void> deleteTrack(String id) async {
    // Note: We might want to remove this track from all playlists too
    // For now we just delete the track
    await FirebaseFirestore.instance.collection('tracks').doc(id).delete();
  }

  // =========================================================================
  // ★ CLOUD DATABASE — CRUD PLAYLISTS (Firestore)
  // =========================================================================

  /// ★ INSERT — Membuat playlist baru di Firestore.
  static Future<void> insertPlaylist(String name) async {
    final newPlaylist = Playlist(name: name, trackIds: []);
    await FirebaseFirestore.instance.collection('playlists').add(newPlaylist.toMap());
  }

  /// ★ SELECT — Mengambil semua playlist dari Firestore.
  static Future<List<Playlist>> getAllPlaylists() async {
    final snapshot = await FirebaseFirestore.instance.collection('playlists').get();
    return snapshot.docs.map((doc) => Playlist.fromMap(doc.data(), doc.id)).toList();
  }

  /// ★ DELETE — Menghapus playlist dari Firestore.
  static Future<void> deletePlaylist(String id) async {
    await FirebaseFirestore.instance.collection('playlists').doc(id).delete();
  }

  // =========================================================================
  // ★ CLOUD DATABASE — RELASI MANY-TO-MANY (NoSQL Array)
  // =========================================================================

  /// ★ INSERT RELASI — Menambahkan track ke dalam playlist.
  static Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    await FirebaseFirestore.instance.collection('playlists').doc(playlistId).update({
      'track_ids': FieldValue.arrayUnion([trackId])
    });
  }

  /// ★ DELETE RELASI — Mengeluarkan track dari playlist.
  static Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await FirebaseFirestore.instance.collection('playlists').doc(playlistId).update({
      'track_ids': FieldValue.arrayRemove([trackId])
    });
  }

  /// ★ SELECT JOIN — Mengambil semua track dalam sebuah playlist.
  static Future<List<Track>> getTracksForPlaylist(String playlistId) async {
    final playlistDoc = await FirebaseFirestore.instance.collection('playlists').doc(playlistId).get();
    if (!playlistDoc.exists) return [];

    final trackIds = List<String>.from(playlistDoc.data()?['track_ids'] ?? []);
    if (trackIds.isEmpty) return [];

    // Note: Firestore 'in' query supports max 10 items.
    // For playlists with > 10 items, we might need multiple queries or fetch tracks locally.
    // For simplicity in this migration, we fetch tracks one by one or chunk them.
    List<Track> tracks = [];
    // Chunking array into size 10 max
    for (var i = 0; i < trackIds.length; i += 10) {
      final end = (i + 10 < trackIds.length) ? i + 10 : trackIds.length;
      final chunk = trackIds.sublist(i, end);
      
      final snapshot = await FirebaseFirestore.instance
          .collection('tracks')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
          
      tracks.addAll(snapshot.docs.map((doc) => Track.fromMap(doc.data(), doc.id)));
    }
    
    // Sort to match original trackIds order if needed (skipping for now)
    return tracks;
  }

  // =========================================================================
  // ★ CLOUD STORAGE — UPLOAD FILE KE FIREBASE STORAGE
  // =========================================================================

  /// ★ UPLOAD AUDIO — Upload file audio ke folder 'audio' di Firebase Storage.
  static Future<String> uploadAudio(String fileName, Uint8List bytes) async {
    try {
      final path = 'audio/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = FirebaseStorage.instance.ref().child(path);
      
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'audio/mpeg'),
      );

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload audio error: $e');
      rethrow;
    }
  }

  /// ★ UPLOAD COVER — Upload gambar cover ke folder 'covers' di Firebase Storage.
  static Future<String> uploadCover(String fileName, Uint8List bytes) async {
    try {
      final path = 'covers/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = FirebaseStorage.instance.ref().child(path);
      
      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload cover error: $e');
      rethrow;
    }
  }
}
