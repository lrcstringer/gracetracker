import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// Response models

class AuthResponse {
  final String userId;
  final String? displayName;
  final bool isNewUser;
  AuthResponse({required this.userId, this.displayName, required this.isNewUser});
  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
    userId: j['userId'] as String,
    displayName: j['displayName'] as String?,
    isNewUser: j['isNewUser'] as bool? ?? false,
  );
}

class CircleResponse {
  final String id;
  final String name;
  final String inviteCode;
  CircleResponse({required this.id, required this.name, required this.inviteCode});
  factory CircleResponse.fromJson(Map<String, dynamic> j) => CircleResponse(
    id: j['id'] as String, name: j['name'] as String, inviteCode: j['inviteCode'] as String,
  );
}

class CircleListItem {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final String role;
  final String inviteCode;
  CircleListItem({required this.id, required this.name, required this.description, required this.memberCount, required this.role, required this.inviteCode});
  factory CircleListItem.fromJson(Map<String, dynamic> j) => CircleListItem(
    id: j['id'] as String, name: j['name'] as String, description: j['description'] as String? ?? '',
    memberCount: j['memberCount'] as int? ?? 0, role: j['role'] as String? ?? 'member',
    inviteCode: j['inviteCode'] as String? ?? '',
  );
}

class CircleDetail {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final String inviteCode;
  final String createdAt;
  final List<CircleMemberInfo> members;
  CircleDetail({required this.id, required this.name, required this.description, required this.memberCount, required this.inviteCode, required this.createdAt, required this.members});
  factory CircleDetail.fromJson(Map<String, dynamic> j) => CircleDetail(
    id: j['id'] as String, name: j['name'] as String, description: j['description'] as String? ?? '',
    memberCount: j['memberCount'] as int? ?? 0, inviteCode: j['inviteCode'] as String? ?? '',
    createdAt: j['createdAt'] as String? ?? '',
    members: (j['members'] as List<dynamic>? ?? []).map((m) => CircleMemberInfo.fromJson(m as Map<String, dynamic>)).toList(),
  );
}

class CircleMemberInfo {
  final String userId;
  final String role;
  final String joinedAt;
  CircleMemberInfo({required this.userId, required this.role, required this.joinedAt});
  factory CircleMemberInfo.fromJson(Map<String, dynamic> j) => CircleMemberInfo(
    userId: j['userId'] as String, role: j['role'] as String? ?? 'member', joinedAt: j['joinedAt'] as String? ?? '',
  );
}

class JoinCircleResponse {
  final String id;
  final String name;
  final bool alreadyMember;
  JoinCircleResponse({required this.id, required this.name, required this.alreadyMember});
  factory JoinCircleResponse.fromJson(Map<String, dynamic> j) => JoinCircleResponse(
    id: j['id'] as String, name: j['name'] as String, alreadyMember: j['alreadyMember'] as bool? ?? false,
  );
}

class ShareLinkResponse {
  final String shareUrl;
  final String inviteCode;
  ShareLinkResponse({required this.shareUrl, required this.inviteCode});
  factory ShareLinkResponse.fromJson(Map<String, dynamic> j) => ShareLinkResponse(
    shareUrl: j['shareUrl'] as String, inviteCode: j['inviteCode'] as String,
  );
}

class SundaySummaryResponse {
  final String circleId;
  final String weekOf;
  final int totalMembers;
  final int activeMembers;
  final double averageScore;
  final List<TopStreak> topStreaks;
  SundaySummaryResponse({required this.circleId, required this.weekOf, required this.totalMembers, required this.activeMembers, required this.averageScore, required this.topStreaks});
  factory SundaySummaryResponse.fromJson(Map<String, dynamic> j) => SundaySummaryResponse(
    circleId: j['circleId'] as String, weekOf: j['weekOf'] as String,
    totalMembers: j['totalMembers'] as int? ?? 0, activeMembers: j['activeMembers'] as int? ?? 0,
    averageScore: (j['averageScore'] as num?)?.toDouble() ?? 0,
    topStreaks: (j['topStreaks'] as List<dynamic>? ?? []).map((s) => TopStreak.fromJson(s as Map<String, dynamic>)).toList(),
  );
}

class TopStreak {
  final String userId;
  final int streak;
  TopStreak({required this.userId, required this.streak});
  factory TopStreak.fromJson(Map<String, dynamic> j) => TopStreak(userId: j['userId'] as String, streak: j['streak'] as int? ?? 0);
}

