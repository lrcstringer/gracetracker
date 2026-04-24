import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/accountability_partnership.dart';
import '../../../domain/entities/partner_message.dart';
import '../../providers/accountability_provider.dart';
import '../../theme/app_theme.dart';

class PartnershipDetailScreen extends StatefulWidget {
  final AccountabilityPartnership partnership;

  const PartnershipDetailScreen({super.key, required this.partnership});

  @override
  State<PartnershipDetailScreen> createState() =>
      _PartnershipDetailScreenState();
}

class _PartnershipDetailScreenState extends State<PartnershipDetailScreen> {
  static const _maxChars = 500;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  int _lastKnownMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    // Mark messages as read on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountabilityProvider>().markMessagesRead(widget.partnership.id);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    final prov = context.read<AccountabilityProvider>();
    try {
      await prov.sendReachOut(
        partnershipId: widget.partnership.id,
        body: body,
      );
      if (!mounted) return;
      _controller.clear();
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't send. Check your connection."),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmEnd(String partnerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GraceWayColor.surfaceOverlay,
        title: const Text('End partnership?',
            style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 16)),
        content: Text(
          'This will end your accountability partnership with '
          '$partnerName. '
          'Messages will no longer be visible.',
          style: TextStyle(
              color: GraceWayColor.warmWhite.withValues(alpha: 0.7),
              fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: GraceWayColor.warmWhite.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End',
                style: TextStyle(color: GraceWayColor.warmCoral)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context
        .read<AccountabilityProvider>()
        .endPartnership(widget.partnership.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AccountabilityProvider>();
    final uid = prov.currentUserId ?? '';
    // Use live partnership from provider so status changes are reflected
    // immediately (e.g. partner ends partnership while this screen is open).
    final livePartnership = prov.partnerships
        .where((p) => p.id == widget.partnership.id)
        .firstOrNull ?? widget.partnership;
    final messages = prov.messagesFor(widget.partnership.id);
    final partnerName =
        livePartnership.partnerDisplayName ?? 'Your partner';
    final isOwner = livePartnership.ownerId == uid;

    // Scroll to bottom only when new messages arrive (not on every rebuild).
    if (messages.length > _lastKnownMessageCount) {
      _lastKnownMessageCount = messages.length;
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: GraceWayColor.warmWhite),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              partnerName,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: GraceWayColor.warmWhite),
            ),
            Text(
              livePartnership.habitName,
              style: TextStyle(
                  fontSize: 11,
                  color: GraceWayColor.warmWhite.withValues(alpha: 0.45)),
            ),
          ],
        ),
        actions: [
          if (livePartnership.status == PartnershipStatus.active)
            PopupMenuButton<String>(
              color: GraceWayColor.surfaceOverlay,
              icon: Icon(Icons.more_vert_rounded,
                  size: 20,
                  color: GraceWayColor.warmWhite.withValues(alpha: 0.6)),
              onSelected: (val) {
                if (val == 'end') _confirmEnd(partnerName);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'end',
                  child: Row(children: [
                    Icon(Icons.handshake_outlined,
                        size: 16,
                        color: GraceWayColor.warmCoral.withValues(alpha: 0.8)),
                    const SizedBox(width: 8),
                    Text(
                      isOwner ? 'End partnership' : 'Leave partnership',
                      style: TextStyle(
                          fontSize: 13,
                          color: GraceWayColor.warmCoral.withValues(alpha: 0.9)),
                    ),
                  ]),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          Expanded(
            child: messages.isEmpty
                ? _EmptyThread(partnerName: partnerName)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final msg = messages[i];
                      final isMe = msg.senderId == uid;
                      final showDate = i == 0 ||
                          !_sameDay(
                              messages[i - 1].sentAt, msg.sentAt);
                      return Column(
                        children: [
                          if (showDate) _DateChip(date: msg.sentAt),
                          _MessageBubble(message: msg, isMe: isMe),
                        ],
                      );
                    },
                  ),
          ),
          if (livePartnership.status == PartnershipStatus.active)
            _ComposeBar(
              controller: _controller,
              sending: _sending,
              maxChars: _maxChars,
              onSend: _send,
            )
          else
            _EndedBanner(status: livePartnership.status),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyThread extends StatelessWidget {
  final String partnerName;
  const _EmptyThread({required this.partnerName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.handshake_rounded,
                size: 40,
                color: GraceWayColor.sage.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              'You and $partnerName are walking together.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  color: GraceWayColor.warmWhite.withValues(alpha: 0.7),
                  height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Send your first message below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: GraceWayColor.warmWhite.withValues(alpha: 0.35)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date chip ─────────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${_month(date.month)} ${date.day}';
  }

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: GraceWayColor.warmWhite.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _label(),
            style: TextStyle(
                fontSize: 11,
                color: GraceWayColor.warmWhite.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final PartnerMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  String _time(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'am' : 'pm';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? GraceWayColor.sage.withValues(alpha: 0.22)
                      : GraceWayColor.warmWhite.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: Text(
                  message.body,
                  style: TextStyle(
                      fontSize: 14,
                      color: GraceWayColor.warmWhite
                          .withValues(alpha: isMe ? 0.92 : 0.78),
                      height: 1.45),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _time(message.sentAt),
                style: TextStyle(
                    fontSize: 10,
                    color: GraceWayColor.warmWhite.withValues(alpha: 0.28)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compose bar ───────────────────────────────────────────────────────────────

class _ComposeBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final int maxChars;
  final VoidCallback onSend;

  const _ComposeBar({
    required this.controller,
    required this.sending,
    required this.maxChars,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = maxChars - controller.text.length;
    final canSend = controller.text.trim().isNotEmpty && !sending;

    return Container(
      color: GraceWayColor.charcoal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: Color(0xFF2A2A2A)),
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: 5,
                    minLines: 1,
                    maxLength: maxChars,
                    buildCounter: (_, {required currentLength,
                            required isFocused, maxLength}) =>
                        null,
                    style: const TextStyle(
                        color: GraceWayColor.warmWhite,
                        fontSize: 14,
                        height: 1.45),
                    decoration: InputDecoration(
                      hintText: 'Share what\'s on your heart…',
                      hintStyle: TextStyle(
                          color: GraceWayColor.warmWhite.withValues(alpha: 0.28),
                          fontSize: 14),
                      filled: true,
                      fillColor: GraceWayColor.surfaceOverlay,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: canSend ? onSend : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: canSend
                          ? GraceWayColor.sage
                          : GraceWayColor.sage.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: sending
                        ? Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: GraceWayColor.charcoal.withValues(alpha: 0.7),
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: canSend
                                ? GraceWayColor.charcoal
                                : GraceWayColor.charcoal.withValues(alpha: 0.4),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (remaining < 80)
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$remaining',
                  style: TextStyle(
                      fontSize: 11,
                      color: remaining < 30
                          ? GraceWayColor.warmCoral.withValues(alpha: 0.8)
                          : GraceWayColor.warmWhite.withValues(alpha: 0.3)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Ended / declined banner ───────────────────────────────────────────────────

class _EndedBanner extends StatelessWidget {
  final PartnershipStatus status;
  const _EndedBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      PartnershipStatus.ended => 'This partnership has ended.',
      PartnershipStatus.declined => 'The invitation was declined.',
      PartnershipStatus.cancelled => 'This invitation was cancelled.',
      _ => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: GraceWayColor.charcoal,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 13,
            color: GraceWayColor.warmWhite.withValues(alpha: 0.35)),
      ),
    );
  }
}
