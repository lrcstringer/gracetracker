import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/habit.dart';
import '../../providers/habit_provider.dart';
import '../../providers/store_provider.dart';
import '../../../domain/services/milestone_service.dart';
import '../../theme/app_theme.dart';
import '../habits/all_habits_heatmap_view.dart';
import '../shared/graceway_paywall_view.dart';

class JourneyView extends StatefulWidget {
  const JourneyView({super.key});

  @override
  State<JourneyView> createState() => _JourneyViewState();
}

class _JourneyViewState extends State<JourneyView> {
  static const _milestoneService = MilestoneService.instance;

  int _totalGivingDays(List<Habit> habits) {
    final seen = <String>{};
    for (final habit in habits) {
      for (final entry in habit.entries.where((e) => e.isCompleted)) {
        final key = '${entry.date.year}-${entry.date.month}-${entry.date.day}';
        seen.add(key);
      }
    }
    return seen.length;
  }

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<HabitProvider>().sortedHabits;
    final isPremium = context.watch<StoreProvider>().isPremium;

    final totalGivingDays = _totalGivingDays(habits);
    final totalCheckIns = habits.fold<int>(0, (s, h) => s + h.entries.where((e) => e.isCompleted).length);
    final gratitudeDays = habits
        .where((h) => h.isBuiltIn && h.category == HabitCategory.gratitude)
        .firstOrNull
        ?.totalCompletedDays() ?? 0;

