import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/services/daily_score_service.dart';
import '../../../domain/services/milestone_service.dart';
import '../../../domain/services/week_cycle_manager.dart';
import '../../providers/habit_provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/app_theme.dart';
import '../habits/all_habits_heatmap_view.dart';
import '../shared/graceway_paywall_view.dart';
import '../shared/appbar_actions.dart';
import '../help/progress_help_view.dart';

class ProgressView extends StatelessWidget {
  final WeekCycleManager weekCycleManager;

  const ProgressView({super.key, required this.weekCycleManager});

  static const _scoreService = DailyScoreService.instance;
  static const _milestoneService = MilestoneService.instance;
  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<HabitProvider>().sortedHabits;
    final isPremium = context.watch<StoreProvider>().isPremium;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final weekDates = weekCycleManager.currentWeekDates;
    final daysElapsed = weekDates.where((d) => !d.isAfter(todayStart)).toList();

    // ── Week stats ────────────────────────────────────────────────────────────
    final overallScore = daysElapsed.isEmpty
        ? 0.0
        : daysElapsed
                .map((d) => _scoreService.dailyScore(habits.toList(), d))
                .reduce((a, b) => a + b) /
            daysElapsed.length;
    final tier = _scoreService.tierForScore(overallScore);
    final totalCompleted = habits.fold<int>(
        0, (sum, h) => sum + weekCycleManager.completedDaysThisWeek(h));
    final totalPossible = daysElapsed.fold<int>(
        0, (sum, d) => sum + habits.where((h) => h.isActive(d)).length);

    final milestoneCallouts = habits
        .map((h) {
          final p = weekCycleManager.microMilestonePreview(h);
          return p != null ? (h, p) : null;
        })
        .whereType<(Habit, String)>()
        .toList();

    // ── Journey stats ─────────────────────────────────────────────────────────
    final totalGivingDays = _totalGivingDays(habits.toList());
    final totalCheckIns = habits.fold<int>(
        0, (s, h) => s + h.entries.where((e) => e.isCompleted).length);
    final gratitudeDays = habits
            .where((h) => h.isBuiltIn && h.category == HabitCategory.gratitude)
            .firstOrNull
            ?.totalCompletedDays() ??
        0;
    final milestoneCount = habits
        .expand((h) => _milestoneService.milestones(h).where((m) => m.isReached))
        .length;
    final prayersAnswered = habits
        .where((h) => h.hasPrayerItems)
        .expand((h) => h.prayerItems)
        .where((p) => p.status == PrayerItemStatus.answered)
        .length;

