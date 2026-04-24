/// Circle domain entities — pure Dart, no JSON or platform imports.
/// All JSON parsing lives in the data layer (FirestoreCircleRepository).
library;

import 'package:uuid/uuid.dart';
import 'habit.dart' show PrayerItemStatus;

// ── Core circle types ─────────────────────────────────────────────────────────

class Circle {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final String role;
  final String inviteCode;

  const Circle({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.role,
    required this.inviteCode,
  });

  bool get isAdmin => role == 'admin';
}

class CircleMember {
  final String userId;
  final String role;
  final String joinedAt;
  final String displayName;

  const CircleMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.displayName = 'Circle Member',
  });

  bool get isAdmin => role == 'admin';
}

class CircleDetails {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final String inviteCode;
  final String createdAt;
  final List<CircleMember> members;

  const CircleDetails({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.inviteCode,
    required this.createdAt,
    required this.members,
  });
}

class JoinCircleResult {
  final String id;
  final String name;
  final bool alreadyMember;

  const JoinCircleResult({
    required this.id,
    required this.name,
    required this.alreadyMember,
  });
}


class GratitudePost {
  final String id;
  final String gratitudeText;
  final bool isAnonymous;
  final String? displayName;
  final String sharedAt;
  final bool isMine;

  const GratitudePost({
    required this.id,
    required this.gratitudeText,
    required this.isAnonymous,
    this.displayName,
    required this.sharedAt,
    required this.isMine,
  });
}

class GratitudeWall {
  final String circleId;
  final int weeksBack;
  final List<GratitudePost> gratitudes;

  const GratitudeWall({
    required this.circleId,
    required this.weeksBack,
    required this.gratitudes,
  });
}

class CircleWeeklyTopMember {
  final String userId;
  final int streak;

  const CircleWeeklyTopMember({required this.userId, required this.streak});
}

class CircleWeeklySummary {
  final String circleId;
  final String weekOf;
  final int totalMembers;
  final int activeMembers;
  final double averageScore;
  final List<CircleWeeklyTopMember> topMembers;

  const CircleWeeklySummary({
    required this.circleId,
    required this.weekOf,
    required this.totalMembers,
    required this.activeMembers,
    required this.averageScore,
    required this.topMembers,
  });
}

class HeatmapDay {
  final String date;
  final double intensity;

  const HeatmapDay({required this.date, required this.intensity});
}

class CircleHeatmap {
  final String circleId;
  final int weekCount;
  final List<HeatmapDay> days;

  const CircleHeatmap({
    required this.circleId,
    required this.weekCount,
    required this.days,
  });
}

class CollectiveMilestone {
  final String id;
  final String title;
  final String message;
  final String achievedAt;

  const CollectiveMilestone({
    required this.id,
    required this.title,
    required this.message,
    required this.achievedAt,
  });
}

class CollectiveMilestones {
  final String circleId;
  final int totalGivingDays;
  final double totalHours;
  final int totalGratitudeDays;
  final List<CollectiveMilestone> milestones;

  const CollectiveMilestones({
    required this.circleId,
    required this.totalGivingDays,
    required this.totalHours,
    required this.totalGratitudeDays,
    required this.milestones,
  });
}

// ── Feature 1: Prayer List ─────────────────────────────────────────────────────

enum PrayerDuration { thisWeek, ongoing, untilRemoved }
enum PrayerRequestStatus { active, answered, expired }

class PrayerRequest {
  final String id;
  final String circleId;
  final String authorId;
  final String authorDisplayName;
  final String requestText;
  final PrayerDuration duration;
  final PrayerRequestStatus status;
  final String? answeredNote;
  final int prayerCount;
  final List<String> prayedByUserIds;
  final String createdAt;
  final String? answeredAt;
  final String? expiresAt;

  const PrayerRequest({
    required this.id,
    required this.circleId,
    required this.authorId,
    required this.authorDisplayName,
    required this.requestText,
    required this.duration,
    required this.status,
    this.answeredNote,
    required this.prayerCount,
    required this.prayedByUserIds,
    required this.createdAt,
    this.answeredAt,
    this.expiresAt,
  });

  bool hasPrayed(String uid) => prayedByUserIds.contains(uid);
  bool isAuthor(String uid) => authorId == uid;
}

// ── Feature 4: Encouragements ─────────────────────────────────────────────────

enum EncouragementMessageType { preset, custom }

class Encouragement {
  final String id;
  final String circleId;
  final String? senderId; // null when anonymous (masked server-side)
  final String? senderDisplayName; // null when anonymous
  final String recipientId;
  final EncouragementMessageType messageType;
  final String? presetKey;
  final String? customText;
  final bool isAnonymous;
  final bool isRead;
  final String createdAt;

  const Encouragement({
    required this.id,
    required this.circleId,
    this.senderId,
    this.senderDisplayName,
    required this.recipientId,
    required this.messageType,
    this.presetKey,
    this.customText,
    required this.isAnonymous,
    required this.isRead,
    required this.createdAt,
  });

  String get displayMessage {
    if (messageType == EncouragementMessageType.preset &&
        presetKey != null &&
        _presets.containsKey(presetKey)) {
      return _presets[presetKey]!;
    }
    return customText ?? '';
  }

  static const Map<String, String> _presets = {
    'PRAYING': 'Praying for you today.',
    'KEEP_GOING': "Keep going \u2014 you're doing great.",
    'GOD_SEES': 'God sees your faithfulness.',
    'PROUD': 'Proud of you.',
    'NOT_ALONE': "You're not walking alone.",
    'STRENGTH': 'Praying God gives you strength today.',
    'THINKING': "Just wanted you to know I'm thinking of you.",
    'GRATEFUL': 'Grateful to be in community with you.',
  };

