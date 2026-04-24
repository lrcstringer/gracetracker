import '../entities/accountability_partnership.dart';
import '../entities/partner_message.dart';

class InviteResult {
  final String shareUrl;
  final String shortCode;
  final bool inAppSent;

  const InviteResult({
    required this.shareUrl,
    required this.shortCode,
    required this.inAppSent,
  });
}

abstract class AccountabilityRepository {
  /// Creates a new partnership doc and returns invite details.
  /// [recipientEmail] is optional — if the email belongs to a GraceWay user an
  /// in-app notification is written to their inbox automatically.
  Future<InviteResult> createInvite({
    required String habitId,
    required String habitName,
    required String ownerDisplayName,
    String? recipientEmail,
  });

  /// Accepts a pending partnership via its invite token.
  /// Returns the accepted [AccountabilityPartnership].
  Future<AccountabilityPartnership> acceptViaToken({
    required String token,
    required String partnerDisplayName,
  });

  /// Declines a pending partnership via its invite token.
  Future<void> declineViaToken(String token);

  /// Owner cancels a pending or active partnership.
  Future<void> cancelPartnership(String partnershipId);

  /// Either participant ends an active partnership.
  Future<void> endPartnership(String partnershipId);

  /// Sends a message within a partnership. Batch-writes: message doc +
  /// updates lastMessagePreview/lastMessageAt on the partnership.
  Future<void> sendMessage({
    required String partnershipId,
    required String body,
    required String senderDisplayName,
  });

  /// Marks all unread messages in a partnership as read by the current user.
  Future<void> markMessagesRead(String partnershipId);

  /// Stream of all partnerships where the current user is a participant.
  Stream<List<AccountabilityPartnership>> watchPartnershipsForUser();

  /// Stream of messages for a given partnership, ordered oldest-first.
  Stream<List<PartnerMessage>> watchMessages(String partnershipId);

  /// Looks up a partnership by invite token (for the acceptance screen).
  /// Returns null if not found or already used.
  Future<AccountabilityPartnership?> findByToken(String token);

  /// Looks up a pending partnership by its 6-character short code.
  /// Returns null if not found or already used.
  Future<AccountabilityPartnership?> findByShortCode(String code);

  /// Ends/cancels all active or pending partnerships for the given habit owned
  /// by the current user. Active ones are ended and the partner is notified.
  /// [reason] is 'deleted' or 'archived' — passed to the Cloud Function.
  Future<void> endPartnershipsForHabit(String habitId, {String reason = 'deleted'});
}
