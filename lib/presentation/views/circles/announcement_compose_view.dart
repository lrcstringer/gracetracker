import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/circle_notification_provider.dart';
import '../../theme/app_theme.dart';

class AnnouncementComposeView extends StatefulWidget {
  final String circleId;
  final String circleName;

  const AnnouncementComposeView({
    super.key,
    required this.circleId,
    required this.circleName,
  });

  @override
  State<AnnouncementComposeView> createState() =>
      _AnnouncementComposeViewState();
}

class _AnnouncementComposeViewState extends State<AnnouncementComposeView> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    setState(() => _sending = true);
    try {
      await context.read<CircleNotificationProvider>().sendAnnouncement(
            circleId: widget.circleId,
            message: message,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        foregroundColor: GraceWayColor.warmWhite,
        title: const Text('Send Announcement'),
        actions: [
          TextButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Send',
                    style: TextStyle(
                      color: GraceWayColor.softGold,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To all members of ${widget.circleName}',
                style: TextStyle(
                  fontSize: 13,
                  color: GraceWayColor.warmWhite.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLength: 500,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    color: GraceWayColor.warmWhite,
                    fontSize: 15,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write your announcement…',
                    hintStyle: TextStyle(
                        color: GraceWayColor.warmWhite.withValues(alpha: 0.3)),
                    border: InputBorder.none,
                    counterStyle: TextStyle(
                        color: GraceWayColor.warmWhite.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