class SharedGratitudeItem {
  final String id;
  final String gratitudeText;
  final bool isAnonymous;
  final String? displayName;
  final String sharedAt;
  final bool isMine;
  SharedGratitudeItem({required this.id, required this.gratitudeText, required this.isAnonymous, this.displayName, required this.sharedAt, required this.isMine});
  factory SharedGratitudeItem.fromJson(Map<String, dynamic> j) => SharedGratitudeItem(
    id: j['id'] as String, gratitudeText: j['gratitudeText'] as String,
    isAnonymous: j['isAnonymous'] as bool? ?? false, displayName: j['displayName'] as String?,
    sharedAt: j['sharedAt'] as String, isMine: j['isMine'] as bool? ?? false,
  );
}

class GratitudeWallResponse {
  final String circleId;
  final int weeksBack;
  final List<SharedGratitudeItem> gratitudes;
  GratitudeWallResponse({required this.circleId, required this.weeksBack, required this.gratitudes});
  factory GratitudeWallResponse.fromJson(Map<String, dynamic> j) => GratitudeWallResponse(
    circleId: j['circleId'] as String, weeksBack: j['weeksBack'] as int? ?? 0,
    gratitudes: (j['gratitudes'] as List<dynamic>? ?? []).map((g) => SharedGratitudeItem.fromJson(g as Map<String, dynamic>)).toList(),
  );
}

class GratitudeNewCountResponse {
  final String circleId;
  final int newCount;
  GratitudeNewCountResponse({required this.circleId, required this.newCount});
  factory GratitudeNewCountResponse.fromJson(Map<String, dynamic> j) => GratitudeNewCountResponse(
    circleId: j['circleId'] as String, newCount: j['newCount'] as int? ?? 0,
  );
}

class GratitudeWeekCountResponse {
  final String circleId;
  final int weekCount;
  GratitudeWeekCountResponse({required this.circleId, required this.weekCount});
  factory GratitudeWeekCountResponse.fromJson(Map<String, dynamic> j) => GratitudeWeekCountResponse(
    circleId: j['circleId'] as String, weekCount: j['weekCount'] as int? ?? 0,
  );
}

class CircleHeatmapDay {
  final String date;
  final double intensity;
  CircleHeatmapDay({required this.date, required this.intensity});
  factory CircleHeatmapDay.fromJson(Map<String, dynamic> j) => CircleHeatmapDay(
    date: j['date'] as String,
    intensity: (j['intensity'] as num?)?.toDouble() ?? 0.0,
  );
}

class CircleHeatmapResponse {
  final String circleId;
  final int weekCount;
  final List<CircleHeatmapDay> days;
  CircleHeatmapResponse({required this.circleId, required this.weekCount, required this.days});
  factory CircleHeatmapResponse.fromJson(Map<String, dynamic> j) => CircleHeatmapResponse(
    circleId: j['circleId'] as String,
    weekCount: j['weekCount'] as int? ?? 1,
    days: (j['days'] as List<dynamic>? ?? []).map((d) => CircleHeatmapDay.fromJson(d as Map<String, dynamic>)).toList(),
  );
}

class CircleMilestone {
  final String id;
  final String title;
  final String message;
  final String achievedAt;
  CircleMilestone({required this.id, required this.title, required this.message, required this.achievedAt});
  factory CircleMilestone.fromJson(Map<String, dynamic> j) => CircleMilestone(
    id: j['id'] as String,
    title: j['title'] as String,
    message: j['message'] as String,
    achievedAt: j['achievedAt'] as String,
  );
}

class CircleMilestonesResponse {
  final String circleId;
  final int totalGivingDays;
  final double totalHours;
  final int totalGratitudeDays;
  final List<CircleMilestone> milestones;
  CircleMilestonesResponse({required this.circleId, required this.totalGivingDays, required this.totalHours, required this.totalGratitudeDays, required this.milestones});
  factory CircleMilestonesResponse.fromJson(Map<String, dynamic> j) => CircleMilestonesResponse(
    circleId: j['circleId'] as String,
    totalGivingDays: j['totalGivingDays'] as int? ?? 0,
    totalHours: (j['totalHours'] as num?)?.toDouble() ?? 0.0,
    totalGratitudeDays: j['totalGratitudeDays'] as int? ?? 0,
    milestones: (j['milestones'] as List<dynamic>? ?? []).map((m) => CircleMilestone.fromJson(m as Map<String, dynamic>)).toList(),
  );
}

