import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_entry.dart';
import '../../domain/repositories/habit_repository.dart';
/// Firestore-backed implementation of [HabitRepository].
///
/// Data layout:
///   users/{uid}/habits/{habitId}          — habit metadata + lifetime aggregates
///   users/{uid}/habits/{habitId}/entries/{YYYY-MM-DD}  — daily entry
///
/// Aggregates (allTimeCompletedCount, allTimeTotalValue) are maintained via
/// fire-and-forget [FieldValue.increment] writes on every [upsertEntry] call.
/// Deltas are pre-computed by the provider from its in-memory entry list, so
/// no read is required. Firestore queues these writes offline and syncs them
/// automatically on reconnect.
///
/// Only entries from the last [_entryWindowDays] days are loaded to keep
/// memory usage bounded; lifetime stats come from the aggregate fields.
class FirestoreHabitRepository implements HabitRepository {
  final FirebaseFirestore _db;

  /// How many days of entries to load for display (current week + retroactive window).
  static const int _entryWindowDays = 28;

  FirestoreHabitRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('FirestoreHabitRepository: no authenticated user');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _habitsRef =>
      _db.collection('users').doc(_uid).collection('habits');

  CollectionReference<Map<String, dynamic>> _entriesRef(String habitId) =>
      _habitsRef.doc(habitId).collection('entries');

  // ── Cache-fallback helpers ────────────────────────────────────────────────

  /// Fetch a query server-first; retries from local cache on network errors.
  /// Only `unavailable`/`deadline-exceeded` trigger the retry — other codes
  /// (e.g. `permission-denied`) are rethrown immediately.
  Future<QuerySnapshot<Map<String, dynamic>>> _queryWithFallback(
      Query<Map<String, dynamic>> query) async {
    try {
      return await query.get();
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable' && e.code != 'deadline-exceeded') rethrow;
      return await query.get(const GetOptions(source: Source.cache));
    }
  }

  // ── HabitRepository interface ─────────────────────────────────────────────

  @override
  Future<List<Habit>> loadHabits() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];

    final habitsSnap = await _queryWithFallback(_habitsRef.orderBy('sortOrder'));
    if (habitsSnap.docs.isEmpty) return const [];

    // Load entries for the last _entryWindowDays days in parallel.
    final cutoffDate = DateTime.now().subtract(const Duration(days: _entryWindowDays));
    final cutoffKey = HabitEntry.dateKey(cutoffDate);

    final entryFutures = habitsSnap.docs.map((doc) async {
      final entriesSnap = await _queryWithFallback(_entriesRef(doc.id)
          .where('date', isGreaterThanOrEqualTo: cutoffKey));
      return entriesSnap.docs
          .map((e) => HabitEntry.fromFirestore(e.data()))
          .toList();
    });

    final entriesList = await Future.wait(entryFutures);

    return List.generate(habitsSnap.docs.length, (i) {
      return Habit.fromFirestore(habitsSnap.docs[i].data(), entries: entriesList[i]);
    }).where((h) => !h.isArchived).toList();
  }

  @override
  Future<void> insertHabit(Habit habit) async {
    await _habitsRef.doc(habit.id).set(habit.toFirestore());
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    // Use merge so we don't accidentally wipe aggregate counters if the caller
    // didn't populate them.
    await _habitsRef.doc(habit.id).set(habit.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    // Delete all entries in the subcollection first (Firestore doesn't cascade).
    await _deleteSubcollection(_entriesRef(habitId));
    await _habitsRef.doc(habitId).delete();
  }

  @override
  Future<void> upsertEntry(HabitEntry entry,
      {int deltaCompleted = 0, double deltaValue = 0}) async {
    final entryKey = HabitEntry.dateKey(entry.date);
    final entryRef = _entriesRef(entry.habitId).doc(entryKey);
    final habitRef = _habitsRef.doc(entry.habitId);

    // Fire-and-forget: Firestore queues writes offline and syncs when online.
    // Delta is precomputed by the provider from its in-memory entry list —
    // no transaction read required.
    entryRef.set(entry.toFirestore()).ignore();

    if (deltaCompleted != 0 || deltaValue != 0.0) {
      habitRef.update({
        'allTimeCompletedCount': FieldValue.increment(deltaCompleted),
        'allTimeTotalValue': FieldValue.increment(deltaValue),
      }).ignore();
    }
  }

  @override
  Future<void> setArchived(String habitId, {required bool archived}) async {
    await _habitsRef.doc(habitId).update({'isArchived': archived});
  }

  @override
  Future<List<Habit>> loadArchivedHabits() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    final snap = await _queryWithFallback(
        _habitsRef.where('isArchived', isEqualTo: true));
    return snap.docs.map((d) => Habit.fromFirestore(d.data())).toList();
  }

  @override
  Future<void> clearHabitEntries(String habitId) async {
    await _deleteSubcollection(_entriesRef(habitId));
    await _habitsRef.doc(habitId).update({
      'allTimeCompletedCount': 0,
      'allTimeTotalValue': 0.0,
    });
  }

  @override
  Future<void> updateHabitSortOrders(List<Habit> habits) async {
    final batch = _db.batch();
    for (final habit in habits) {
      batch.update(_habitsRef.doc(habit.id), {'sortOrder': habit.sortOrder});
    }
    await batch.commit();
  }

  @override
  Future<void> batchUpdateCategoryFields(
      Map<String, Map<String, String?>> updates) async {
    if (updates.isEmpty) return;
    // Chunk into 499-item batches to stay within Firestore's 500-op limit.
    const chunkSize = 499;
    final entries = updates.entries.toList();
    for (var i = 0; i < entries.length; i += chunkSize) {
      final chunk = entries.sublist(i, (i + chunkSize).clamp(0, entries.length));
      final batch = _db.batch();
      for (final entry in chunk) {
        batch.update(_habitsRef.doc(entry.key), entry.value);
      }
      await batch.commit();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Deletes all documents in a subcollection in batches of 100.
  Future<void> _deleteSubcollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    const batchSize = 100;
    QuerySnapshot<Map<String, dynamic>> snap;
    do {
      snap = await ref.limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length == batchSize);
  }
}
