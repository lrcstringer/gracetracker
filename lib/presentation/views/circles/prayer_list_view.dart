import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/circle.dart';
import '../../../domain/repositories/circle_repository.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../theme/app_theme.dart';

class PrayerListView extends StatefulWidget {
  final String circleId;
  final String circleName;

  const PrayerListView({
    super.key,
    required this.circleId,
    required this.circleName,
  });

  @override
  State<PrayerListView> createState() => _PrayerListViewState();
}

class _PrayerListViewState extends State<PrayerListView> {
  List<PrayerRequest> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final requests = await context
          .read<CircleRepository>()
          .getPrayerRequests(widget.circleId);
      if (mounted) setState(() { _requests = requests; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pray(PrayerRequest req) async {
    try {
      await context
          .read<CircleRepository>()
          .prayForRequest(widget.circleId, req.id);
      _load();
    } catch (_) {}
  }

  Future<void> _markAnswered(PrayerRequest req) async {
    String? note;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AnsweredDialog(
        onConfirm: (n) { note = n; Navigator.pop(ctx, true); },
        onCancel: () => Navigator.pop(ctx, false),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<CircleRepository>().markPrayerAnswered(
            widget.circleId,
            req.id,
            answeredNote: note?.isNotEmpty == true ? note : null,
          );
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        foregroundColor: GraceWayColor.warmWhite,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Prayer Requests',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: GraceWayColor.warmWhite)),
            Text(widget.circleName,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.4))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                size: 20, color: GraceWayColor.softGold),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: GraceWayColor.golden));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.warning_amber_rounded,
              size: 28, color: GraceWayColor.warmCoral),
          const SizedBox(height: 12),
          Text('Could not load requests',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 12),
          TextButton(
              onPressed: _load,
              child: const Text('Retry',
                  style: TextStyle(color: GraceWayColor.golden))),
        ]),
      );
    }
    if (_requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.volunteer_activism_rounded,
                size: 40, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              'No prayer requests yet.',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 8),
            Text(
              "When members share requests, they'll appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.3),
                  height: 1.5),
            ),
          ]),
        ),
      );
    }

    final uid = AuthService.shared.userId ?? '';
    final active = _requests.where((r) => r.status == PrayerRequestStatus.active).toList();
    final answered =
        _requests.where((r) => r.status == PrayerRequestStatus.answered).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        if (active.isNotEmpty) ...[
          _sectionHeader('Active (${active.length})'),
          const SizedBox(height: 8),
          ...active.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RequestCard(
                  request: r,
                  currentUid: uid,
                  onPray: () => _pray(r),
                  onMarkAnswered: () => _markAnswered(r),
                ),
              )),
        ],
        if (answered.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sectionHeader('Answered (${answered.length})'),
          const SizedBox(height: 8),
          ...answered.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RequestCard(
                  request: r,
                  currentUid: uid,
                  onPray: null,
                  onMarkAnswered: null,
                ),
              )),
        ],
      ],
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.4),
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Request card ─────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final PrayerRequest request;
  final String currentUid;
  final VoidCallback? onPray;
  final VoidCallback? onMarkAnswered;

  const _RequestCard({
    required this.request,
    required this.currentUid,
    required this.onPray,
    required this.onMarkAnswered,
  });

  @override
  Widget build(BuildContext context) {
    final isAnswered = request.status == PrayerRequestStatus.answered;
    final isMine = request.authorId == currentUid;
    final alreadyPrayed = request.prayedByUserIds.contains(currentUid);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAnswered
            ? GraceWayColor.sage.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAnswered
              ? GraceWayColor.sage.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: author + time
          Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAnswered
                    ? GraceWayColor.sage.withValues(alpha: 0.15)
                    : GraceWayColor.sage.withValues(alpha: 0.10),
              ),
              child: Icon(
                isAnswered
                    ? Icons.check_circle_rounded
                    : Icons.volunteer_activism_rounded,
                size: 13,
                color: GraceWayColor.sage,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMine ? 'You' : request.authorDisplayName,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: GraceWayColor.warmWhite),
              ),
            ),
            Text(
              _timeAgo(request.createdAt),
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
            ),
          ]),
          const SizedBox(height: 10),
          // Request text
          Text(
            request.requestText,
            style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.5),
          ),
          // Answered note
          if (isAnswered && request.answeredNote?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: GraceWayColor.sage.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 13, color: GraceWayColor.sage.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.answeredNote!,
                      style: TextStyle(
                          fontSize: 13,
                          color: GraceWayColor.sage.withValues(alpha: 0.9),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Footer: prayer count + action buttons
          Row(children: [
            Icon(Icons.volunteer_activism_rounded,
                size: 13, color: Colors.white.withValues(alpha: 0.35)),
            const SizedBox(width: 4),
            Text(
              '${request.prayerCount} ${request.prayerCount == 1 ? 'person' : 'people'} prayed',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
            ),
            const Spacer(),
            if (!isAnswered && onPray != null && !alreadyPrayed)
              _actionButton(
                label: 'Pray',
                icon: Icons.volunteer_activism_rounded,
                color: GraceWayColor.sage,
                onTap: onPray!,
              ),
            if (!isAnswered && onPray != null && alreadyPrayed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Prayed ✓',
                  style: TextStyle(
                      fontSize: 12,
                      color: GraceWayColor.sage.withValues(alpha: 0.7)),
                ),
              ),
            if (!isAnswered && isMine && onMarkAnswered != null) ...[
              const SizedBox(width: 8),
              _actionButton(
                label: 'Answered',
                icon: Icons.check_circle_outline_rounded,
                color: GraceWayColor.golden,
                onTap: onMarkAnswered!,
              ),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (_) {
      return '';
    }
  }
}

// ─── Answered dialog ──────────────────────────────────────────────────────────

class _AnsweredDialog extends StatefulWidget {
  final ValueChanged<String?> onConfirm;
  final VoidCallback onCancel;

  const _AnsweredDialog({required this.onConfirm, required this.onCancel});

  @override
  State<_AnsweredDialog> createState() => _AnsweredDialogState();
}

class _AnsweredDialogState extends State<_AnsweredDialog> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Mark as Answered',
          style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Would you like to share how God answered this prayer?',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            maxLength: 200,
            maxLines: 3,
            style: const TextStyle(
                color: GraceWayColor.warmWhite, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Optional note…',
              hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1), width: 0.5),
              ),
              counterStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text('Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        ),
        TextButton(
          onPressed: () => widget.onConfirm(_noteController.text.trim()),
          child: const Text('Mark Answered',
              style: TextStyle(
                  color: GraceWayColor.golden, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