class CircleNotificationItem {
  final String id;
  final String type;
  final String circleId;
  final String circleName;
  final String senderUid;
  final String senderName;
  final String message;
  final String createdAt;
  final bool isRead;
  final String? actionTaken;
  final bool suppressActions;
  CircleNotificationItem({required this.id, required this.type, required this.circleId, required this.circleName, required this.senderUid, required this.senderName, required this.message, required this.createdAt, required this.isRead, this.actionTaken, required this.suppressActions});
  factory CircleNotificationItem.fromJson(Map<String, dynamic> j) => CircleNotificationItem(
    id: j['id'] as String, type: j['type'] as String, circleId: j['circleId'] as String,
    circleName: j['circleName'] as String, senderUid: j['senderUid'] as String,
    senderName: j['senderName'] as String, message: j['message'] as String,
    createdAt: j['createdAt'] as String, isRead: j['isRead'] as bool? ?? false,
    actionTaken: j['actionTaken'] as String?, suppressActions: j['suppressActions'] as bool? ?? false,
  );
}

// Errors

class APIError implements Exception {
  final String message;
  const APIError._(this.message);

  static const invalidURL = APIError._('Invalid request URL');
  static const serverError = APIError._('Server error. Please try again.');
  static const unauthorized = APIError._('Please sign in to continue');
  static const decodingError = APIError._('Unexpected response format');
  static const rateLimited = APIError._('You can send up to 2 prayer requests per day.');

  @override
  String toString() => message;
}

// Service

class APIService {
  static final APIService shared = APIService._();
  APIService._();

  String? userId;
  bool isAuthenticated = false;

