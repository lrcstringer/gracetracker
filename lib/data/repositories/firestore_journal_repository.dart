import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/entities/journal_entry.dart';
import '../../domain/repositories/journal_repository.dart';

class FirestoreJournalRepository implements JournalRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  FirestoreJournalRepository({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  })  : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('FirestoreJournalRepository: no authenticated user');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _journalRef =>
      _db.collection('users').doc(_uid).collection('journal');

  @override
  Stream<List<JournalEntry>> watchEntries() {
    if (FirebaseAuth.instance.currentUser?.uid == null) return const Stream.empty();
    return _journalRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => JournalEntry.fromFirestore(d.data())).toList());
  }

  @override
  Future<List<JournalEntry>> loadEntries() async {
    if (FirebaseAuth.instance.currentUser?.uid == null) return const [];
    final snap = await _journalRef.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => JournalEntry.fromFirestore(d.data())).toList();
  }

  @override
  Future<void> saveEntry(JournalEntry entry) async {
    // Fire-and-forget: Firestore queues writes locally when offline and
    // syncs automatically when connectivity is restored.
    _journalRef.doc(entry.id).set(entry.toFirestore()).ignore();
  }

  @override
  Future<void> updateEntry(JournalEntry entry) async {
    _journalRef.doc(entry.id).set(entry.toFirestore(), SetOptions(merge: true)).ignore();
  }

  @override
  Future<void> deleteEntry(String id) async {
    _journalRef.doc(id).delete().ignore();
  }

  @override
  Future<String> uploadMedia(String localPath, String entryId, String filename) async {
    final uid = _uid;
    final ref = _storage.ref('journal/$uid/$entryId/$filename');
    final file = File(localPath);
    final task = await ref.putFile(file);
    return await task.ref.getDownloadURL();
  }

  @override
  Future<void> deleteMedia(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // If the file doesn't exist in Storage, ignore the error.
    }
  }
}
