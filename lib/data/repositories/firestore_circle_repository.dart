import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/circle.dart';
import '../../domain/entities/habit.dart' show PrayerItemStatus;
import '../../domain/repositories/circle_repository.dart';
import '../../domain/services/week_id_service.dart';
import '../services/pending_notification_send_queue.dart';

class FirestoreCircleRepository implements CircleRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _fn;
  final PendingNotificationSendQueue _sendQueue;

  FirestoreCircleRepository(this._sendQueue)
      : _db = FirebaseFirestore.instance,
        _auth = FirebaseAuth.instance,
        _fn = FirebaseFunctions.instanceFor(region: 'us-central1');

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    return user.uid;
  }

  // ── Collection / document references ─────────────────────────────────────

  CollectionReference get _circles => _db.collection('circles');

  CollectionReference _members(String circleId) =>
      _circles.doc(circleId).collection('members');

  CollectionReference _gratitudes(String circleId) =>
      _circles.doc(circleId).collection('gratitudes');

  CollectionReference _heatmapEntries(String circleId) =>
      _circles.doc(circleId).collection('heatmapEntries');

  CollectionReference _milestones(String circleId) =>
      _circles.doc(circleId).collection('milestones');

  DocumentReference _meta(String circleId) =>
      _circles.doc(circleId).collection('meta').doc('totals');

  DocumentReference _seenDoc(String circleId) =>
      _circles.doc(circleId).collection('userSeenGratitude').doc(_uid);

  // Feature sub-collections
  CollectionReference _prayerRequests(String circleId) =>
      _circles.doc(circleId).collection('prayer_requests');

  CollectionReference _milestoneShares(String circleId) =>
      _circles.doc(circleId).collection('milestone_shares');

  CollectionReference _weeklyPulse(String circleId) =>
      _circles.doc(circleId).collection('weekly_pulse');

  CollectionReference _pulseResponses(String circleId, String weekId) =>
      _weeklyPulse(circleId).doc(weekId).collection('responses');

  CollectionReference _events(String circleId) =>
      _circles.doc(circleId).collection('events');

  DocumentReference _groupPrayerListMeta(String circleId) =>
      _circles.doc(circleId).collection('group_prayer_list').doc('meta');

  CollectionReference _groupPrayerItems(String circleId) =>
      _circles.doc(circleId).collection('group_prayer_items');

  // ── Callable helper ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    final result = await _fn
        .httpsCallable(name)
        .call<Map<Object?, Object?>>(data);
    return Map<String, dynamic>.from(result.data);
  }

  // ── Cache-fallback helpers ────────────────────────────────────────────────

  /// Fetch a document server-first; retries from local cache on network errors.
  ///
  /// Only `unavailable` and `deadline-exceeded` trigger the cache retry.
  /// Other codes (e.g. `permission-denied`, `unauthenticated`) are rethrown
  /// so security failures are never silently masked by stale cached data.
  Future<DocumentSnapshot<T>> _getWithFallback<T>(
      DocumentReference<T> ref) async {
    try {
      return await ref.get();
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable' && e.code != 'deadline-exceeded') rethrow;
      return await ref.get(const GetOptions(source: Source.cache));
    }
  }

  /// Fetch a query server-first; retries from local cache on network errors.
  ///
  /// Only `unavailable` and `deadline-exceeded` trigger the cache retry.
  /// Other codes (e.g. `permission-denied`, `unauthenticated`) are rethrown
  /// so security failures are never silently masked by stale cached data.
  Future<QuerySnapshot<T>> _queryWithFallback<T>(Query<T> query) async {
    try {
      return await query.get();
    } on FirebaseException catch (e) {
      if (e.code != 'unavailable' && e.code != 'deadline-exceeded') rethrow;
      return await query.get(const GetOptions(source: Source.cache));
    }
  }

  // ── Existing: listCircles ─────────────────────────────────────────────────

  @override
  Future<List<Circle>> listCircles() async {
    final uid = _uid;
    final memberSnaps = await _queryWithFallback(_db
        .collectionGroup('members')
        .where('userId', isEqualTo: uid));
    if (memberSnaps.docs.isEmpty) return [];

    final circleIds =
        memberSnaps.docs.map((d) => d.reference.parent.parent!.id).toList();
    final circleSnaps =
        await Future.wait(circleIds.map((id) => _getWithFallback(_circles.doc(id))));

    return circleSnaps.where((s) => s.exists).map((s) {
      final data = s.data()! as Map<String, dynamic>;
      final membership = memberSnaps.docs
          .firstWhere((m) => m.reference.parent.parent!.id == s.id)
          .data();
      return Circle(
        id: s.id,
        name: data['name'] as String? ?? '',
        description: data['description'] as String? ?? '',
        memberCount: data['memberCount'] as int? ?? 0,
        role: membership['role'] as String? ?? 'member',
        inviteCode: data['inviteCode'] as String? ?? '',
      );
    }).toList();
  }

  // ── Existing: getCircleDetail ─────────────────────────────────────────────

  @override
  Future<CircleDetails> getCircleDetail(String circleId) async {
    final results = await Future.wait([
      _getWithFallback(_circles.doc(circleId)),
      _queryWithFallback(_members(circleId)),
    ]);
    final snap = results[0] as DocumentSnapshot;
    final membersSnap = results[1] as QuerySnapshot;
    if (!snap.exists) throw Exception('Circle not found');
    final data = snap.data()! as Map<String, dynamic>;
    return CircleDetails(
      id: snap.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      memberCount: data['memberCount'] as int? ?? 0,
      inviteCode: data['inviteCode'] as String? ?? '',
      createdAt: _tsToIso(data['createdAt']),
      members: membersSnap.docs.map((m) {
        final md = m.data() as Map<String, dynamic>;
        return CircleMember(
          userId: md['userId'] as String? ?? '',
          role: md['role'] as String? ?? 'member',
          joinedAt: _tsToIso(md['joinedAt']),
          displayName: md['displayName'] as String? ?? 'Circle Member',
        );
      }).toList(),
    );
  }

  // ── Existing: getGratitudeWall ────────────────────────────────────────────

  @override
  Future<GratitudeWall> getGratitudeWall(String circleId,
      {int weeksBack = 0}) async {
    final uid = _uid;
    final now = DateTime.now();
    final lowerBound = now.subtract(Duration(days: (weeksBack + 1) * 7));
    final upperBound = now.subtract(Duration(days: weeksBack * 7));
    final Query<Object?> query = _gratitudes(circleId)
        .where('sharedAt', isGreaterThan: Timestamp.fromDate(lowerBound))
        .where('sharedAt', isLessThanOrEqualTo: Timestamp.fromDate(upperBound))
        .orderBy('sharedAt', descending: true);
    final snap = await _queryWithFallback(query);
    final posts = snap.docs
        .map((d) => d.data() as Map<String, dynamic>)
        .where((d) => d['deleted'] != true)
        .map((d) => GratitudePost(
              id: d['id'] as String? ?? '',
              gratitudeText: d['gratitudeText'] as String? ?? '',
              isAnonymous: d['isAnonymous'] as bool? ?? false,
              displayName: d['displayName'] as String?,
              sharedAt: _tsToIso(d['sharedAt']),
              isMine: d['userId'] == uid,
            ))
        .toList();
    return GratitudeWall(
        circleId: circleId, weeksBack: weeksBack, gratitudes: posts);
  }

  @override
  Future<int> getGratitudeNewCount(String circleId) async {
    final seenSnap = await _getWithFallback(_seenDoc(circleId));
    final lastSeenAt = seenSnap.exists
        ? ((seenSnap.data() as Map<String, dynamic>?)?['lastSeenAt']
            as Timestamp?)
        : null;

    // Always bound to 30 days to avoid a full collection scan when the user
    // has never opened the gratitude tab (lastSeenAt == null).
    final thirtyDaysAgo = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 30)));
    final Query query = lastSeenAt != null
        ? _gratitudes(circleId).where('sharedAt', isGreaterThan: lastSeenAt)
        : _gratitudes(circleId).where('sharedAt', isGreaterThan: thirtyDaysAgo);

    final snap = await _queryWithFallback(query);
    return snap.docs
        .where((d) =>
            (d.data() as Map<String, dynamic>)['deleted'] != true)
        .length;
  }

  @override
  Future<int> getGratitudeWeekCount(String circleId) async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final snap = await _queryWithFallback(_gratitudes(circleId)
        .where('sharedAt', isGreaterThan: Timestamp.fromDate(weekAgo)));
    return snap.docs
        .where((d) =>
            (d.data() as Map<String, dynamic>)['deleted'] != true)
        .length;
  }

  @override
  Future<CircleHeatmap> getCircleHeatmap(String circleId,
      {int weekCount = 1}) async {
    final snap = await _queryWithFallback(_heatmapEntries(circleId));
    final totalMembers = snap.size == 0 ? 1 : snap.size;
    final cutoff = DateTime.now().subtract(Duration(days: weekCount * 7));
    final cutoffStr = WeekIdService.dateStr(cutoff);

    final strongCount = <String, int>{};
    final seenCount = <String, int>{};

    for (final doc in snap.docs) {
      final entry = doc.data() as Map<String, dynamic>;
      final weekData =
          (entry['weekData'] as List<dynamic>?) ?? <dynamic>[];
      for (final day in weekData) {
        final d = day as Map<String, dynamic>;
        final date = d['date'] as String? ?? '';
        if (date.compareTo(cutoffStr) < 0) continue;
        seenCount[date] = (seenCount[date] ?? 0) + 1;
        final score = (d['score'] as num?)?.toDouble() ?? 0.0;
        if (score >= 0.5) {
          strongCount[date] = (strongCount[date] ?? 0) + 1;
        }
      }
    }

    final days = seenCount.keys.toList()..sort();
    return CircleHeatmap(
      circleId: circleId,
      weekCount: weekCount,
      days: days
          .map((date) => HeatmapDay(
                date: date,
                intensity: (strongCount[date] ?? 0) / totalMembers,
              ))
          .toList(),
    );
  }

  @override
  Future<CollectiveMilestones> getCircleMilestones(String circleId) async {
    final results = await Future.wait([
      _getWithFallback(_meta(circleId)),
      _queryWithFallback(_milestones(circleId).orderBy('achievedAt', descending: false)),
    ]);
    final totalsSnap = results[0] as DocumentSnapshot;
    final milestonesSnap = results[1] as QuerySnapshot;
    final totals = totalsSnap.exists
        ? totalsSnap.data()! as Map<String, dynamic>
        : <String, dynamic>{};
    return CollectiveMilestones(
      circleId: circleId,
      totalGivingDays: (totals['totalGivingDays'] as int?) ?? 0,
      totalHours: ((totals['totalHours'] as num?) ?? 0).toDouble(),
      totalGratitudeDays: (totals['totalGratitudeDays'] as int?) ?? 0,
      milestones: milestonesSnap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return CollectiveMilestone(
          id: data['id'] as String? ?? d.id,
          title: data['title'] as String? ?? '',
          message: data['message'] as String? ?? '',
          achievedAt: _tsToIso(data['achievedAt']),
        );
      }).toList(),
    );
  }

  @override
  Future<CircleWeeklySummary> getSundaySummary(String circleId) async {
    final results = await Future.wait([
      _getWithFallback(_circles.doc(circleId)),
      _queryWithFallback(_heatmapEntries(circleId)),
    ]);
    final circleSnap = results[0] as DocumentSnapshot;
    final entrySnaps = results[1] as QuerySnapshot;

    final totalMembers = circleSnap.exists
        ? (circleSnap.data()! as Map<String, dynamic>)['memberCount'] as int? ??
            0
        : 0;

    var activeCount = 0;
    var totalScore = 0.0;
    for (final doc in entrySnaps.docs) {
      final entry = doc.data() as Map<String, dynamic>;
      final weekData =
          (entry['weekData'] as List<dynamic>?) ?? <dynamic>[];
      if (weekData.isNotEmpty) {
        activeCount++;
        final avg = weekData.fold<double>(
              0,
              (acc, d) =>
                  acc +
                  ((d as Map<String, dynamic>)['score'] as num? ?? 0)
                      .toDouble(),
            ) /
            weekData.length;
        totalScore += avg;
      }
    }

    return CircleWeeklySummary(
      circleId: circleId,
      weekOf: DateTime.now().toIso8601String(),
      totalMembers: totalMembers,
      activeMembers: activeCount,
      averageScore: activeCount > 0 ? totalScore / activeCount : 0,
      topMembers: [],
    );
  }

  @override
  Future<String> generateShareLink(String circleId) async {
    final snap = await _getWithFallback(_circles.doc(circleId));
    final inviteCode = snap.exists
        ? (snap.data()! as Map<String, dynamic>)['inviteCode'] as String? ?? ''
        : '';
    return 'https://graceway.faith/join?code=$inviteCode';
  }

  @override
  Future<void> markGratitudesSeen(String circleId) async {
    await _seenDoc(circleId)
        .set({'lastSeenAt': FieldValue.serverTimestamp()});
  }

  // ── Write operations (Callable Functions) ─────────────────────────────────

  @override
  Future<Circle> createCircle(String name,
      {String description = ''}) async {
    final data =
        await _call('circleCreate', {'name': name, 'description': description});
    return Circle(
      id: data['id'] as String,
      name: data['name'] as String,
      description: description,
      memberCount: 1,
      role: 'admin',
      inviteCode: data['inviteCode'] as String,
    );
  }

  @override
  Future<JoinCircleResult> joinCircle(String inviteCode) async {
    final data =
        await _call('circleJoin', {'inviteCode': inviteCode});
    return JoinCircleResult(
      id: data['id'] as String,
      name: data['name'] as String,
      alreadyMember: data['alreadyMember'] as bool? ?? false,
    );
  }

  @override
  Future<void> leaveCircle(String circleId) async {
    await _call('circleLeave', {'circleId': circleId});
  }

  @override
  Future<void> shareGratitude({
    required List<String> circleIds,
    required String gratitudeText,
    required bool isAnonymous,
    String? displayName,
  }) async {
    await _call('circleShareGratitude', {
      'circleIds': circleIds,
      'gratitudeText': gratitudeText,
      'isAnonymous': isAnonymous,
      'displayName': displayName,
    });
  }

  @override
  Future<void> deleteGratitude(String circleId, String gratitudeId) async {
    await _call('circleDeleteGratitude',
        {'circleId': circleId, 'gratitudeId': gratitudeId});
  }

  @override
  Future<void> submitHeatmapData(
      String circleId, List<Map<String, dynamic>> weekData) async {
    await _call('circleSubmitHeatmapData',
        {'circleId': circleId, 'weekData': weekData});
  }

  // ── Circle management ─────────────────────────────────────────────────────

  @override
  Future<void> updateCircle(String circleId, {String? name, String? description}) async {
    final payload = <String, dynamic>{'circleId': circleId};
    if (name != null) payload['name'] = name;
    if (description != null) payload['description'] = description;
    await _call('circleUpdate', payload);
  }

  @override
  Future<void> deleteCircle(String circleId) async {
    await _call('circleDelete', {'circleId': circleId});
  }

  // ── Circle Settings ───────────────────────────────────────────────────────

  @override
  Future<void> updateMemberRole(
      String circleId, String targetUserId, String role) async {
    await _call('circleUpdateMemberRole',
        {'circleId': circleId, 'targetUserId': targetUserId, 'role': role});
  }

  // ── Feature 1: Prayer List ────────────────────────────────────────────────

  @override
  Future<List<PrayerRequest>> getPrayerRequests(String circleId) async {
    final uid = _uid;
    final snap = await _queryWithFallback(_prayerRequests(circleId)
        .where('status', whereIn: ['ACTIVE', 'ANSWERED'])
        .orderBy('createdAt', descending: true));
    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return _parsePrayerRequest(d.id, data, uid);
    }).toList();
  }

  @override
  Future<void> createPrayerRequest({
    required String circleId,
    required String requestText,
    required PrayerDuration duration,
    bool anonymous = false,
  }) async {
    await _call('prayerRequestCreate', {
      'circleId': circleId,
      'requestText': requestText,
      'duration': _prayerDurationToString(duration),
      'anonymous': anonymous,
    });
  }

  @override
  Future<void> prayForRequest(String circleId, String requestId) async {
    await _call('prayerPrayFor',
        {'circleId': circleId, 'requestId': requestId});
  }

  @override
  Future<void> markPrayerAnswered(String circleId, String requestId,
      {String? answeredNote}) async {
    await _call('prayerRequestMarkAnswered', {
      'circleId': circleId,
      'requestId': requestId,
      'answeredNote': answeredNote,
    });
  }

  // ── Feature 4: Encouragements ─────────────────────────────────────────────

  @override
  Future<List<Encouragement>> getReceivedEncouragements(
      String circleId) async {
    final data = await _call('circleGetEncouragements',
        {'circleId': circleId, 'type': 'received'});
    final list = (data['encouragements'] as List<dynamic>?) ?? [];
    return list
        .map((e) => _parseEncouragement(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Encouragement>> getSentEncouragements(String circleId) async {
    final data = await _call('circleGetEncouragements',
        {'circleId': circleId, 'type': 'sent'});
    final list = (data['encouragements'] as List<dynamic>?) ?? [];
    return list
        .map((e) => _parseEncouragement(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> sendEncouragement({
    required String circleId,
    required String recipientId,
    required EncouragementMessageType messageType,
    String? presetKey,
    String? customText,
    required bool isAnonymous,
  }) =>
      _sendQueue.enqueue({
        'type': 'encouragement',
        'circleId': circleId,
        'recipientId': recipientId,
        'messageType':
            messageType == EncouragementMessageType.preset ? 'PRESET' : 'CUSTOM',
        'presetKey': presetKey,
        'customText': customText,
        'isAnonymous': isAnonymous,
      });

  @override
  Future<void> markEncouragementRead(
      String circleId, String encouragementId) async {
    await _call('circleMarkEncouragementRead',
        {'circleId': circleId, 'encouragementId': encouragementId});
  }

  // ── Feature 5: Milestone Shares ───────────────────────────────────────────

  @override
  Future<List<MilestoneShare>> getMilestoneShares(String circleId) async {
    final uid = _uid;
    final snap = await _queryWithFallback(_milestoneShares(circleId)
        .orderBy('createdAt', descending: true)
        .limit(20));
    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return _parseMilestoneShare(d.id, data, uid);
    }).toList();
  }

  @override
  Future<void> shareMilestone({
    required List<String> circleIds,
    required MilestoneShareType milestoneType,
    required int milestoneValue,
    required String habitName,
    required String userDisplayName,
  }) async {
    await _call('circleShareMilestone', {
      'circleIds': circleIds,
      'milestoneType': _milestoneShareTypeToString(milestoneType),
      'milestoneValue': milestoneValue,
      'habitName': habitName,
      'userDisplayName': userDisplayName,
    });
  }

  @override
  Future<void> celebrateMilestone(String circleId, String shareId) async {
    await _call('circleCelebrateMilestone',
        {'circleId': circleId, 'shareId': shareId});
  }

  // ── Feature 6: Weekly Pulse ───────────────────────────────────────────────

  @override
  Future<WeeklyPulse?> getCurrentWeeklyPulse(String circleId) async {
    final weekId = WeekIdService.currentWeekId();
    final snap = await _getWithFallback(_weeklyPulse(circleId).doc(weekId));
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>;
    return _parseWeeklyPulse(snap.id, data);
  }

  @override
  Future<PulseResponse?> getMyPulseResponse(
      String circleId, String weekId) async {
    final uid = _uid;
    final snap = await _getWithFallback(_pulseResponses(circleId, weekId).doc(uid));
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>;
    return _parsePulseResponse(snap.id, data);
  }

  @override
  Future<void> submitPulseResponse({
    required String circleId,
    required PulseStatus status,
    String? note,
    required bool isAnonymous,
  }) async {
    await _call('circleSubmitPulseResponse', {
      'circleId': circleId,
      'status': _pulseStatusToString(status),
      'note': note,
      'isAnonymous': isAnonymous,
    });
  }

  // ── Feature 7: Events ─────────────────────────────────────────────────────

  @override
  Future<List<CircleEvent>> getUpcomingEvents(String circleId) async {
    final now = DateTime.now();
    final snap = await _queryWithFallback(_events(circleId)
        .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('eventDate', descending: false)
        .limit(2));
    return snap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return _parseCircleEvent(d.id, data);
    }).toList();
  }

  @override
  Future<void> createEvent({
    required String circleId,
    required String title,
    required DateTime eventDate,
    String? description,
    String? location,
    String? meetingLink,
  }) async {
    await _call('circleCreateEvent', {
      'circleId': circleId,
      'title': title,
      'eventDate': eventDate.toIso8601String(),
      'description': description,
      'location': location,
      'meetingLink': meetingLink,
    });
  }

  @override
  Future<void> updateEvent({
    required String circleId,
    required String eventId,
    required String title,
    required DateTime eventDate,
    String? description,
    String? location,
    String? meetingLink,
  }) async {
    await _call('circleUpdateEvent', {
      'circleId': circleId,
      'eventId': eventId,
      'title': title,
      'eventDateMs': eventDate.millisecondsSinceEpoch,
      'description': description,
      'location': location,
      'meetingLink': meetingLink,
    });
  }

  @override
  Future<void> deleteEvent(String circleId, String eventId) async {
    await _call('circleDeleteEvent',
        {'circleId': circleId, 'eventId': eventId});
  }

  // ── Parse helpers ─────────────────────────────────────────────────────────

  static PrayerRequest _parsePrayerRequest(
      String id, Map<String, dynamic> d, String uid) {
    return PrayerRequest(
      id: id,
      circleId: d['circleId'] as String? ?? '',
      authorId: d['authorId'] as String? ?? '',
      authorDisplayName: d['authorDisplayName'] as String? ?? '',
      requestText: d['requestText'] as String? ?? '',
      duration: _parsePrayerDuration(d['duration'] as String?),
      status: _parsePrayerStatus(d['status'] as String?),
      answeredNote: d['answeredNote'] as String?,
      prayerCount: d['prayerCount'] as int? ?? 0,
      prayedByUserIds:
          List<String>.from((d['prayedByUserIds'] as List<dynamic>?) ?? []),
      createdAt: _tsToIso(d['createdAt']),
      answeredAt: d['answeredAt'] != null ? _tsToIso(d['answeredAt']) : null,
      expiresAt: d['expiresAt'] != null ? _tsToIso(d['expiresAt']) : null,
    );
  }

  static Encouragement _parseEncouragement(Map<String, dynamic> d) {
    return Encouragement(
      id: d['id'] as String? ?? '',
      circleId: d['circleId'] as String? ?? '',
      senderId: d['senderId'] as String?,
      senderDisplayName: d['senderDisplayName'] as String?,
      recipientId: d['recipientId'] as String? ?? '',
      messageType: (d['messageType'] as String?) == 'PRESET'
          ? EncouragementMessageType.preset
          : EncouragementMessageType.custom,
      presetKey: d['presetKey'] as String?,
      customText: d['customText'] as String?,
      isAnonymous: d['isAnonymous'] as bool? ?? false,
      isRead: d['isRead'] as bool? ?? false,
      createdAt: d['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  static MilestoneShare _parseMilestoneShare(
      String id, Map<String, dynamic> d, String uid) {
    return MilestoneShare(
      id: id,
      circleId: d['circleId'] as String? ?? '',
      userId: d['userId'] as String? ?? '',
      userDisplayName: d['userDisplayName'] as String? ?? '',
      milestoneType: _parseMilestoneShareType(d['milestoneType'] as String?),
      milestoneValue: d['milestoneValue'] as int? ?? 0,
      habitName: d['habitName'] as String? ?? '',
      celebrationCount: d['celebrationCount'] as int? ?? 0,
      celebratedByUserIds:
          List<String>.from((d['celebratedByUserIds'] as List<dynamic>?) ?? []),
      createdAt: _tsToIso(d['createdAt']),
    );
  }

  static WeeklyPulse _parseWeeklyPulse(String id, Map<String, dynamic> d) {
    final summaryRaw =
        (d['pulseSummary'] as Map<String, dynamic>?) ?? {};
    final summary = <PulseStatus, int>{};
    for (final status in PulseStatus.values) {
      final key = _pulseStatusToString(status);
      summary[status] = summaryRaw[key] as int? ?? 0;
    }
    return WeeklyPulse(
      id: id,
      circleId: d['circleId'] as String? ?? '',
      weekStartDate: _tsToIso(d['weekStartDate']),
      responseCount: d['responseCount'] as int? ?? 0,
      pulseSummary: summary,
      needsPrayerCount: d['needsPrayerCount'] as int? ?? 0,
    );
  }

  static PulseResponse _parsePulseResponse(
      String id, Map<String, dynamic> d) {
    return PulseResponse(
      id: id,
      userId: d['userId'] as String?,
      userDisplayName: d['userDisplayName'] as String?,
      status: _parsePulseStatus(d['status'] as String?),
      note: d['note'] as String?,
      isAnonymous: d['isAnonymous'] as bool? ?? false,
      createdAt: _tsToIso(d['createdAt']),
    );
  }

  static CircleEvent _parseCircleEvent(String id, Map<String, dynamic> d) {
    return CircleEvent(
      id: id,
      circleId: d['circleId'] as String? ?? '',
      createdById: d['createdById'] as String? ?? '',
      title: d['title'] as String? ?? '',
      description: d['description'] as String?,
      eventDate: _tsToIso(d['eventDate']),
      location: d['location'] as String?,
      meetingLink: d['meetingLink'] as String?,
      reminderSent: d['reminderSent'] as bool? ?? false,
      createdAt: _tsToIso(d['createdAt']),
    );
  }

  // ── Enum converters ───────────────────────────────────────────────────────

  static String _prayerDurationToString(PrayerDuration d) {
    switch (d) {
      case PrayerDuration.thisWeek:
        return 'THIS_WEEK';
      case PrayerDuration.ongoing:
        return 'ONGOING';
      case PrayerDuration.untilRemoved:
        return 'UNTIL_REMOVED';
    }
  }

  static PrayerDuration _parsePrayerDuration(String? s) {
    switch (s) {
      case 'THIS_WEEK':
        return PrayerDuration.thisWeek;
      case 'UNTIL_REMOVED':
        return PrayerDuration.untilRemoved;
      default:
        return PrayerDuration.ongoing;
    }
  }

  static PrayerRequestStatus _parsePrayerStatus(String? s) {
    switch (s) {
      case 'ANSWERED':
        return PrayerRequestStatus.answered;
      case 'EXPIRED':
        return PrayerRequestStatus.expired;
      default:
        return PrayerRequestStatus.active;
    }
  }

  static MilestoneShareType _parseMilestoneShareType(String? s) {
    switch (s) {
      case 'TIME':
        return MilestoneShareType.time;
      case 'COUNT':
        return MilestoneShareType.count;
      case 'CONSECUTIVE':
        return MilestoneShareType.consecutive;
      default:
        return MilestoneShareType.days;
    }
  }

  static String _milestoneShareTypeToString(MilestoneShareType t) {
    switch (t) {
      case MilestoneShareType.time:
        return 'TIME';
      case MilestoneShareType.count:
        return 'COUNT';
      case MilestoneShareType.consecutive:
        return 'CONSECUTIVE';
      case MilestoneShareType.days:
        return 'DAYS';
    }
  }

  static String _pulseStatusToString(PulseStatus s) {
    switch (s) {
      case PulseStatus.encouraged:
        return 'ENCOURAGED';
      case PulseStatus.steady:
        return 'STEADY';
      case PulseStatus.struggling:
        return 'STRUGGLING';
      case PulseStatus.needsPrayer:
        return 'NEEDS_PRAYER';
    }
  }

  static PulseStatus _parsePulseStatus(String? s) {
    switch (s) {
      case 'STEADY':
        return PulseStatus.steady;
      case 'STRUGGLING':
        return PulseStatus.struggling;
      case 'NEEDS_PRAYER':
        return PulseStatus.needsPrayer;
      default:
        return PulseStatus.encouraged;
    }
  }

  // ── Group Prayer List ─────────────────────────────────────────────────────

  @override
  Future<CirclePrayerList?> getGroupPrayerList(String circleId) async {
    final uid = _uid;
    final metaSnap = await _getWithFallback(_groupPrayerListMeta(circleId));
    if (!metaSnap.exists) return null;
    final meta = metaSnap.data() as Map<String, dynamic>;
    final visibleIds =
        ((meta['visibleToMemberIds'] as List<dynamic>?) ?? []).cast<String>();
    final isAdmin = await _isAdmin(circleId, uid);
    if (!isAdmin && !visibleIds.contains(uid)) {
      return CirclePrayerList(
        circleId: circleId,
        createdBy: meta['createdBy'] as String?,
        createdAt: _tsToIso(meta['createdAt']),
        visibleToMemberIds: visibleIds,
        items: const [],
      );
    }
    final itemsSnap =
        await _queryWithFallback(_groupPrayerItems(circleId).orderBy('order'));
    final items = itemsSnap.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return CirclePrayerItem(
        id: d.id,
        text: data['text'] as String? ?? '',
        status: PrayerItemStatus.fromString(data['status'] as String? ?? ''),
        memo: data['memo'] as String?,
        createdAt: _tsToIso(data['createdAt']),
        answeredAt: data['answeredAt'] != null
            ? _tsToIso(data['answeredAt'])
            : null,
        order: (data['order'] as num?)?.toInt() ?? 0,
      );
    }).toList();
    return CirclePrayerList(
      circleId: circleId,
      createdBy: meta['createdBy'] as String?,
      createdAt: _tsToIso(meta['createdAt']),
      visibleToMemberIds: visibleIds,
      items: items,
    );
  }

  @override
  Future<void> saveGroupPrayerList(CirclePrayerList list) async {
    final data = <String, dynamic>{
      'createdBy': list.createdBy ?? _uid,
      'visibleToMemberIds': list.visibleToMemberIds,
    };
    // Only stamp createdAt on initial creation; preserve the original on updates.
    if (list.createdAt == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    await _groupPrayerListMeta(list.circleId).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> upsertGroupPrayerItem(
      String circleId, CirclePrayerItem item) async {
    await _groupPrayerItems(circleId).doc(item.id).set({
      'text': item.text,
      'status': item.status.rawValue,
      'memo': item.memo,
      'createdAt': item.createdAt,
      'answeredAt': item.answeredAt,
      'order': item.order,
    });
  }

  @override
  Future<void> deleteGroupPrayerItem(String circleId, String itemId) async {
    await _groupPrayerItems(circleId).doc(itemId).delete();
  }

  /// Returns true if [uid] is an admin of [circleId].
  ///
  /// Uses [_getWithFallback], so when offline a cached member document is used.
  /// This means a role change (admin → member) is not reflected until the
  /// device reconnects. This is an accepted trade-off for offline-first access:
  /// a demoted admin can view the group prayer list from cache but cannot make
  /// privileged writes (those go through callable functions which enforce roles
  /// server-side). [_getWithFallback] will rethrow `permission-denied` when
  /// online, so the stale-role window is limited to genuine offline sessions.
  Future<bool> _isAdmin(String circleId, String uid) async {
    final snap = await _getWithFallback(_members(circleId).doc(uid));
    if (!snap.exists) return false;
    final data = snap.data() as Map<String, dynamic>;
    return (data['role'] as String?) == 'admin';
  }

  // ── Timestamp helper ──────────────────────────────────────────────────────

  static String _tsToIso(dynamic ts) {
    if (ts is Timestamp) return ts.toDate().toIso8601String();
    // Client-written items store an ISO string directly.
    if (ts is String && ts.isNotEmpty) return ts;
    // Missing/malformed — return epoch so downstream sorts are stable.
    return DateTime.utc(2000).toIso8601String();
  }
}