  static const String _baseURL = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://your-backend-url.com',
  );

  Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      isAuthenticated = true;
    }
  }

  void setFirebaseToken(String? token, {String? userId}) {
    this.userId = userId ?? FirebaseAuth.instance.currentUser?.uid;
    isAuthenticated = token != null;
  }

  Future<AuthResponse> ensureProfile({String? displayName, String? email}) {
    final body = <String, dynamic>{
      'displayName': ?displayName,
      'email': ?email,
    };
    return _postMutation<AuthResponse>(
      'auth.ensureProfile',
      body: body,
      fromJson: (j) => AuthResponse.fromJson(j),
    );
  }

  Future<void> signOut() async {
    userId = null;
    isAuthenticated = false;
  }

  Future<CircleResponse> createCircle(String name, {String description = ''}) =>
      _postMutation('circles.create', body: {'name': name, 'description': description}, fromJson: (j) => CircleResponse.fromJson(j));

  Future<JoinCircleResponse> joinCircle(String inviteCode) =>
      _postMutation('circles.join', body: {'inviteCode': inviteCode}, fromJson: (j) => JoinCircleResponse.fromJson(j));

  Future<List<CircleListItem>> listCircles() =>
      _getQuery('circles.list', fromJson: (j) => (j as List<dynamic>).map((e) => CircleListItem.fromJson(e as Map<String, dynamic>)).toList());

  Future<CircleDetail> getCircleDetail(String circleId) =>
      _getQuery('circles.getDetail', input: {'circleId': circleId}, fromJson: (j) => CircleDetail.fromJson(j));

  Future<void> leaveCircle(String circleId) =>
      _postMutation<Map<String, dynamic>>('circles.leave', body: {'circleId': circleId}, fromJson: (j) => j);

  Future<ShareLinkResponse> generateShareLink(String circleId) =>
      _postMutation('invite.generateShareLink', body: {'circleId': circleId}, fromJson: (j) => ShareLinkResponse.fromJson(j));

  Future<SundaySummaryResponse> getSundaySummary(String circleId) =>
      _getQuery('circles.getSundaySummary', input: {'circleId': circleId}, fromJson: (j) => SundaySummaryResponse.fromJson(j));

  Future<void> registerPushToken(String token) async {
    if (userId == null) return;
    try {
      await _postMutation<Map<String, dynamic>>('auth.registerPushToken', body: {'fcmToken': token}, fromJson: (j) => j);
    } catch (_) {}
  }

  Future<GratitudeWallResponse> getGratitudeWall(String circleId, {int weeksBack = 0}) =>
      _getQuery('gratitudes.getWall', input: {'circleId': circleId, 'weeksBack': weeksBack}, fromJson: (j) => GratitudeWallResponse.fromJson(j));

  Future<void> shareGratitude({required List<String> circleIds, required String gratitudeText, required bool isAnonymous, String? displayName}) =>
      _postMutation<Map<String, dynamic>>('gratitudes.share', body: {'circleIds': circleIds, 'gratitudeText': gratitudeText, 'isAnonymous': isAnonymous, 'displayName': ?displayName}, fromJson: (j) => j);

  Future<void> deleteGratitude(String circleId, String gratitudeId) =>
      _postMutation<Map<String, dynamic>>('gratitudes.delete', body: {'circleId': circleId, 'gratitudeId': gratitudeId}, fromJson: (j) => j);

  Future<GratitudeNewCountResponse> getGratitudeNewCount(String circleId) =>
      _getQuery('gratitudes.getNewCount', input: {'circleId': circleId}, fromJson: (j) => GratitudeNewCountResponse.fromJson(j));

  Future<void> markGratitudesSeen(String circleId) =>
      _postMutation<Map<String, dynamic>>('gratitudes.markSeen', body: {'circleId': circleId}, fromJson: (j) => j);

  Future<GratitudeWeekCountResponse> getGratitudeWeekCount(String circleId) =>
      _getQuery('gratitudes.getWeekCount', input: {'circleId': circleId}, fromJson: (j) => GratitudeWeekCountResponse.fromJson(j));

  Future<CircleHeatmapResponse> getCircleHeatmap(String circleId, {int weekCount = 1}) =>
      _getQuery('circles.getHeatmap', input: {'circleId': circleId, 'weekCount': weekCount}, fromJson: (j) => CircleHeatmapResponse.fromJson(j));

  Future<CircleMilestonesResponse> getCircleMilestones(String circleId) =>
      _getQuery('circles.getMilestones', input: {'circleId': circleId}, fromJson: (j) => CircleMilestonesResponse.fromJson(j));

  Future<void> submitHeatmapData(String circleId, List<Map<String, dynamic>> weekData) =>
      _postMutation<Map<String, dynamic>>('circles.submitHeatmapData', body: {'circleId': circleId, 'weekData': weekData}, fromJson: (j) => j);

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<List<CircleNotificationItem>> getNotificationInbox({int limit = 50, bool onlyUnread = false}) =>
      _getQuery('notifications.getInbox', input: {'limit': limit, 'onlyUnread': onlyUnread}, fromJson: (j) => (j as List<dynamic>).map((e) => CircleNotificationItem.fromJson(e as Map<String, dynamic>)).toList());

  Future<void> markNotificationRead(String notifId) =>
      _postMutation<Map<String, dynamic>>('notifications.markRead', body: {'notifId': notifId}, fromJson: (j) => j);

  Future<void> recordNotificationAction(String notifId, String action) =>
      _postMutation<Map<String, dynamic>>('notifications.recordAction', body: {'notifId': notifId, 'action': action}, fromJson: (j) => j);

  Future<void> sendAnnouncement({required String circleId, required String message}) =>
      _postMutation<Map<String, dynamic>>('notifications.sendAnnouncement', body: {'circleId': circleId, 'message': message}, fromJson: (j) => j);

  Future<void> sendPrayerRequest({required String circleId, required String message, required List<String> recipientIds}) =>
      _postMutation<Map<String, dynamic>>('notifications.sendPrayerRequest', body: {'circleId': circleId, 'message': message, 'recipientIds': recipientIds}, fromJson: (j) => j);

  // Private HTTP helpers

  Future<T> _getQuery<T>(String procedure, {Map<String, dynamic>? input, required T Function(dynamic) fromJson}) async {
    var urlString = '$_baseURL/api/trpc/$procedure';
    if (input != null) {
      final encoded = Uri.encodeComponent(jsonEncode(input));
      urlString += '?input=$encoded';
    }
    final uri = Uri.parse(urlString);
    final response = await http.get(uri, headers: await _buildAuthHeaders());
    _checkStatus(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return fromJson(body['result']['data']);
  }

  Future<T> _postMutation<T>(String procedure, {required Map<String, dynamic> body, required T Function(Map<String, dynamic>) fromJson}) async {
    final uri = Uri.parse('$_baseURL/api/trpc/$procedure');
    final authHeaders = await _buildAuthHeaders();
    final response = await http.post(uri, headers: {'Content-Type': 'application/json', ...authHeaders}, body: jsonEncode(body));
    _checkStatus(response);
    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    return fromJson(responseBody['result']['data'] as Map<String, dynamic>);
  }

  Future<Map<String, String>> _buildAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final token = await user.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode < 200 || response.statusCode > 299) {
      if (response.statusCode == 401) throw APIError.unauthorized;
      if (response.statusCode == 429) throw APIError.rateLimited;
      throw APIError.serverError;
    }
  }
}