    final imageHeight = MediaQuery.of(context).size.width * (2.0 / 3.0);

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      body: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: GraceWayColor.charcoal,
              foregroundColor: GraceWayColor.warmWhite,
              expandedHeight: imageHeight,
              pinned: true,
              automaticallyImplyLeading: false,
              title: const Text(
                'Grace Tracker',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              actions: [
                ...standardAppBarActions(context, helpView: const ProgressHelpView()),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/progress.png',
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            GraceWayColor.charcoal.withValues(alpha: 0.5),
                            GraceWayColor.charcoal,
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 20,
                      right: 20,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: GraceWayColor.warmWhite,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            '\u2018\u2026being confident of this, that he who began a good work in you will carry it on to completion\u2019',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: GraceWayColor.softGold,
                              height: 1.45,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Philippians 1:6',
                            style: TextStyle(
                              fontSize: 11,
                              color: GraceWayColor.golden,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Journey hero ────────────────────────────────────────────
                  _heroStat(totalGivingDays),
                  const SizedBox(height: 16),

                  // ── Journey stat cards ──────────────────────────────────────
                  _statCardsRow(gratitudeDays, totalCheckIns, milestoneCount),
                  if (prayersAnswered > 0) ...[
                    const SizedBox(height: 12),
                    _prayersAnsweredCard(prayersAnswered),
                  ],
                  const SizedBox(height: 24),

                  // ── Week summary ────────────────────────────────────────────
                  _weekHeader(tier, totalCompleted, totalPossible),
                  if (milestoneCallouts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _milestoneCallouts(milestoneCallouts),
                  ],
                  const SizedBox(height: 24),

                  // ── Week grid ───────────────────────────────────────────────
                  _weekGrid(habits.toList(), weekDates, todayStart),
                  const SizedBox(height: 24),

                  // ── Heatmap ─────────────────────────────────────────────────
                  _heatmapSection(habits.toList(), isPremium, context),
                ]),
              ),
            ),
          ],
      ),
    );
  }

  // ── Journey hero ────────────────────────────────────────────────────────────

  int _totalGivingDays(List<Habit> habits) {
    final seen = <String>{};
    for (final h in habits) {
      for (final e in h.entries.where((e) => e.isCompleted)) {
        seen.add('${e.date.year}-${e.date.month}-${e.date.day}');
      }
    }
    return seen.length;
  }

  Widget _heroStat(int days) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text('$days',
            style: const TextStyle(
                fontSize: 56, fontWeight: FontWeight.w800, color: GraceWayColor.golden, height: 1.0)),
        const SizedBox(height: 6),
        Text(days == 1 ? 'day of giving' : 'days of giving',
            style: const TextStyle(fontSize: 16, color: GraceWayColor.softGold)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _statCardsRow(int gratitudeDays, int checkIns, int milestones) {
    return Row(children: [
      Expanded(child: _statCard(Icons.auto_awesome, '$gratitudeDays', 'gratitude days', GraceWayColor.golden)),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.check_circle_rounded, '$checkIns', 'total check-ins', GraceWayColor.sage)),
      const SizedBox(width: 12),
      Expanded(child: _statCard(Icons.star_rounded, '$milestones', 'milestones', GraceWayColor.golden)),
    ]);
  }

  Widget _prayersAnsweredCard(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: GraceWayColor.sage.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GraceWayColor.sage.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(children: [
        Icon(Icons.volunteer_activism_rounded, size: 20, color: GraceWayColor.sage),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite)),
          Text(count == 1 ? 'prayer answered' : 'prayers answered',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w500, color: GraceWayColor.sage.withValues(alpha: 0.8))),
        ]),
        const Spacer(),
        Text('Testimony', style: TextStyle(fontSize: 11, color: GraceWayColor.sage.withValues(alpha: 0.5))),
      ]),
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
      child: Column(children: [
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
      ]),
    );
  }

  // ── Week summary ─────────────────────────────────────────────────────────────

  Widget _weekHeader(DayTier tier, int completed, int possible) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('This Week',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4),
              letterSpacing: 1.2)),
      const SizedBox(height: 14),
      Row(children: [
        SizedBox(width: 52, height: 52, child: _tierIndicator(tier)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_tierLabel(tier),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite)),
            Text(weekCycleManager.graceMessage(completed, possible),
                style: const TextStyle(fontSize: 12, color: GraceWayColor.sage)),
          ]),
        ),
      ]),
    ]);
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
          child: Center(child: Icon(Icons.check, size: 16, color: GraceWayColor.golden.withValues(alpha: 0.7))),
        );
      case DayTier.substantial:
        return Container(
          decoration: const BoxDecoration(shape: BoxShape.circle, color: GraceWayColor.golden),
          child: const Center(child: Icon(Icons.check, size: 18, color: GraceWayColor.charcoal)),
        );
      case DayTier.full:
        return Stack(alignment: Alignment.center, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.45), width: 1.5),
            ),
          ),
          Container(
            width: 52, height: 52,
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
        ]);
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
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.auto_awesome, size: 11, color: GraceWayColor.golden),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(habit.name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
                  Text(preview,
                      style: TextStyle(
                          fontSize: 11, color: GraceWayColor.softGold.withValues(alpha: 0.7))),
                ]),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  // ── Week per-habit dot grid ──────────────────────────────────────────────────

  Widget _weekGrid(List<Habit> habits, List<DateTime> weekDates, DateTime todayStart) {
    if (habits.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(
        children: habits.map((h) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Icon(_habitIcon(h), size: 14, color: h.trackingType == HabitTrackingType.abstain
                  ? GraceWayColor.sage : GraceWayColor.golden),
              const SizedBox(width: 8),
              Expanded(
                child: Text(h.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: GraceWayColor.warmWhite),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Row(
                children: weekDates.asMap().entries.map((e) {
                  final date = e.value;
                  final isFuture = date.isAfter(todayStart);
                  final isToday = date.year == todayStart.year &&
                      date.month == todayStart.month &&
                      date.day == todayStart.day;
                  final isActive = h.isActive(date);
                  final score = isActive ? _scoreService.habitScore(h, date) : -1.0;
                  final tileTier = _scoreService.tierForScore(score.clamp(0.0, 1.0));
                  final accent = h.trackingType == HabitTrackingType.abstain
                      ? GraceWayColor.sage : GraceWayColor.golden;

                  return Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Column(children: [
                      Text(_dayLabels[e.key],
                          style: TextStyle(
                              fontSize: 9,
                              color: isToday ? GraceWayColor.softGold : Colors.white.withValues(alpha: 0.3))),
                      const SizedBox(height: 4),
                      _dot(isActive, isFuture, isToday, tileTier, accent),
                    ]),
                  );
                }).toList(),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _dot(bool isActive, bool isFuture, bool isToday, DayTier tier, Color accent) {
    const size = 20.0;
    if (!isActive) {
      return SizedBox(width: size, height: size,
          child: Center(child: Text('–', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.12)))));
    }
    if (isFuture) {
      return Container(width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.03)));
    }
    switch (tier) {
      case DayTier.nothing:
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isToday ? GraceWayColor.golden.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
              width: isToday ? 1.5 : 1,
            ),
          ),
        );
      case DayTier.partial:
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Center(child: Icon(Icons.check, size: 10, color: accent.withValues(alpha: 0.7))),
        );
      case DayTier.substantial:
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          child: const Center(child: Icon(Icons.check, size: 11, color: GraceWayColor.charcoal)),
        );
      case DayTier.full:
        return Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent,
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 6)],
          ),
          child: const Center(child: Icon(Icons.check, size: 11, color: GraceWayColor.charcoal)),
        );
    }
  }

  // ── Heatmap ──────────────────────────────────────────────────────────────────

  Widget _heatmapSection(List<Habit> habits, bool isPremium, BuildContext context) {
    if (isPremium) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: GraceWayDecorations.card,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Year in Grace Tracker',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.golden)),
            const Spacer(),
            Text('52 weeks',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          ]),
          const SizedBox(height: 12),
          AllHabitsHeatmapView(habits: habits, weekCount: 52),
          const SizedBox(height: 12),
          _heatmapLegend(),
        ]),
      );
    }

    return Column(children: [
      GestureDetector(
        onTap: () => _openPaywall(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: GraceWayDecorations.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Year in Grace Tracker',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GraceWayColor.golden.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.workspace_premium, size: 10, color: GraceWayColor.golden),
                  const SizedBox(width: 3),
                  const Text('PRO',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: GraceWayColor.golden)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            ClipRect(
              child: SizedBox(
                height: 140,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: IgnorePointer(child: AllHabitsHeatmapView(habits: habits, weekCount: 52)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.lock_outline, size: 13, color: GraceWayColor.golden),
              const SizedBox(width: 6),
              const Text('Unlock with Grace Tracker Pro',
                  style: TextStyle(fontSize: 12, color: GraceWayColor.softGold)),
              const Spacer(),
              Icon(Icons.chevron_right, size: 13, color: Colors.white.withValues(alpha: 0.3)),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: GraceWayDecorations.card,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Recent Activity',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
            const Spacer(),
            Text('4 weeks',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
          ]),
          const SizedBox(height: 12),
          AllHabitsHeatmapView(habits: habits, weekCount: 4),
          const SizedBox(height: 12),
          _heatmapLegend(),
        ]),
      ),
    ]);
  }

  Widget _heatmapLegend() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _legendItem(GraceWayColor.surfaceOverlay, 'None'),
      const SizedBox(width: 16),
      _legendItem(GraceWayColor.golden.withValues(alpha: 0.12), 'Some', hasBorder: true),
      const SizedBox(width: 16),
      _legendItem(GraceWayColor.golden.withValues(alpha: 0.55), 'Strong'),
      const SizedBox(width: 16),
      _legendItem(GraceWayColor.golden.withValues(alpha: 0.8), 'Full'),
    ]);
  }

  Widget _legendItem(Color color, String label, {bool hasBorder = false}) {
    return Row(children: [
      Container(
        width: 10, height: 10,
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
    ]);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

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
