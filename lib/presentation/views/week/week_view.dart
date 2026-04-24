import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/habit.dart';
import '../../providers/habit_provider.dart';
import '../../../domain/services/daily_score_service.dart';
import '../../../domain/services/week_cycle_manager.dart';
import '../../theme/app_theme.dart';

class WeekView extends StatelessWidget {
  final WeekCycleManager weekCycleManager;

  const WeekView({super.key, required this.weekCycleManager});

  static const _scoreService = DailyScoreService.instance;
  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<HabitProvider>().sortedHabits;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final weekDates = weekCycleManager.currentWeekDates;
    final daysElapsed = weekDates.where((d) => !d.isAfter(todayStart)).toList();

    final overallScore = daysElapsed.isEmpty
        ? 0.0
        : daysElapsed.map((d) => _scoreService.dailyScore(habits.toList(), d)).reduce((a, b) => a + b) /
            daysElapsed.length;
    final tier = _scoreService.tierForScore(overallScore);

    final totalCompleted = habits.fold<int>(0, (sum, h) => sum + weekCycleManager.completedDaysThisWeek(h));
    final totalPossible = daysElapsed.fold<int>(
        0, (sum, d) => sum + habits.where((h) => h.isActive(d)).length);

    final previews = habits
        .map((h) {
          final preview = weekCycleManager.microMilestonePreview(h);
          return preview != null ? (h, preview) : null;
        })
        .whereType<(Habit, String)>()
        .toList();

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GraceWayColor.charcoal,
              title: const Text('This Week',
                  style: TextStyle(
                      color: GraceWayColor.warmWhite, fontSize: 22, fontWeight: FontWeight.w700)),
              floating: true,
              snap: true,
              pinned: false,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _weekSummaryHeader(tier, totalCompleted, totalPossible),
                  const SizedBox(height: 20),
                  if (previews.isNotEmpty) ...[
                    _milestoneCallouts(previews),
                    const SizedBox(height: 20),
                  ],
                  ...habits.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _habitWeekCard(h, weekDates, todayStart),
                      )),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekSummaryHeader(DayTier tier, int completed, int possible) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Your Week So Far',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
        const SizedBox(height: 14),
        Row(
          children: [
            SizedBox(width: 52, height: 52, child: _tierIndicator(tier)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tierLabel(tier),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite),
                  ),
                  Text(
                    weekCycleManager.graceMessage(completed, possible),
                    style: const TextStyle(fontSize: 12, color: GraceWayColor.sage),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tierIndicator(DayTier tier) {
    switch (tier) {
      case DayTier.nothing:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
          ),
        );
      case DayTier.partial:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.6), width: 2),
          ),
          child: Center(
            child: Icon(Icons.check, size: 16, color: GraceWayColor.golden.withValues(alpha: 0.7)),
          ),
        );
      case DayTier.substantial:
        return Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: GraceWayColor.golden),
          child: const Center(child: Icon(Icons.check, size: 18, color: GraceWayColor.charcoal)),
        );
      case DayTier.full:
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.45), width: 1.5),
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GraceWayColor.golden,
                boxShadow: [
                  BoxShadow(color: GraceWayColor.golden.withValues(alpha: 0.7), blurRadius: 14),
                  BoxShadow(color: GraceWayColor.golden.withValues(alpha: 0.35), blurRadius: 5),
                ],
              ),
              child: const Center(child: Icon(Icons.check, size: 18, color: GraceWayColor.charcoal)),
            ),
          ],
        );
    }
  }

  String _tierLabel(DayTier tier) {
    switch (tier) {
      case DayTier.nothing: return 'Just getting started';
      case DayTier.partial: return 'Something given';
      case DayTier.substantial: return 'Strong week';
      case DayTier.full: return 'Beautiful week';
    }
  }

  Widget _milestoneCallouts(List<(Habit, String)> previews) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GraceWayColor.golden.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: previews.map((item) {
          final (habit, preview) = item;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 11, color: GraceWayColor.golden),
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
        }).toList(),
      ),
    );
  }

  Widget _habitWeekCard(Habit habit, List<DateTime> weekDates, DateTime todayStart) {
    final isAbstain = habit.trackingType == HabitTrackingType.abstain;
    final accent = isAbstain ? GraceWayColor.sage : GraceWayColor.golden;
    final daysElapsed = weekDates.where((d) => !d.isAfter(todayStart)).toList();
    final milestone = weekCycleManager.microMilestonePreview(habit);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_habitIcon(habit), size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(habit.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: GraceWayColor.warmWhite)),
              ),
              Text(_weekSummaryText(habit, daysElapsed),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: GraceWayColor.softGold.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: weekDates.asMap().entries.map((e) {
              final i = e.key;
              final date = e.value;
              final isFuture = date.isAfter(todayStart);
              final isToday = date.year == todayStart.year &&
                  date.month == todayStart.month &&
                  date.day == todayStart.day;
              final isActive = habit.isActive(date);
              final score = isActive ? _scoreService.habitScore(habit, date) : -1.0;
              final tileTier = _scoreService.tierForScore(score.clamp(0.0, 1.0));

              return Expanded(
                child: Column(
                  children: [
                    Text(_dayLabels[i],
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isToday
                                ? GraceWayColor.softGold
                                : Colors.white.withValues(alpha: 0.4))),
                    const SizedBox(height: 6),
                    _habitDayTile(habit, isActive, isFuture, isToday, tileTier, accent),
                  ],
                ),
              );
            }).toList(),
          ),
          if (milestone != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 11, color: GraceWayColor.golden),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(milestone,
                      style: TextStyle(
                          fontSize: 11,
                          color: GraceWayColor.softGold.withValues(alpha: 0.6))),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _habitDayTile(
      Habit habit, bool isActive, bool isFuture, bool isToday, DayTier tier, Color accent) {
    if (!isActive) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Text('\u2013',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.15))),
        ),
      );
    }
    if (isFuture) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.03)),
      );
    }
    final isAbstain = habit.trackingType == HabitTrackingType.abstain;
    final icon = isAbstain ? Icons.shield_rounded : Icons.check;

    switch (tier) {
      case DayTier.nothing:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isToday
                  ? GraceWayColor.golden.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
              width: isToday ? 1.5 : 1,
            ),
          ),
        );
      case DayTier.partial:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Center(child: Icon(icon, size: 13, color: accent.withValues(alpha: 0.7))),
        );
      case DayTier.substantial:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          child: Center(child: Icon(icon, size: 14, color: GraceWayColor.charcoal)),
        );
      case DayTier.full:
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 10)],
              ),
              child: Center(child: Icon(icon, size: 14, color: GraceWayColor.charcoal)),
            ),
          ],
        );
    }
  }

  String _weekSummaryText(Habit habit, List<DateTime> daysElapsed) {
    final activeDays = daysElapsed.where((d) => habit.isActive(d)).toList();
    final count = activeDays.length;

    switch (habit.trackingType) {
      case HabitTrackingType.timed:
        final total = activeDays.fold<double>(0, (s, d) => s + (habit.entryFor(d)?.value ?? 0));
        final target = habit.dailyTarget * count;
        return '${total.toInt()} / ${target.toInt()} min';
      case HabitTrackingType.count:
        final total = activeDays.fold<double>(0, (s, d) => s + (habit.entryFor(d)?.value ?? 0));
        final target = habit.dailyTarget * count;
        final unit = habit.targetUnit.isEmpty ? '' : ' ${habit.targetUnit}';
        return '${total.toInt()} / ${target.toInt()}$unit';
      case HabitTrackingType.checkIn:
        final done = activeDays.where((d) => habit.isCompleted(d)).length;
        return '$done / $count days';
      case HabitTrackingType.abstain:
        final done = activeDays.where((d) => habit.isCompleted(d)).length;
        return '$done / $count days clean';
    }
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
