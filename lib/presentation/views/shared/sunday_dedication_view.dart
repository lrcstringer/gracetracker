import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/scripture.dart';
import '../../providers/habit_provider.dart';
import '../../../domain/services/week_cycle_manager.dart';
import '../../theme/app_theme.dart';

class SundayDedicationView extends StatefulWidget {
  final WeekCycleManager weekCycleManager;
  final VoidCallback onDismiss;

  const SundayDedicationView({
    super.key,
    required this.weekCycleManager,
    required this.onDismiss,
  });

  @override
  State<SundayDedicationView> createState() => _SundayDedicationViewState();
}

class _SundayDedicationViewState extends State<SundayDedicationView>
    with SingleTickerProviderStateMixin {
  bool _showHeading = false;
  bool _showVerse = false;
  bool _showButton = false;
  bool _isDedicating = false;
  bool _isDedicated = false;
  bool _showDedicatedMessage = false;
  double _glowIntensity = 0.08;
  int _revealedTileCount = 0;

  late AnimationController _breatheController;
  late Animation<double> _breatheAnim;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _breatheAnim = Tween(begin: 0.0, end: 1.0).animate(_breatheController);
    _startEntryAnimations();
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  void _startEntryAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showHeading = true);
    });

    final habits = context.read<HabitProvider>().sortedHabits;
    for (int i = 0; i <= habits.length; i++) {
      Future.delayed(Duration(milliseconds: 800 + i * 200), () {
        if (mounted) setState(() => _revealedTileCount = i + 1);
      });
    }

    final verseDelay = 800 + habits.length * 200 + 300;
    Future.delayed(Duration(milliseconds: verseDelay), () {
      if (mounted) setState(() => _showVerse = true);
    });
    Future.delayed(Duration(milliseconds: verseDelay + 300), () {
      if (mounted) setState(() => _showButton = true);
    });
  }

  Future<void> _performDedication() async {
    setState(() {
      _isDedicating = true;
      _glowIntensity = 0.3;
    });
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    await widget.weekCycleManager.dedicateCurrentWeek();
    setState(() {
      _isDedicated = true;
      _showButton = false;
      _glowIntensity = 0.12;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _showDedicatedMessage = true);
  }

  bool get _isMidWeekStart =>
      !widget.weekCycleManager.isSunday;

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<HabitProvider>().sortedHabits;

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      body: Stack(
        children: [
          // Animated glow background
          AnimatedBuilder(
            animation: _breatheAnim,
            builder: (_, child) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    GraceWayColor.golden.withValues(alpha: _glowIntensity),
                    GraceWayColor.softGold
                        .withValues(alpha: _glowIntensity * 0.4),
                    Colors.transparent,
                  ],
                  radius: 0.7 + _breatheAnim.value * 0.1,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
                    child: _isDedicated
                        ? _postDedicationContent()
                        : _preDedicationContent(habits.toList()),
                  ),
                ),
                if (!_isDedicated && _showButton && !_isDedicating)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _performDedication,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Dedicate this week to God',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GraceWayColor.golden,
                          foregroundColor: GraceWayColor.charcoal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                if (_isDedicated && _showDedicatedMessage)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.onDismiss,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Begin your week',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GraceWayColor.golden,
                          foregroundColor: GraceWayColor.charcoal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _preDedicationContent(List<Habit> habits) {
    return Column(
      children: [
        AnimatedOpacity(
          opacity: _showHeading ? 1 : 0,
          duration: const Duration(milliseconds: 500),
          child: AnimatedSlide(
            offset: _showHeading ? Offset.zero : const Offset(0, 0.2),
            duration: const Duration(milliseconds: 500),
            child: Column(
              children: [
                if (_isMidWeekStart)
                  Text('Starting mid-week?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          color: GraceWayColor.softGold.withValues(alpha: 0.6))),
                const SizedBox(height: 6),
                Text(
                  _isMidWeekStart
                      ? 'No problem. Let\u2019s dedicate\nwhat\u2019s left of this week.'
                      : 'Set Your Week',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: GraceWayColor.warmWhite),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your habits, your purpose, your offering.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        ...habits.asMap().entries.map((e) {
          final i = e.key;
          final habit = e.value;
          final isRevealed = i < _revealedTileCount;
          return AnimatedOpacity(
            opacity: isRevealed ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: AnimatedSlide(
              offset: isRevealed ? Offset.zero : const Offset(0, 0.2),
              duration: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _dedicationHabitTile(habit),
              ),
            ),
          );
        }),
        if (habits.isNotEmpty) ...[
          AnimatedOpacity(
            opacity: _showVerse ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: _milestonePreviewSection(habits),
          ),
          const SizedBox(height: 20),
        ],
        AnimatedOpacity(
          opacity: _showVerse ? 1 : 0,
          duration: const Duration(milliseconds: 500),
          child: Column(
            children: [
              Text(
                '\u201CThe steadfast love of the Lord never ceases; his mercies never come to an end; they are new every morning.\u201D',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: GraceWayColor.softGold.withValues(alpha: 0.6),
                    height: 1.6),
              ),
              const SizedBox(height: 6),
              Text('Lamentations 3:22\u201323',
                  style: TextStyle(
                      fontSize: 11, color: GraceWayColor.golden.withValues(alpha: 0.5))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _postDedicationContent() {
    return Column(
      children: [
        const SizedBox(height: 60),
        AnimatedOpacity(
          opacity: _showDedicatedMessage ? 1 : 0,
          duration: const Duration(milliseconds: 800),
          child: AnimatedScale(
            scale: _showDedicatedMessage ? 1 : 0.92,
            duration: const Duration(milliseconds: 800),
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        GraceWayColor.golden.withValues(alpha: 0.4),
                        GraceWayColor.golden.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.auto_awesome, size: 38, color: GraceWayColor.golden),
                ),
                const SizedBox(height: 24),
                const Text('Your week is dedicated.',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: GraceWayColor.warmWhite)),
                const SizedBox(height: 8),
                const Text(
                  'God is with you in the effort and in the rest.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: GraceWayColor.softGold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dedicationHabitTile(Habit habit) {
    final accent =
        habit.trackingType == HabitTrackingType.abstain ? GraceWayColor.sage : GraceWayColor.golden;
    final verse = ScriptureLibrary.anchorVerse(habit.category);
    final summary = widget.weekCycleManager.weekProjectionSummary(habit);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: 0.25),
                      accent.withValues(alpha: 0.06),
                    ],
                  ),
                ),
                child: Icon(_habitIcon(habit), size: 22, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: GraceWayColor.warmWhite)),
                    Text(habit.purposeStatement,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
                  ],
                ),
              ),
              Text(summary,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: GraceWayColor.softGold.withValues(alpha: 0.6))),
            ],
          ),
          if (habit.isCompletedToday) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 13, color: GraceWayColor.golden),
                const SizedBox(width: 6),
                Text('Already completed today',
                    style: const TextStyle(fontSize: 12, color: GraceWayColor.sage)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '\u201C${verse.text}\u201D \u2014 ${verse.reference}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: GraceWayColor.softGold.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }

  Widget _milestonePreviewSection(List<Habit> habits) {
    final previews = habits
        .map((h) {
          final p = widget.weekCycleManager.microMilestonePreview(h);
          return p != null ? (h, p) : null;
        })
        .whereType<(Habit, String)>()
        .toList();

    if (previews.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GraceWayColor.golden.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('If you hit your targets this week:',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GraceWayColor.softGold)),
          const SizedBox(height: 12),
          ...previews.map((item) {
            final (habit, preview) = item;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 12, color: GraceWayColor.golden),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(habit.name,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: GraceWayColor.warmWhite)),
                        Text(preview,
                            style: TextStyle(
                                fontSize: 11,
                                color: GraceWayColor.softGold.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _habitIcon(Habit habit) {
    if (habit.trackingType == HabitTrackingType.abstain) return Icons.shield_rounded;
    switch (habit.category) {
      case HabitCategory.gratitude: return Icons.auto_awesome;
      case HabitCategory.scripture: return Icons.menu_book;
      case HabitCategory.exercise: return Icons.fitness_center;
      case HabitCategory.rest: return Icons.bedtime;
      case HabitCategory.fasting: return Icons.no_food;
      case HabitCategory.study: return Icons.school;
      case HabitCategory.service: return Icons.volunteer_activism;
      case HabitCategory.connection: return Icons.people;
      case HabitCategory.health: return Icons.favorite;
      case HabitCategory.abstain: return Icons.shield_rounded;
      case HabitCategory.prayer: return Icons.self_improvement_rounded;
      case HabitCategory.custom: return Icons.star;
    }
  }
}
