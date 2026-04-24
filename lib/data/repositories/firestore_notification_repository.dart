import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/circle_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/remote/api_service.dart';
import '../services/pending_action_queue_service.dart';
import '../services/pending_notification_send_queue.dart';

class FirestoreNotificationRepository implements NotificationRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final PendingActionQueueService _queue;
  final PendingNotificationSendQueue _sendQueue;

  FirestoreNotificationRepository(this._queue, this._sendQueue)
      : _db = FirebaseFirestore.instance,
        _auth = FirebaseAuth.instance;

  /// Returns null if no user is authenticated.
  String? get _uidOrNull => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  // ── Stream ─────────────────────────────────────────────────────────────────

  @override
  Stream<List<CircleNotification>> watchInbox() {
    final uid = _uidOrNull;
    if (uid == null) return const Stream.empty();
    return _inbox(uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map(_docToNotification).toList());
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  @override
  Future<List<CircleNotification>> getInbox({
    int limit = 50,
    bool onlyUnread = false,
  }) async {
    try {
      final items = await APIService.shared.getNotificationInbox(
        limit: limit,
        onlyUnread: onlyUnread,
      );
      return items
          .map(
            (i) => CircleNotification.fromJson({
              'id': i.id,
              'type': i.type,
              'circleId': i.circleId,
              'circleName': i.circleName,
              'senderUid': i.senderUid,
              'senderName': i.senderName,
              'message': i.message,
              'createdAt': i.createdAt,
              'isRead': i.isRead,
              'actionTaken': i.actionTaken,
              'suppressActions': i.suppressActions,
            }),
          )
          .toList();
    } catch (_) {
      // HTTP API is unavailable (offline, server error, captive portal).
      // Return empty list so callers degrade gracefully; the real-time
      // [watchInbox] stream remains the authoritative source of truth and
      // continues to work from Firestore's local cache.
      return const [];
    }
  }

  @override
  Future<int> getUnreadCount() async {
    final uid = _uidOrNull;
    if (uid == null) return 0;
    try {
      final snap =
          await _inbox(uid).where('isRead', isEqualTo: false).count().get();
      return snap.count ?? 0;
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable' && e.code != 'deadline-exceeded') rethrow;
      // count() aggregate queries are server-only and have no local-cache
      // representation. Return 0 when offline rather than throwing.
      return 0;
    }
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  @override
  Future<void> markRead(String notifId) async {
    final uid = _uidOrNull;
    if (uid == null) return;
    // Local Firestore write triggers the stream immediately (offline-first).
    await _inbox(uid).doc(notifId).update({'isRead': true});
    // Fire-and-forget sync to server; failure is acceptable (stream is source of truth).
    APIService.shared.markNotificationRead(notifId).catchError((_) {});
  }

  @override
  Future<void> recordAction(String notifId, NotificationAction action) async {
    final uid = _uidOrNull;
    if (uid == null) return;
    final actionStr = switch (action) {
      NotificationAction.pray => 'pray',
      NotificationAction.imHere => 'im_here',
      NotificationAction.accept => 'accept',
      NotificationAction.decline => 'decline',
    };
    // Local write for immediate UI feedback.
    await _inbox(uid)
        .doc(notifId)
        .update({'actionTaken': actionStr, 'isRead': true});
    // Route through offline queue: tries immediately, persists on failure.
    await _queue.enqueue(notifId, actionStr);
  }

  @override
  Future<void> sendAnnouncement({
    required String circleId,
    required String message,
  }) =>
      _sendQueue.enqueue({
        'type': 'announcement',
        'circleId': circleId,
        'message': message,
      });

  @override
  Future<void> sendPrayerRequest({
    required String circleId,
    required String message,
    required List<String> recipientIds,
  }) =>
      // Bypass the offline queue so rate-limit (429) and other errors surface
      // immediately to the UI instead of being silently retried.
      APIService.shared.sendPrayerRequest(
        circleId: circleId,
        message: message,
        recipientIds: recipientIds,
      );

  // ── Helpers ────────────────────────────────────────────────────────────────

  CircleNotification _docToNotification(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data()!;
    String createdAtStr;
    final raw = d['createdAt'];
    if (raw is Timestamp) {
      createdAtStr = raw.toDate().toIso8601String();
    } else {
      createdAtStr = raw?.toString() ?? DateTime.now().toIso8601String();
    }
    return CircleNotification.fromJson({...d, 'createdAt': createdAtStr});
  }
}
