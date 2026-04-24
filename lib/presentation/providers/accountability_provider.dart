import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/datasources/remote/auth_service.dart';
import '../../domain/entities/accountability_partnership.dart';
import '../../domain/entities/partner_message.dart';
import '../../domain/repositories/accountability_repository.dart';

class AccountabilityProvider extends ChangeNotifier {
  final AccountabilityRepository _repo;

  AccountabilityProvider(this._repo) {
    AuthService.shared.addListener(_onAuthChanged);
    if (AuthService.shared.isAuthenticated) _startListening();
  }

  List<AccountabilityPartnership> _partnerships = [];
  final Map<String, List<PartnerMessage>> _messagesByPartnership = {};
  final Map<String, StreamSubscription<List<PartnerMessage>>> _messageSubs = {};
  StreamSubscription<List<AccountabilityPartnership>>? _partnershipSub;

  bool _loading = false;
  String? error;

  List<AccountabilityPartnership> get partnerships => _partnerships;
  bool get isLoading => _loading;
  String? get currentUserId => AuthService.shared.userId;

  /// Returns the active or pending partnership for a given habitId, if any.
  AccountabilityPartnership? partnershipForHabit(String habitId) {
    return _partnerships
        .where((p) =>
            p.habitId == habitId &&
            (p.status == PartnershipStatus.active ||
                p.status == PartnershipStatus.pending))
        .firstOrNull;
  }

  List<PartnerMessage> messagesFor(String partnershipId) =>
      _messagesByPartnership[partnershipId] ?? [];

  @override
  void dispose() {
    AuthService.shared.removeListener(_onAuthChanged);
    _partnershipSub?.cancel();
    for (final sub in _messageSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _onAuthChanged() {
    if (AuthService.shared.isAuthenticated) {
      _startListening();
    } else {
      _clearAll();
    }
  }

  void _startListening() {
    _partnershipSub?.cancel();
    _partnershipSub = _repo.watchPartnershipsForUser().listen(
      (list) {
        _partnerships = list;

        final activeIds = list
            .where((p) => p.status == PartnershipStatus.active)
            .map((p) => p.id)
            .toSet();

        // Cancel subscriptions for partnerships that are no longer active.
        final stale = _messageSubs.keys
            .where((id) => !activeIds.contains(id))
            .toList();
        for (final id in stale) {
          _messageSubs.remove(id)?.cancel();
          _messagesByPartnership.remove(id);
        }

        // Subscribe to messages for newly active partnerships.
        for (final p in list) {
          if (p.status == PartnershipStatus.active &&
              !_messageSubs.containsKey(p.id)) {
            _subscribeMessages(p.id);
          }
        }
        notifyListeners();
      },
      onError: (Object e) {
        error = e.toString();
        notifyListeners();
      },
    );
  }

  void _subscribeMessages(String partnershipId) {
    _messageSubs[partnershipId] =
        _repo.watchMessages(partnershipId).listen((msgs) {
      _messagesByPartnership[partnershipId] = msgs;
      notifyListeners();
    });
  }

  void _clearAll() {
    _partnerships = [];
    _messagesByPartnership.clear();
    _partnershipSub?.cancel();
    _partnershipSub = null;
    for (final sub in _messageSubs.values) {
      sub.cancel();
    }
    _messageSubs.clear();
    error = null;
    notifyListeners();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Creates an invite and returns [InviteResult] with shareUrl, shortCode,
  /// and inAppSent flag. [recipientEmail] is optional — when provided and the
  /// email belongs to a GraceWay user, an in-app notification is sent to them.
  Future<InviteResult> createInvite({
    required String habitId,
    required String habitName,
    String? recipientEmail,
  }) async {
    _loading = true;
    error = null;
    notifyListeners();
    try {
      final displayName = AuthService.shared.displayName ?? 'A friend';
      return await _repo.createInvite(
        habitId: habitId,
        habitName: habitName,
        ownerDisplayName: displayName,
        recipientEmail: recipientEmail,
      );
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<AccountabilityPartnership> acceptViaToken(String token) async {
    _loading = true;
    error = null;
    notifyListeners();
    try {
      final displayName = AuthService.shared.displayName ?? 'Your partner';
      return await _repo.acceptViaToken(
        token: token,
        partnerDisplayName: displayName,
      );
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> declineViaToken(String token) async {
    await _repo.declineViaToken(token);
  }

  Future<void> cancelPartnership(String partnershipId) async {
    await _repo.cancelPartnership(partnershipId);
  }

  Future<void> endPartnership(String partnershipId) async {
    await _repo.endPartnership(partnershipId);
  }

  Future<void> sendReachOut({
    required String partnershipId,
    required String body,
  }) async {
    final displayName = AuthService.shared.displayName ?? 'Your partner';
    await _repo.sendMessage(
      partnershipId: partnershipId,
      body: body,
      senderDisplayName: displayName,
    );
  }

  Future<void> markMessagesRead(String partnershipId) async {
    await _repo.markMessagesRead(partnershipId);
  }

  /// Ends/cancels all active or pending partnerships for the given habit.
  /// Call before deleting or archiving a habit. No-ops if no partnerships exist.
  Future<void> endPartnershipsForHabit(String habitId, {String reason = 'deleted'}) async {
    await _repo.endPartnershipsForHabit(habitId, reason: reason);
  }

  Future<AccountabilityPartnership?> findByToken(String token) =>
      _repo.findByToken(token);

  Future<AccountabilityPartnership?> findByShortCode(String code) =>
      _repo.findByShortCode(code);
}
