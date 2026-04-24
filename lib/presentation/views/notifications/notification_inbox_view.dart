import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/circle_notification.dart';
import '../../providers/accountability_provider.dart';
import '../../providers/circle_notification_provider.dart';
import '../../theme/app_theme.dart';
import '../habits/partner_acceptance_screen.dart';

class NotificationInboxView extends StatelessWidget {
  const NotificationInboxView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        foregroundColor: GraceWayColor.warmWhite,
        title: const Text('Notifications'),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () => _showEnterCodeDialog(context),
            child: Text(
              'Enter code',
              style: TextStyle(
                  color: GraceWayColor.sage.withValues(alpha: 0.85), fontSize: 13),
            ),
          ),
        ],
      ),
      body: Consumer<CircleNotificationProvider>(
        builder: (context, provider, _) {
          if (provider.notifications.isEmpty && provider.error == null) {
            return RefreshIndicator(
              color: GraceWayColor.golden,
              backgroundColor: GraceWayColor.cardBackground,
              onRefresh: provider.refresh,
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none,
                              size: 56,
                              color: GraceWayColor.warmWhite.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(
                                color: GraceWayColor.warmWhite.withValues(alpha: 0.5),
                                fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          if (provider.error != null) {
            return RefreshIndicator(
              color: GraceWayColor.golden,
              backgroundColor: GraceWayColor.cardBackground,
              onRefresh: provider.refresh,
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: Center(
                      child: Text(
                        'Could not load notifications',
                        style: TextStyle(
                            color: GraceWayColor.warmWhite.withValues(alpha: 0.5),
                            fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: GraceWayColor.golden,
            backgroundColor: GraceWayColor.cardBackground,
            onRefresh: provider.refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.notifications.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: GraceWayColor.warmWhite.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, i) {
                final notif = provider.notifications[i];
                return _NotificationTile(
                  notification: notif,
                  onMarkRead: () => provider.markRead(notif.id),
                  onAction: (action) => provider.recordAction(notif.id, action),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showEnterCodeDialog(BuildContext context) {
    final codeController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GraceWayColor.charcoal,
        title: const Text('Enter invite code',
            style: TextStyle(
                color: GraceWayColor.warmWhite,
                fontWeight: FontWeight.w600,
                fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 6-character code from your partner\'s invitation.',
              style: TextStyle(
                  color: GraceWayColor.warmWhite, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                  color: GraceWayColor.warmWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4),
              decoration: InputDecoration(
                hintText: 'ABC123',
                hintStyle: TextStyle(
                    color: GraceWayColor.warmWhite.withValues(alpha: 0.3),
                    letterSpacing: 4,
                    fontWeight: FontWeight.w400),
                counterText: '',
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: GraceWayColor.warmWhite.withValues(alpha: 0.2))),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: GraceWayColor.sage)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: GraceWayColor.warmWhite.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();
              if (code.length != 6) return;
              Navigator.pop(ctx);
              if (!context.mounted) return;
              final accountabilityProv = context.read<AccountabilityProvider>();
              final partnership =
                  await accountabilityProv.findByShortCode(code);
              if (!context.mounted) return;
              if (partnership == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Code not found or already used. Check with your partner.')),
                );
                return;
              }
              Navigator.of(context).push(MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) =>
                    PartnerAcceptanceScreen(token: partnership.inviteToken),
              ));
            },
            child: const Text('Find invite',
                style: TextStyle(color: GraceWayColor.sage)),
          ),
        ],
      ),
    ).then((_) => codeController.dispose());
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatefulWidget {
  final CircleNotification notification;
  final VoidCallback onMarkRead;
  final void Function(NotificationAction) onAction;

  const _NotificationTile({
    required this.notification,
    required this.onMarkRead,
    required this.onAction,
  });

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _acting = false;

  CircleNotification get n => widget.notification;

  void _openThread(BuildContext context) {
    if (!n.isRead) widget.onMarkRead();
    final partnership = context
        .read<AccountabilityProvider>()
        .partnerships
        .where((p) => p.id == n.circleId)
        .firstOrNull;
    if (partnership == null || !context.mounted) return;
    Navigator.of(context).pushNamed('/partnership-detail', arguments: partnership);
  }

  Future<void> _handlePartnerAction(NotificationAction action) async {
    final token = n.partnerInviteToken;
    if (token == null) return;
    setState(() => _acting = true);
    try {
      final accountabilityProv = context.read<AccountabilityProvider>();
      if (action == NotificationAction.accept) {
        await accountabilityProv.acceptViaToken(token);
      } else {
        await accountabilityProv.declineViaToken(token);
      }
      if (!mounted) return;
      widget.onAction(action); // marks read + records actionTaken in Firestore
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(action == NotificationAction.accept
                ? 'Could not accept invite. It may have already been used.'
                : 'Could not decline invite.')),
      );
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !n.isRead;
    final color = _typeColor(n.type);
    final icon = _typeIcon(n.type);
    final timeStr = _formatTime(n.createdAt);
    final isPartnerInvite = n.type == CircleNotificationType.partnershipInvite;
    final isThreadable = n.type == CircleNotificationType.partnerMessage ||
        n.type == CircleNotificationType.partnershipAccepted;

    return InkWell(
      onTap: isThreadable
          ? () => _openThread(context)
          : isUnread && !isPartnerInvite
              ? widget.onMarkRead
              : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        color: isUnread
            ? GraceWayColor.warmWhite.withValues(alpha: 0.04)
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _typeLabel(n.type),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: GraceWayColor.warmWhite.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPartnerInvite
                        ? n.senderName
                        : '${n.senderName} · ${n.circleName}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GraceWayColor.warmWhite.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: GraceWayColor.warmWhite.withValues(alpha: 0.65),
                      height: 1.45,
                    ),
                  ),
                  if (!n.suppressActions) ...[
                    const SizedBox(height: 10),
                    if (isPartnerInvite)
                      _PartnerActionRow(
                        actionTaken: n.actionTaken,
                        acting: _acting,
                        onAccept: () =>
                            _handlePartnerAction(NotificationAction.accept),
                        onDecline: () =>
                            _handlePartnerAction(NotificationAction.decline),
                      )
                    else
                      _CircleActionRow(
                        actionTaken: n.actionTaken,
                        onAction: widget.onAction,
                      ),
                  ],
                ],
              ),
            ),
            if (isUnread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _typeColor(CircleNotificationType type) {
    switch (type) {
      case CircleNotificationType.sos:
        return const Color(0xFFE05555);
      case CircleNotificationType.prayerRequest:
        return GraceWayColor.softGold;
      case CircleNotificationType.announcement:
        return const Color(0xFF5B8DEF);
      case CircleNotificationType.partnershipInvite:
      case CircleNotificationType.partnerMessage:
      case CircleNotificationType.partnershipAccepted:
        return GraceWayColor.sage;
    }
  }

  IconData _typeIcon(CircleNotificationType type) {
    switch (type) {
      case CircleNotificationType.sos:
        return Icons.warning_rounded;
      case CircleNotificationType.prayerRequest:
        return Icons.volunteer_activism_rounded;
      case CircleNotificationType.announcement:
        return Icons.campaign_rounded;
      case CircleNotificationType.partnershipInvite:
        return Icons.handshake_rounded;
      case CircleNotificationType.partnerMessage:
        return Icons.chat_bubble_outline_rounded;
      case CircleNotificationType.partnershipAccepted:
        return Icons.handshake_rounded;
    }
  }

  String _typeLabel(CircleNotificationType type) {
    switch (type) {
      case CircleNotificationType.sos:
        return 'SOS';
      case CircleNotificationType.prayerRequest:
        return 'PRAYER REQUEST';
      case CircleNotificationType.announcement:
        return 'ANNOUNCEMENT';
      case CircleNotificationType.partnershipInvite:
        return 'PARTNER INVITE';
      case CircleNotificationType.partnerMessage:
        return 'PARTNER MESSAGE';
      case CircleNotificationType.partnershipAccepted:
        return 'PARTNER ACCEPTED';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }
}

// ── Partner invite actions (Accept / Decline) ─────────────────────────────────

class _PartnerActionRow extends StatelessWidget {
  final NotificationAction? actionTaken;
  final bool acting;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _PartnerActionRow({
    required this.actionTaken,
    required this.acting,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    if (actionTaken != null) {
      final label = actionTaken == NotificationAction.accept
          ? 'Accepted — you\'re walking together'
          : 'Declined';
      final icon = actionTaken == NotificationAction.accept
          ? Icons.check_circle_outline
          : Icons.cancel_outlined;
      return Row(children: [
        Icon(icon, size: 14, color: GraceWayColor.sage.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: GraceWayColor.sage.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic)),
      ]);
    }

    if (acting) {
      return const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: GraceWayColor.sage));
    }

    return Row(children: [
      _ActionButton(
          label: 'Accept',
          icon: Icons.check_rounded,
          color: GraceWayColor.sage,
          onTap: onAccept),
      const SizedBox(width: 8),
      _ActionButton(
          label: 'Decline',
          icon: Icons.close_rounded,
          color: GraceWayColor.warmWhite.withValues(alpha: 0.4),
          onTap: onDecline),
    ]);
  }
}