    final allMilestones = habits.expand((h) =>
        _milestoneService.milestones(h).where((m) => m.isReached).map((m) => (h, m))).toList();

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GraceWayColor.charcoal,
              title: const Text('Journey',
                  style: TextStyle(
                      color: GraceWayColor.warmWhite,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              floating: true,
              snap: true,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _heroStatSection(totalGivingDays),
                  const SizedBox(height: 20),
                  _statCardsRow(gratitudeDays, totalCheckIns, allMilestones.length),
                  const SizedBox(height: 20),
                  _heatmapSection(habits.toList(), isPremium),
                  const SizedBox(height: 20),
                  _perHabitStatsSection(habits.toList()),
                  const SizedBox(height: 20),
                  _milestonesSection(allMilestones),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroStatSection(int totalGivingDays) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                GraceWayColor.golden.withValues(alpha: 0.25),
                GraceWayColor.golden.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: const Icon(Icons.local_fire_department, size: 36, color: GraceWayColor.golden),
        ),
        const SizedBox(height: 12),
        Text(
          '$totalGivingDays',
          style: const TextStyle(
              fontSize: 56, fontWeight: FontWeight.w800, color: GraceWayColor.golden, height: 1.0),
        ),
        const SizedBox(height: 6),
        Text(
          totalGivingDays == 1 ? 'day of giving' : 'days of giving',
          style: const TextStyle(fontSize: 16, color: GraceWayColor.softGold),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _statCardsRow(int gratitudeDays, int totalCheckIns, int milestoneCount) {
    return Row(
      children: [
        Expanded(child: _statCard(Icons.auto_awesome, '$gratitudeDays', 'gratitude days', GraceWayColor.golden)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(Icons.check_circle_rounded, '$totalCheckIns', 'total check-ins', GraceWayColor.sage)),
        const SizedBox(width: 12),
        Expanded(child: _statCard(Icons.star_rounded, '$milestoneCount', 'milestones', GraceWayColor.golden)),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: GraceWayColor.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GraceWayColor.cardBorder, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.45))),
        ],
      ),
    );
  }

  Widget _perHabitStatsSection(List<Habit> habits) {
    if (habits.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded, size: 13, color: GraceWayColor.golden),
            const SizedBox(width: 6),
            Text('Habit Totals',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
          ]),
          const SizedBox(height: 14),
          ...habits.map((habit) {
            final stat = _milestoneService.lifetimeStat(habit);
            final isAbstain = habit.trackingType == HabitTrackingType.abstain;
            final accent = isAbstain ? GraceWayColor.sage : GraceWayColor.golden;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                  ),
                  child: Icon(_habitIcon(habit), size: 16, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(habit.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: GraceWayColor.warmWhite)),
                    Text(stat.description,
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                    if (stat.detail != null)
                      Text(stat.detail!,
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
                  ]),
                ),
                Text(stat.primaryValue,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: accent)),
              ]),
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

  Widget _heatmapSection(List<Habit> habits, bool isPremium) {
    if (isPremium) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: GraceWayDecorations.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Year in Grace Tracker',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.golden)),
                const Spacer(),
                Text('52 weeks',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
              ],
            ),
            const SizedBox(height: 12),
            AllHabitsHeatmapView(habits: habits, weekCount: 52),
            const SizedBox(height: 12),
            _heatmapLegend(),
          ],
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () => _openPaywall(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: GraceWayDecorations.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Year in Grace Tracker',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: GraceWayColor.softGold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: GraceWayColor.golden.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.workspace_premium, size: 10, color: GraceWayColor.golden),
                          const SizedBox(width: 3),
                          Text('PRO',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: GraceWayColor.golden)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRect(
                  child: SizedBox(
                    height: 180,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: IgnorePointer(child: AllHabitsHeatmapView(habits: habits, weekCount: 52)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 13, color: GraceWayColor.golden),
                    const SizedBox(width: 6),
                    Text('Unlock with Grace Tracker Pro',
                        style: TextStyle(fontSize: 12, color: GraceWayColor.softGold)),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 13, color: Colors.white.withValues(alpha: 0.3)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: GraceWayDecorations.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Recent Activity',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: GraceWayColor.softGold)),
                  const Spacer(),
                  Text('4 weeks',
                      style:
                          TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                ],
              ),
              const SizedBox(height: 12),
              AllHabitsHeatmapView(habits: habits, weekCount: 4),
              const SizedBox(height: 12),
              _heatmapLegend(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heatmapLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(GraceWayColor.surfaceOverlay, 'None', hasBorder: false),
        const SizedBox(width: 16),
        _legendItem(GraceWayColor.golden.withValues(alpha: 0.12), 'Some', hasBorder: true),
        const SizedBox(width: 16),
        _legendItem(GraceWayColor.golden.withValues(alpha: 0.55), 'Strong'),
        const SizedBox(width: 16),
        _legendItem(GraceWayColor.golden.withValues(alpha: 0.8), 'Full'),
      ],
    );
  }

  Widget _legendItem(Color color, String label, {bool hasBorder = false}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: hasBorder
                ? Border.all(color: GraceWayColor.golden.withValues(alpha: 0.5), width: 0.5)
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.4))),
      ],
    );
  }

  Widget _milestonesSection(List<(Habit, dynamic)> allMilestones) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 13, color: GraceWayColor.golden),
              const SizedBox(width: 6),
              Text('Milestones Earned',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: GraceWayColor.softGold)),
            ],
          ),
          const SizedBox(height: 14),
          if (allMilestones.isEmpty)
            Column(
              children: [
                const SizedBox(height: 12),
                Icon(Icons.star_outline_rounded,
                    size: 28, color: Colors.white.withValues(alpha: 0.15)),
                const SizedBox(height: 10),
                Text(
                  'Keep giving \u2014 milestones are on their way',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35)),
                ),
                const SizedBox(height: 12),
              ],
            )
          else
            ...allMilestones.map((item) {
              final (habit, milestone) = item;
              final isAbstain = habit.trackingType == HabitTrackingType.abstain;
              final accent = isAbstain ? GraceWayColor.sage : GraceWayColor.golden;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.2),
                      ),
                      child: Icon(Icons.star_rounded, size: 14, color: accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(milestone.message,
                              maxLines: 2,
                              style: const TextStyle(
                                  fontSize: 12, color: GraceWayColor.warmWhite)),
                          Text(habit.name,
                              style: TextStyle(
                                  fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle_rounded,
                        size: 14, color: accent.withValues(alpha: 0.5)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _openPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: GraceWayColor.charcoal,
      builder: (_) => const GraceWayPaywallView(),
    );
  }
}
