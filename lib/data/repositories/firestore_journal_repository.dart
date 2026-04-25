import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/journal_entry.dart';
import '../../domain/repositories/journal_repository.dart';

class FirestoreJournalRepository implements JournalRepository {
  final FirebaseFirestore _db;

  FirestoreJournalRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

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
}
