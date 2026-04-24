import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/circle.dart';
import '../../../data/datasources/remote/api_service.dart';
import '../../providers/circle_notification_provider.dart';
import '../../theme/app_theme.dart';

class PrayerRequestComposeView extends StatefulWidget {
  final String circleId;
  final String circleName;
  final List<CircleMember> otherMembers;

  const PrayerRequestComposeView({
    super.key,
    required this.circleId,
    required this.circleName,
    required this.otherMembers,
  });

  @override
  State<PrayerRequestComposeView> createState() =>
      _PrayerRequestComposeViewState();
}

class _PrayerRequestComposeViewState extends State<PrayerRequestComposeView> {
  final _controller = TextEditingController();
  late Set<String> _selectedIds;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.otherMembers.map((m) => m.userId).toSet();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend =>
      _controller.text.trim().isNotEmpty && _selectedIds.isNotEmpty && !_sending;

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _selectedIds.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<CircleNotificationProvider>().sendPrayerRequest(
            circleId: widget.circleId,
            message: message,
            recipientIds: _selectedIds.toList(),
          );
      if (mounted) Navigator.pop(context);
    } on APIError catch (e) {
      if (mounted) setState(() { _sending = false; _error = e.message; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Failed to send. Please check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        foregroundColor: GraceWayColor.warmWhite,
        title: const Text('Prayer Request'),
        actions: [
          TextButton(
            onPressed: _canSend ? _send : null,
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: GraceWayColor.softGold),
                  )
                : Text(
                    'Send',
                    style: TextStyle(
                      color: _canSend
                          ? GraceWayColor.softGold
                          : GraceWayColor.softGold.withValues(alpha: 0.4),
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
                'TO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              if (widget.otherMembers.isEmpty)
                Text(
                  'No other members in this circle yet.',
                  style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.otherMembers.map((m) {
                    final selected = _selectedIds.contains(m.userId);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedIds.remove(m.userId);
                        } else {
                          _selectedIds.add(m.userId);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? GraceWayColor.golden.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? GraceWayColor.golden.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.12),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          m.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
                                ? GraceWayColor.golden
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),
              Text(
                'MESSAGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLength: 500,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: GraceWayColor.warmWhite,
                    fontSize: 15,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share your prayer request…',
                    hintStyle: TextStyle(
                        color: GraceWayColor.warmWhite.withValues(alpha: 0.3)),
                    border: InputBorder.none,
                    counterStyle: TextStyle(
                        color: GraceWayColor.warmWhite.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: GraceWayColor.warmCoral),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          fontSize: 12, color: GraceWayColor.warmCoral),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