// ── Circle actions (Pray / I'm Here) ─────────────────────────────────────────

class _CircleActionRow extends StatelessWidget {
  final NotificationAction? actionTaken;
  final void Function(NotificationAction) onAction;

  const _CircleActionRow(
      {required this.actionTaken, required this.onAction});

  @override
  Widget build(BuildContext context) {
    if (actionTaken != null) {
      final label =
          actionTaken == NotificationAction.pray ? 'Prayed' : "I'm Here — sent";
      return Row(children: [
        Icon(Icons.check_circle_outline,
            size: 14, color: GraceWayColor.softGold.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: GraceWayColor.softGold.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic)),
      ]);
    }

    return Row(children: [
      _ActionButton(
          label: 'Pray',
          icon: Icons.favorite_border_rounded,
          color: GraceWayColor.warmWhite.withValues(alpha: 0.7),
          onTap: () => onAction(NotificationAction.pray)),
      const SizedBox(width: 8),
      _ActionButton(
          label: "I'm Here",
          icon: Icons.handshake_outlined,
          color: GraceWayColor.warmWhite.withValues(alpha: 0.7),
          onTap: () => onAction(NotificationAction.imHere)),
    ]);
  }
}

// ── Shared action button ──────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: GraceWayColor.warmWhite.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: GraceWayColor.warmWhite.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