  static List<MapEntry<String, String>> get presetEntries =>
      _presets.entries.toList();
}

// ── Feature 5: Milestone Shares ───────────────────────────────────────────────

enum MilestoneShareType { time, count, days, consecutive }

class MilestoneShare {
  final String id;
  final String circleId;
  final String userId;
  final String userDisplayName;
  final MilestoneShareType milestoneType;
  final int milestoneValue;
  final String habitName;
  final int celebrationCount;
  final List<String> celebratedByUserIds;
  final String createdAt;

  const MilestoneShare({
    required this.id,
    required this.circleId,
    required this.userId,
    required this.userDisplayName,
    required this.milestoneType,
    required this.milestoneValue,
    required this.habitName,
    required this.celebrationCount,
    required this.celebratedByUserIds,
    required this.createdAt,
  });

  bool hasCelebrated(String uid) => celebratedByUserIds.contains(uid);
  bool isAuthor(String uid) => userId == uid;

  String get displayLabel {
    switch (milestoneType) {
      case MilestoneShareType.time:
        return '$milestoneValue ${milestoneValue == 1 ? 'hour' : 'hours'} of $habitName';
      case MilestoneShareType.count:
        return '$milestoneValue completions of $habitName';
      case MilestoneShareType.days:
        return '$milestoneValue days of $habitName';
      case MilestoneShareType.consecutive:
        return '$milestoneValue consecutive days of $habitName';
    }
  }
}

// ── Feature 6: Weekly Pulse ───────────────────────────────────────────────────

enum PulseStatus { encouraged, steady, struggling, needsPrayer }

class WeeklyPulse {
  final String id; // YYYY-WW
  final String circleId;
  final String weekStartDate;
  final int responseCount;
  final Map<PulseStatus, int> pulseSummary;
  final int needsPrayerCount;
  final List<PulseResponse> responses;

  const WeeklyPulse({
    required this.id,
    required this.circleId,
    required this.weekStartDate,
    required this.responseCount,
    required this.pulseSummary,
    required this.needsPrayerCount,
    this.responses = const [],
  });

  int countFor(PulseStatus status) => pulseSummary[status] ?? 0;
}

class PulseResponse {
  final String id; // userId
  final String? userId; // null when anonymous (masked server-side)
  final String? userDisplayName;
  final PulseStatus status;
  final String? note;
  final bool isAnonymous;
  final String createdAt;

  const PulseResponse({
    required this.id,
    this.userId,
    this.userDisplayName,
    required this.status,
    this.note,
    required this.isAnonymous,
    required this.createdAt,
  });
}


// ── Feature 7: Events ─────────────────────────────────────────────────────────

class CircleEvent {
  final String id;
  final String circleId;
  final String createdById;
  final String title;
  final String? description;
  final String eventDate; // ISO string
  final String? location;
  final String? meetingLink;
  final bool reminderSent;
  final String createdAt;

  const CircleEvent({
    required this.id,
    required this.circleId,
    required this.createdById,
    required this.title,
    this.description,
    required this.eventDate,
    this.location,
    this.meetingLink,
    required this.reminderSent,
    required this.createdAt,
  });

  bool isAuthor(String uid) => createdById == uid;

  DateTime get eventDateTime => DateTime.parse(eventDate);

  bool get isUpcoming => eventDateTime.isAfter(DateTime.now());
}

// ── Group Prayer List ─────────────────────────────────────────────────────────

class CirclePrayerItem {
  final String id;
  final String text;
  final PrayerItemStatus status;
  final String? memo;
  final String createdAt;
  final String? answeredAt;
  final int order;

  const CirclePrayerItem({
    required this.id,
    required this.text,
    required this.status,
    this.memo,
    required this.createdAt,
    this.answeredAt,
    required this.order,
  });

  factory CirclePrayerItem.create(String text, int order) => CirclePrayerItem(
        id: const Uuid().v4(),
        text: text,
        status: PrayerItemStatus.praying,
        createdAt: DateTime.now().toIso8601String(),
        order: order,
      );

  // Sentinel so callers can explicitly pass null to clear memo or answeredAt.
  static const Object _keep = Object();

  CirclePrayerItem copyWith({
    String? text,
    PrayerItemStatus? status,
    Object? memo = _keep,
    Object? answeredAt = _keep,
  }) =>
      CirclePrayerItem(
        id: id,
        text: text ?? this.text,
        status: status ?? this.status,
        memo: identical(memo, _keep) ? this.memo : memo as String?,
        createdAt: createdAt,
        answeredAt:
            identical(answeredAt, _keep) ? this.answeredAt : answeredAt as String?,
        order: order,
      );
}

class CirclePrayerList {
  final String circleId;
  final String? createdBy;
  final String? createdAt;
  final List<String> visibleToMemberIds;
  final List<CirclePrayerItem> items;

  const CirclePrayerList({
    required this.circleId,
    this.createdBy,
    this.createdAt,
    this.visibleToMemberIds = const [],
    this.items = const [],
  });

  bool canView(String uid, {required bool isAdmin}) =>
      isAdmin || visibleToMemberIds.contains(uid);

  List<CirclePrayerItem> get activeItems => items
      .where((i) => i.status != PrayerItemStatus.answered)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));

  List<CirclePrayerItem> get answeredItems => items
      .where((i) => i.status == PrayerItemStatus.answered)
      .toList()
    ..sort((a, b) => (b.answeredAt ?? '').compareTo(a.answeredAt ?? ''));
}
