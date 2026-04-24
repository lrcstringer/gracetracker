import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/scripture.dart';
import '../../providers/habit_provider.dart';
import '../../providers/store_provider.dart';
import '../../../domain/entities/circle.dart';
import '../../../domain/repositories/circle_repository.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../theme/app_theme.dart';
import 'share_gratitude_sheet.dart';

/// Embeddable gratitude check-in card for use inside TodayView or standalone.
class GratitudeCheckInView extends StatefulWidget {
  final Habit habit;
  final DateTime targetDate;
  final bool isRetroactive;

  const GratitudeCheckInView({
    super.key,
    required this.habit,
    required this.targetDate,
    required this.isRetroactive,
  });

  @override
  State<GratitudeCheckInView> createState() => _GratitudeCheckInViewState();
}

class _GratitudeCheckInViewState extends State<GratitudeCheckInView> {
  final _controller = TextEditingController();
  bool _isCompleted = false;
  bool _showPulse = false;
  Scripture? _verse;
  bool _showSharePrompt = false;
  bool _shareConfirmed = false;
  List<Circle> _circles = [];
  String? _lastCompletedText;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(GratitudeCheckInView old) {
    super.didUpdateWidget(old);
    if (old.targetDate != widget.targetDate) {
      _controller.clear();
      _refresh();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    final completed = widget.habit.isCompleted(widget.targetDate);
    final isPremium = context.read<StoreProvider>().isPremium;
    setState(() {
      _isCompleted = completed;
      _verse = completed
          ? ScriptureLibrary.completionVerse(
              widget.habit.category, widget.targetDate, isPremium: isPremium)
          : null;
    });
  }

  void _complete() {
    final note = _controller.text.trim().isEmpty ? null : _controller.text.trim();
    final isPremium = context.read<StoreProvider>().isPremium;
    context.read<HabitProvider>().checkInGratitude(
          widget.habit, note: note, date: widget.targetDate);
    setState(() {
      _isCompleted = true;
      _showPulse = true;
      _lastCompletedText = note;
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _verse = ScriptureLibrary.completionVerse(
              widget.habit.category, widget.targetDate, isPremium: isPremium);
        });
      }
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showPulse = false);
    });
    _loadCirclesForShare();
  }

  void _loadCirclesForShare() {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) return;
    context.read<CircleRepository>().listCircles().then((circles) {
      if (!mounted || circles.isEmpty) return;
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() { _circles = circles; _showSharePrompt = true; });
      });
    }).catchError((Object e) { debugPrint('ShareGratitude failed: $e'); });
  }

  String get _dayName {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[(widget.targetDate.weekday - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: GraceWayDecorations.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _header(),
            if (!_isCompleted) ...[
              const SizedBox(height: 12),
              _inputSection(),
            ],
            if (_verse != null && _isCompleted) ...[
              const SizedBox(height: 12),
              _verseSection(_verse!),
            ],
            if (_showSharePrompt && _isCompleted && _circles.isNotEmpty) ...[
              const SizedBox(height: 12),
              _shareSection(),
            ],
          ]),
        ),
        if (_showPulse)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: GraceWayColor.golden.withValues(alpha: 0.06),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _header() {
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            GraceWayColor.golden.withValues(alpha: _isCompleted ? 0.35 : 0.12),
            GraceWayColor.golden.withValues(alpha: _isCompleted ? 0.15 : 0.04),
          ]),
        ),
        child: const Icon(Icons.auto_awesome, size: 20, color: GraceWayColor.golden),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Daily Gratitude',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
          Text(
            _isCompleted
                ? '${widget.habit.totalCompletedDays()} days of gratitude'
                : (widget.isRetroactive
                    ? 'Were you grateful on $_dayName?'
                    : 'What\u2019s one thing you\u2019re grateful for?'),
            style: TextStyle(
                fontSize: 12,
                color: _isCompleted ? GraceWayColor.sage : GraceWayColor.softGold.withValues(alpha: 0.7)),
          ),
        ]),
      ),
      if (_isCompleted)
        const Icon(Icons.check_circle_rounded, size: 24, color: GraceWayColor.golden),
    ]);
  }

  Widget _inputSection() {
    return Column(children: [
      TextField(
        controller: _controller,
        maxLines: 3,
        style: const TextStyle(fontSize: 14, color: GraceWayColor.warmWhite),
        decoration: InputDecoration(
          hintText: widget.isRetroactive
              ? 'What were you grateful for?'
              : 'Thank God for something today...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
          filled: true,
          fillColor: GraceWayColor.cardBackground,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _complete,
          icon: const Icon(Icons.favorite_rounded, size: 14),
          label: Text(
            _controller.text.trim().isEmpty ? 'Thank you, Lord' : 'Give thanks',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: GraceWayColor.golden,
            foregroundColor: GraceWayColor.charcoal,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ]);
  }

  Widget _verseSection(Scripture verse) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('\u201C${verse.text}\u201D',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic,
              color: GraceWayColor.softGold.withValues(alpha: 0.6), height: 1.6)),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.center,
        child: Text(verse.reference,
            style: TextStyle(fontSize: 11, color: GraceWayColor.golden.withValues(alpha: 0.4))),
      ),
    ]);
  }

  Widget _shareSection() {
    if (_shareConfirmed) {
      return Center(
        child: Text('Shared \u2713',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: GraceWayColor.sage)),
      );
    }
    return GestureDetector(
      onTap: () => _openShareSheet(),
      child: Row(children: [
        Text('Share with your circle?',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
        const Spacer(),
        const Icon(Icons.ios_share_rounded, size: 14, color: GraceWayColor.golden),
      ]),
    );
  }

  void _openShareSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: GraceWayColor.charcoal,
      builder: (_) => ShareGratitudeSheet(
        circles: _circles,
        gratitudeText: _lastCompletedText,
        onShare: (circleIds, isAnonymous) {
          final auth = context.read<AuthService>();
          final text = (_lastCompletedText?.isNotEmpty ?? false)
              ? _lastCompletedText!
              : (isAnonymous ? 'gave thanks to God today' : '${auth.displayName?.split(' ').first ?? 'Someone'} gave thanks to God today');
          context.read<CircleRepository>().shareGratitude(
            circleIds: circleIds,
            gratitudeText: text,
            isAnonymous: isAnonymous,
            displayName: auth.displayName,
          ).then((_) {
            if (mounted) {
              setState(() => _shareConfirmed = true);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() { _shareConfirmed = false; _showSharePrompt = false; });
              });
            }
          }).catchError((_) {});
        },
      ),
    );
  }
}
