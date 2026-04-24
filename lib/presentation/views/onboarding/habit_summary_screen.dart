import 'package:flutter/material.dart';
import '../../../domain/entities/habit.dart';
import '../../theme/app_theme.dart';

class HabitSummaryScreen extends StatefulWidget {
  final String habitName;
  final HabitCategory habitCategory;
  final HabitTrackingType trackingType;
  final String purposeStatement;
  final double dailyTarget;
  final String targetUnit;
  final Set<int> activeDays;
  final VoidCallback onFinish;

  const HabitSummaryScreen({
    super.key,
    required this.habitName,
    required this.habitCategory,
    required this.trackingType,
    required this.purposeStatement,
    required this.dailyTarget,
    required this.targetUnit,
    required this.activeDays,
    required this.onFinish,
  });

  @override
  State<HabitSummaryScreen> createState() => _HabitSummaryScreenState();
}

class _HabitSummaryScreenState extends State<HabitSummaryScreen> {
  bool _showGratitude = false;
  bool _showCustom = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showGratitude = true);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showCustom = true);
    });
  }

  Color get _accentColor =>
      widget.habitCategory == HabitCategory.abstain ? GraceWayColor.warmCoral : GraceWayColor.golden;

  String get _trackingDescription {
    switch (widget.trackingType) {
      case HabitTrackingType.timed:
        return '${widget.dailyTarget.toInt()} ${widget.targetUnit}/day';
      case HabitTrackingType.count:
        return widget.targetUnit.isEmpty
            ? '${widget.dailyTarget.toInt()} per day'
            : '${widget.dailyTarget.toInt()} ${widget.targetUnit}/day';
      case HabitTrackingType.checkIn:
        return 'Daily check-in';
      case HabitTrackingType.abstain:
        return 'Confirm daily';
    }
  }

  String get _activeDaysSummary {
    const names = {1: 'Sun', 2: 'Mon', 3: 'Tue', 4: 'Wed', 5: 'Thu', 6: 'Fri', 7: 'Sat'};
    final sorted = widget.activeDays.toList()..sort();
    return sorted.map((d) => names[d] ?? '').join(', ');
  }

  IconData _categoryIcon() {
    switch (widget.habitCategory) {
      case HabitCategory.exercise: return Icons.fitness_center;
      case HabitCategory.scripture: return Icons.menu_book;
      case HabitCategory.rest: return Icons.bedtime;
      case HabitCategory.fasting: return Icons.no_food;
      case HabitCategory.study: return Icons.school;
      case HabitCategory.service: return Icons.volunteer_activism;
      case HabitCategory.connection: return Icons.people;
      case HabitCategory.health: return Icons.favorite;
      case HabitCategory.abstain: return Icons.shield_rounded;
      default: return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Your GraceWay habits',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite)),
            const SizedBox(height: 10),
            Text('Looks good? You can change any of this later.',
                style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5))),
            const SizedBox(height: 24),
            AnimatedOpacity(
              opacity: _showGratitude ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: AnimatedSlide(
                offset: _showGratitude ? Offset.zero : const Offset(0, 0.2),
                duration: const Duration(milliseconds: 400),
                child: _habitTile(
                  icon: Icons.volunteer_activism,
                  name: 'Daily Gratitude',
                  trackingText: 'Check-in',
                  purposeText: 'Already completed today',
                  purposeColor: GraceWayColor.golden.withValues(alpha: 0.7),
                  accent: GraceWayColor.golden,
                  accentBg: GraceWayColor.golden.withValues(alpha: 0.06),
                  borderColor: GraceWayColor.golden.withValues(alpha: 0.2),
                  showCheck: true,
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedOpacity(
              opacity: _showCustom ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: AnimatedSlide(
                offset: _showCustom ? Offset.zero : const Offset(0, 0.2),
                duration: const Duration(milliseconds: 400),
                child: _habitTile(
                  icon: _categoryIcon(),
                  name: widget.habitName,
                  trackingText: _trackingDescription,
                  purposeText: widget.purposeStatement,
                  purposeColor: Colors.white.withValues(alpha: 0.5),
                  accent: _accentColor,
                  accentBg: GraceWayColor.cardBackground,
                  borderColor: GraceWayColor.cardBorder,
                  showCheck: false,
                  activeDaysSummary: widget.activeDays.length < 7 ? _activeDaysSummary : null,
                ),
              ),
            ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onFinish,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text("Let\u2019s go",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: GraceWayColor.golden,
              foregroundColor: GraceWayColor.charcoal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _habitTile({
    required IconData icon,
    required String name,
    required String trackingText,
    required String purposeText,
    required Color purposeColor,
    required Color accent,
    required Color accentBg,
    required Color borderColor,
    required bool showCheck,
    String? activeDaysSummary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              accent.withValues(alpha: 0.35),
              accent.withValues(alpha: 0.12),
            ]),
          ),
          child: Icon(icon, size: 22, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
              if (showCheck) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded, size: 16, color: GraceWayColor.golden),
              ],
            ]),
            const SizedBox(height: 4),
            Text(trackingText, style: const TextStyle(fontSize: 12, color: GraceWayColor.sage)),
            const SizedBox(height: 2),
            Text(purposeText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: purposeColor)),
            if (activeDaysSummary != null) ...[
              const SizedBox(height: 2),
              Text(activeDaysSummary,
                  style: TextStyle(fontSize: 11, color: GraceWayColor.softGold.withValues(alpha: 0.5))),
            ],
          ]),
        ),
      ]),
    );
  }
}
