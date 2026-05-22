import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/circle.dart';
import '../../../domain/repositories/circle_repository.dart';
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

  // null = "All" selected; non-null = specific subset
  Set<String>? _selectedIds;
  PrayerDuration _duration = PrayerDuration.ongoing;
  bool _sending = false;
  String? _error;

  bool get _allSelected => _selectedIds == null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend {
    if (_sending) return false;
    if (_controller.text.trim().isEmpty) return false;
    // "All" always valid; subset must be non-empty
    return _allSelected || _selectedIds!.isNotEmpty;
  }

  void _toggleAll() {
    setState(() {
      _selectedIds = null; // null means "All"
    });
  }

  void _toggleMember(String userId) {
    setState(() {
      if (_allSelected) {
        // Switch from All → deselect this one member
        _selectedIds = widget.otherMembers
            .map((m) => m.userId)
            .where((id) => id != userId)
            .toSet();
      } else {
        final updated = Set<String>.from(_selectedIds!);
        if (updated.contains(userId)) {
          updated.remove(userId);
        } else {
          updated.add(userId);
          // If every member is now selected, switch back to "All"
          if (updated.length == widget.otherMembers.length) {
            _selectedIds = null;
            return;
          }
        }
        _selectedIds = updated;
      }
    });
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    setState(() { _sending = true; _error = null; });
    try {
      await context.read<CircleRepository>().createPrayerRequest(
            circleId: widget.circleId,
            requestText: message,
            duration: _duration,
            recipientIds: _allSelected ? null : _selectedIds!.toList(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.toString().contains('permission')
              ? 'Not authorized to send in this circle.'
              : 'Failed to send. Please check your connection.';
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
              _label('TO'),
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
                  children: [
                    _pill(
                      label: 'All',
                      selected: _allSelected,
                      onTap: _toggleAll,
                    ),
                    ...widget.otherMembers.map((m) {
                      final selected =
                          _allSelected || (_selectedIds?.contains(m.userId) ?? false);
                      return _pill(
                        label: m.displayName,
                        selected: selected,
                        onTap: () => _toggleMember(m.userId),
                      );
                    }),
                  ],
                ),
              const SizedBox(height: 20),
              _label('HOW LONG'),
              const SizedBox(height: 10),
              _durationPicker(),
              const SizedBox(height: 20),
              _label('MESSAGE'),
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

  Widget _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.4),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _pill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? GraceWayColor.golden
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _durationPicker() {
    const options = [
      (PrayerDuration.thisWeek, 'This week'),
      (PrayerDuration.ongoing, 'Ongoing'),
      (PrayerDuration.untilRemoved, 'Until resolved'),
    ];
    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final (dur, label) = opt;
        final selected = _duration == dur;
        return GestureDetector(
          onTap: () => setState(() => _duration = dur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? GraceWayColor.sage.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? GraceWayColor.sage.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? GraceWayColor.sage
                    : Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
