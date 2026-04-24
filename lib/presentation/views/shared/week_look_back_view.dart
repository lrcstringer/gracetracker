import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/habit.dart';
import '../../providers/habit_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/store_provider.dart';
import '../../../domain/services/milestone_service.dart';
import '../../../domain/services/week_cycle_manager.dart';
import '../../theme/app_theme.dart';
import 'graceway_paywall_view.dart';

class WeekLookBackView extends StatefulWidget {
  final WeekCycleManager weekCycleManager;
  final VoidCallback onDismiss;

  const WeekLookBackView({
    super.key,
    required this.weekCycleManager,
    required this.onDismiss,
  });

  @override
  State<WeekLookBackView> createState() => _WeekLookBackViewState();
}

class _WeekLookBackViewState extends State<WeekLookBackView> {
  static const _milestoneService = MilestoneService.instance;

  bool _showHeading = false;
  bool _showTile = false;
  bool _showHabits = false;
  bool _showMilestones = false;
  bool _showMessage = false;
  bool _showReflection = false;
  bool _showButton = false;
  bool _showUpgradePrompt = false;
  bool _tileGlow = false;

  bool _reflectionExpanded = false;
  bool _isSaving = false;
  final _reflectionController = TextEditingController();

  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startAnimations();
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showHeading = true);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showTile = true);
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _tileGlow = true);
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showHabits = true);
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showMilestones = true);
    });
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _showMessage = true);
    });
    Future.delayed(const Duration(milliseconds: 2650), () {
      if (mounted) setState(() => _showReflection = true);
    });
    Future.delayed(const Duration(milliseconds: 2900), () {
      if (mounted) setState(() => _showButton = true);
    });
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _showUpgradePrompt = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<HabitProvider>().sortedHabits;
    final isPremium = context.watch<StoreProvider>().isPremium;
    final prevWeekDates = widget.weekCycleManager.previousWeekDates;

    final totalCompleted = habits.fold<int>(
        0, (s, h) => s + widget.weekCycleManager.completedDays(h, prevWeekDates));
    final totalPossible = habits.length * 7;
    final ratio = totalPossible > 0 ? totalCompleted / totalPossible : 0.0;

    final tileColor = ratio >= 1.0
        ? GraceWayColor.golden
        : ratio >= 0.7
            ? GraceWayColor.golden.withValues(alpha: 0.8)
            : ratio >= 0.4
                ? GraceWayColor.softGold
                : GraceWayColor.mutedSage;

    final weekMilestones = habits.expand((h) =>
        _milestoneService.milestonesHitDuringWeek(h, prevWeekDates).map((m) => (h, m))).toList();

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
                child: Column(
                  children: [
                    // Heading
                    AnimatedOpacity(
                      opacity: _showHeading ? 1 : 0,
                      duration: const Duration(milliseconds: 500),
                      child: AnimatedSlide(
                        offset: _showHeading ? Offset.zero : const Offset(0, 0.2),
                        duration: const Duration(milliseconds: 500),
                        child: Column(
                          children: [
                            Text('Last Week',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: GraceWayColor.softGold.withValues(alpha: 0.6))),
                            const SizedBox(height: 6),
                            const Text('Your Week in Review',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: GraceWayColor.warmWhite)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Week tile
                    AnimatedOpacity(
                      opacity: _showTile ? 1 : 0,
                      duration: const Duration(milliseconds: 600),
                      child: AnimatedScale(
                        scale: _showTile ? 1 : 0.95,
                        duration: const Duration(milliseconds: 600),
                        child: _weekTile(habits.toList(), prevWeekDates, totalCompleted,
                            totalPossible, tileColor),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Habit breakdown
                    AnimatedOpacity(
                      opacity: _showHabits ? 1 : 0,
                      duration: const Duration(milliseconds: 500),
                      child: AnimatedSlide(
                        offset: _showHabits ? Offset.zero : const Offset(0, 0.15),
                        duration: const Duration(milliseconds: 500),
                        child: _habitBreakdown(habits.toList(), prevWeekDates),
                      ),
                    ),

                    // Milestones
                    if (weekMilestones.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      AnimatedOpacity(
                        opacity: _showMilestones ? 1 : 0,
                        duration: const Duration(milliseconds: 500),
                        child: AnimatedSlide(
                          offset: _showMilestones ? Offset.zero : const Offset(0, 0.15),
                          duration: const Duration(milliseconds: 500),
                          child: _milestonesSection(weekMilestones),
                        ),
                      ),
                    ],

                    // Grace message
                    AnimatedOpacity(
                      opacity: _showMessage ? 1 : 0,
                      duration: const Duration(milliseconds: 500),
                      child: _graceMessageSection(totalCompleted, totalPossible),
                    ),
                    const SizedBox(height: 28),

                    // Weekly reflection
                    _reflectionSection(),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            if (_showButton)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    if (_showUpgradePrompt && !isPremium) ...[
                      GestureDetector(
                        onTap: () => _showPaywall(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: GraceWayColor.golden.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: GraceWayColor.golden.withValues(alpha: 0.12), width: 0.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bar_chart_rounded,
                                  size: 14, color: GraceWayColor.golden),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text('See your progress over months',
                                    style: TextStyle(
                                        fontSize: 12, color: GraceWayColor.softGold)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: GraceWayColor.golden.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.workspace_premium,
                                        size: 9, color: GraceWayColor.golden),
                                    const SizedBox(width: 2),
                                    Text('PRO',
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: GraceWayColor.golden)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                setState(() => _isSaving = true);
                                final text = _reflectionController.text.trim();
                                if (text.isNotEmpty) {
                                  await context.read<JournalProvider>().saveEntry(
                                        text: jsonEncode([
                                          {'insert': '$text\n'}
                                        ]),
                                        sourceType: 'weekly_review',
                                      );
                                }
                                if (mounted) {
                                  widget.weekCycleManager.completeLookBack();
                                  widget.onDismiss();
                                }
                              },
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: GraceWayColor.charcoal,
                                ),
                              )
                            : const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Dedicate this week',
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
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _weekTile(List<Habit> habits, List<DateTime> prevWeekDates, int totalCompleted,
      int totalPossible, Color tileColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1000),
      height: 140,
      decoration: BoxDecoration(
        color: tileColor.withValues(alpha: _tileGlow ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: tileColor.withValues(alpha: _tileGlow ? 0.4 : 0.15), width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$totalCompleted',
                    style: TextStyle(
                        fontSize: 52, fontWeight: FontWeight.w800, color: tileColor, height: 1)),
                const SizedBox(width: 4),
                Text('/ $totalPossible',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.45))),
              ],
            ),
            Text('check-ins last week',
                style:
                    TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.45))),
            const SizedBox(height: 12),
            _weekDayDots(habits, prevWeekDates),
          ],
        ),
      ),
    );
  }

  Widget _weekDayDots(List<Habit> habits, List<DateTime> prevWeekDates) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: prevWeekDates.asMap().entries.map((e) {
        final i = e.key;
        final date = e.value;
        final allDone = habits.isNotEmpty &&
            habits.every((h) => h.entries.any((entry) =>
                _isSameDay(entry.date, date) && entry.isCompleted));
        final anyDone = habits.any((h) =>
            h.entries.any((entry) => _isSameDay(entry.date, date) && entry.isCompleted));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Text(_dayLabels[i],
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.4))),
              const SizedBox(height: 4),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: allDone
                      ? GraceWayColor.golden
                      : anyDone
                          ? GraceWayColor.softGold.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _habitBreakdown(List<Habit> habits, List<DateTime> prevWeekDates) {
    return Column(
      children: habits.map((h) {
        final completed = widget.weekCycleManager.completedDays(h, prevWeekDates);
        final isAbstain = h.trackingType == HabitTrackingType.abstain;
        final accent = isAbstain ? GraceWayColor.sage : GraceWayColor.golden;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: GraceWayColor.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GraceWayColor.cardBorder, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(_habitIcon(h), size: 16, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(h.name,
                      style: const TextStyle(fontSize: 14, color: GraceWayColor.warmWhite)),
                ),
                Text('$completed/7',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: completed >= 5
                            ? GraceWayColor.golden
                            : GraceWayColor.softGold.withValues(alpha: 0.5))),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _milestonesSection(List<(Habit, dynamic)> weekMilestones) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GraceWayColor.golden.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: GraceWayColor.golden.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 13, color: GraceWayColor.golden),
              const SizedBox(width: 6),
              Text('Milestones This Week',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: GraceWayColor.softGold)),
            ],
          ),
          const SizedBox(height: 12),
          ...weekMilestones.map((item) {
            final (habit, milestone) = item;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(_habitIcon(habit), size: 13, color: GraceWayColor.golden),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(milestone.message,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12, color: GraceWayColor.warmWhite)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _reflectionSection() {
    return AnimatedOpacity(
      opacity: _showReflection ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      child: AnimatedSlide(
        offset: _showReflection ? Offset.zero : const Offset(0, 0.15),
        duration: const Duration(milliseconds: 500),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() => _reflectionExpanded = !_reflectionExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: GraceWayColor.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _reflectionExpanded
                        ? GraceWayColor.golden.withValues(alpha: 0.4)
                        : GraceWayColor.cardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: GraceWayColor.golden.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Add a weekly reflection (optional)',
                        style: TextStyle(
                          fontSize: 14,
                          color: GraceWayColor.softGold.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    Icon(
                      _reflectionExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: GraceWayColor.softGold.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0, width: double.infinity),
              secondChild: _reflectionField(),
              crossFadeState: _reflectionExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reflectionField() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GraceWayColor.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.25)),
      ),
      child: TextField(
        controller: _reflectionController,
        maxLines: 6,
        minLines: 4,
        style: const TextStyle(
          fontSize: 14,
          color: GraceWayColor.warmWhite,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText:
              'What stood out this week? What are you grateful for? What do you want to carry into the week ahead?',
          hintStyle: TextStyle(
            fontSize: 13,
            color: GraceWayColor.softGold.withValues(alpha: 0.3),
            height: 1.5,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _graceMessageSection(int completed, int total) {
    final msg = widget.weekCycleManager.graceMessage(completed, total);
    return Column(
      children: [
        Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: GraceWayColor.softGold, height: 1.6),
        ),
        const SizedBox(height: 16),
        Text(
          '\u201CThe steadfast love of the Lord never ceases; his mercies never come to an end; they are new every morning.\u201D',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: GraceWayColor.softGold.withValues(alpha: 0.5),
              height: 1.6),
        ),
        const SizedBox(height: 6),
        Text('Lamentations 3:22\u201323',
            style: TextStyle(
                fontSize: 11, color: GraceWayColor.golden.withValues(alpha: 0.4))),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: GraceWayColor.charcoal,
      builder: (_) => const GraceWayPaywallView(),
    );
  }
}
