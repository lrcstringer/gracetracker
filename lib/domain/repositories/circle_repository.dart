import '../entities/circle.dart';

abstract class CircleRepository {
  // ── Existing methods ────────────────────────────────────────────────────────
  Future<List<Circle>> listCircles();
  Future<CircleDetails> getCircleDetail(String circleId);
  Future<Circle> createCircle(String name, {String description});
  Future<JoinCircleResult> joinCircle(String inviteCode);
  Future<void> leaveCircle(String circleId);
  Future<String> generateShareLink(String circleId);
  Future<CircleWeeklySummary> getSundaySummary(String circleId);
  Future<GratitudeWall> getGratitudeWall(String circleId, {int weeksBack});
  Future<void> shareGratitude({
    required List<String> circleIds,
    required String gratitudeText,
    required bool isAnonymous,
    String? displayName,
  });
  Future<void> deleteGratitude(String circleId, String gratitudeId);
  Future<int> getGratitudeNewCount(String circleId);
  Future<void> markGratitudesSeen(String circleId);
  Future<int> getGratitudeWeekCount(String circleId);
  Future<CircleHeatmap> getCircleHeatmap(String circleId, {int weekCount});
  Future<CollectiveMilestones> getCircleMilestones(String circleId);
  Future<void> submitHeatmapData(String circleId, List<Map<String, dynamic>> weekData);

  // ── Circle management ───────────────────────────────────────────────────────
  Future<void> updateCircle(String circleId, {String? name, String? description});
  Future<void> deleteCircle(String circleId);

  // ── Member management ───────────────────────────────────────────────────────
  Future<void> updateMemberRole(String circleId, String targetUserId, String role);

  // ── Feature 1: Prayer List ──────────────────────────────────────────────────
  Future<List<PrayerRequest>> getPrayerRequests(String circleId);
  Future<void> createPrayerRequest({
    required String circleId,
    required String requestText,
    required PrayerDuration duration,
    bool anonymous = false,
    List<String>? recipientIds, // null = all members
  });
  Future<void> prayForRequest(String circleId, String requestId);
  Future<void> markPrayerAnswered(
    String circleId,
    String requestId, {
    String? answeredNote,
  });

  // ── Feature 4: Encouragements ───────────────────────────────────────────────
  Future<List<Encouragement>> getReceivedEncouragements(String circleId);
  Future<List<Encouragement>> getSentEncouragements(String circleId);
  Future<void> sendEncouragement({
    required String circleId,
    required String recipientId,
    required EncouragementMessageType messageType,
    String? presetKey,
    String? customText,
    required bool isAnonymous,
  });
  Future<void> markEncouragementRead(String circleId, String encouragementId);

  // ── Feature 5: Milestone Shares ─────────────────────────────────────────────
  Future<List<MilestoneShare>> getMilestoneShares(String circleId);
  Future<void> shareMilestone({
    required List<String> circleIds,
    required MilestoneShareType milestoneType,
    required int milestoneValue,
    required String habitName,
    required String userDisplayName,
  });
  Future<void> celebrateMilestone(String circleId, String shareId);

  // ── Feature 6: Weekly Pulse ─────────────────────────────────────────────────
  Future<WeeklyPulse?> getCurrentWeeklyPulse(String circleId);
  Future<PulseResponse?> getMyPulseResponse(String circleId, String weekId);
  Future<void> submitPulseResponse({
    required String circleId,
    required PulseStatus status,
    String? note,
    required bool isAnonymous,
  });

  // ── Group Prayer List ───────────────────────────────────────────────────────
  Future<CirclePrayerList?> getGroupPrayerList(String circleId);
  Future<void> saveGroupPrayerList(CirclePrayerList list);
  Future<void> upsertGroupPrayerItem(String circleId, CirclePrayerItem item);
  Future<void> deleteGroupPrayerItem(String circleId, String itemId);

  // ── Feature 7: Events ───────────────────────────────────────────────────────
  Future<List<CircleEvent>> getUpcomingEvents(String circleId);
  Future<void> createEvent({
    required String circleId,
    required String title,
    required DateTime eventDate,
    String? description,
    String? location,
    String? meetingLink,
  });
  Future<void> updateEvent({
    required String circleId,
    required String eventId,
    required String title,
    required DateTime eventDate,
    String? description,
    String? location,
    String? meetingLink,
  });
  Future<void> deleteEvent(String circleId, String eventId);
}
