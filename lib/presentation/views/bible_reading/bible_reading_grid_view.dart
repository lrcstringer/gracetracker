import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/services/bible_reading_plan_data.dart';
import '../../../domain/entities/bible_reading_plan.dart';
import '../../providers/bible_reading_provider.dart';
import '../../theme/app_theme.dart';
import 'bible_reading_day_modal.dart';
import 'bible_reading_milestone_screen.dart';

class BibleReadingGridView extends StatefulWidget {
  const BibleReadingGridView({super.key});

  @override
  State<BibleReadingGridView> createState() => _BibleReadingGridViewState();
}

class _BibleReadingGridViewState extends State<BibleReadingGridView> {
  late final ScrollController _scrollController;
  // Track which weeks are expanded; current week auto-expands.
  final Set<int> _expanded = {};
  bool _initialScrollDone = false;
  // Keys for each week header so we can scroll to the current one.
  final Map<int, GlobalKey> _weekKeys = {};
  // Session-local guard: milestone week indices already shown this session.
  // A Set (not a bool) prevents re-push both while navigation is in-flight AND
  // during the window between markMilestoneShown() and Firestore stream confirmation.
  final Set<int> _localShownMilestones = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentWeek(int weekIndex) {
    if (_initialScrollDone) return;
    _initialScrollDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _weekKeys[weekIndex];
      if (key?.currentContext == null) return;
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BibleReadingProvider>();

    // Auto-expand current week.
    final currentWeek = provider.currentWeekIndex;
    if (currentWeek != null && !_expanded.contains(currentWeek)) {
      _expanded.add(currentWeek);
      _scrollToCurrentWeek(currentWeek);
    }

    // Check for pending milestone after build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkMilestone(context));

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        foregroundColor: GraceWayColor.warmWhite,
        title: const Text('Bible in a Year'),
        actions: [
          if (provider.isActive && currentWeek != null)
            TextButton(
              onPressed: () => _openCurrentDayModal(context, provider),
              child: const Text(
                'Continue',
                style: TextStyle(color: GraceWayColor.golden, fontSize: 13),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _ProgressHeader(provider: provider),
          if (provider.isPending) _PendingBanner(provider: provider),
          Expanded(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: GraceWayColor.golden),
                  )
                : provider.isNotStarted
                    ? _NotStartedView(onStart: () => _startPlan(context, provider))
                    : _WeekList(
                        provider: provider,
                        expanded: _expanded,
                        weekKeys: _weekKeys,
                        onToggle: (w) => setState(() {
                          if (_expanded.contains(w)) {
                            _expanded.remove(w);
                          } else {
                            _expanded.add(w);
                          }
                        }),
                        onDayTap: (w, d) => _openDayModal(context, w, d),
                        scrollController: _scrollController,
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPlan(BuildContext context, BibleReadingProvider provider) async {
    await provider.startPlan();
  }

  void _openCurrentDayModal(BuildContext context, BibleReadingProvider provider) {
    final w = provider.currentWeekIndex!;
    final d = provider.currentDayIndex!;
    _openDayModal(context, w, d);
  }

  void _openDayModal(BuildContext context, int weekIndex, int dayIndex) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BibleReadingDayModal(
        weekIndex: weekIndex,
        dayIndex: dayIndex,
      ),
    );
  }

  void _checkMilestone(BuildContext context) {
    if (!mounted) return;
    final provider = context.read<BibleReadingProvider>();
    final milestone = provider.pendingMilestone();
    if (milestone == null || _localShownMilestones.contains(milestone)) return;
    _localShownMilestones.add(milestone);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BibleReadingMilestoneScreen(weekIndex: milestone),
        fullscreenDialog: true,
      ),
    ).then((_) {
      provider.markMilestoneShown(milestone);
    });
  }
}

// ── Progress header ────────────────────────────────────────────────────────────

class _ProgressHeader extends StatelessWidget {
  final BibleReadingProvider provider;
  const _ProgressHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.isActive) return const SizedBox.shrink();
    final weekIndex = provider.currentWeekIndex ?? 0;
    final daysRead = provider.totalDaysRead;
    final progress = daysRead / 364.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: GraceWayColor.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Week ${weekIndex + 1} of 52',
                style: const TextStyle(
                  color: GraceWayColor.warmWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$daysRead days read',
                style: TextStyle(
                  color: GraceWayColor.softGold.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: GraceWayColor.golden.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(GraceWayColor.golden),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pending banner ─────────────────────────────────────────────────────────────

class _PendingBanner extends StatelessWidget {
  final BibleReadingProvider provider;
  const _PendingBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    final state = provider.state!;
    final liveDate = state.liveDate!;
    final days = provider.daysUntilLive ?? 0;
    final dateStr = DateFormat('MMMM d').format(liveDate);
    final countdown = days == 0
        ? 'Your plan begins this Sunday.'
        : 'Your plan begins Sunday, $dateStr — $days ${days == 1 ? 'day' : 'days'} away.';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: GraceWayColor.golden.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: GraceWayColor.golden.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: GraceWayColor.golden, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              countdown,
              style: const TextStyle(color: GraceWayColor.softGold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Not started ────────────────────────────────────────────────────────────────

class _NotStartedView extends StatelessWidget {
  final VoidCallback onStart;
  const _NotStartedView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded, color: GraceWayColor.golden, size: 48),
            const SizedBox(height: 20),
            const Text(
              'Bible in a Year',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GraceWayColor.warmWhite,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A balanced daily reading plan covering all 66 books — Psalms, New Testament, Torah, Historical, Prophetic, and Wisdom literature.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GraceWayColor.softGold.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: GraceWayColor.golden,
                foregroundColor: GraceWayColor.charcoal,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Plan',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Week list ──────────────────────────────────────────────────────────────────

class _WeekList extends StatelessWidget {
  final BibleReadingProvider provider;
  final Set<int> expanded;
  final Map<int, GlobalKey> weekKeys;
  final void Function(int) onToggle;
  final void Function(int, int) onDayTap;
  final ScrollController scrollController;

  const _WeekList({
    required this.provider,
    required this.expanded,
    required this.weekKeys,
    required this.onToggle,
    required this.onDayTap,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final currentWeek = provider.currentWeekIndex;
    final weeks = BibleReadingPlanData.weeks;

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: weeks.length,
      itemBuilder: (context, w) {
        weekKeys[w] ??= GlobalKey();
        return _WeekAccordion(
          key: weekKeys[w],
          weekIndex: w,
          provider: provider,
          isExpanded: expanded.contains(w),
          isCurrent: w == currentWeek,
          onToggle: () => onToggle(w),
          onDayTap: (d) => onDayTap(w, d),
        );
      },
    );
  }
}

// ── Week accordion ─────────────────────────────────────────────────────────────

class _WeekAccordion extends StatelessWidget {
  final int weekIndex;
  final BibleReadingProvider provider;
  final bool isExpanded;
  final bool isCurrent;
  final VoidCallback onToggle;
  final void Function(int) onDayTap;

  const _WeekAccordion({
    super.key,
    required this.weekIndex,
    required this.provider,
    required this.isExpanded,
    required this.isCurrent,
    required this.onToggle,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final state = provider.state;
    final weekDays = BibleReadingPlanData.weeks[weekIndex];
    final daysComplete = state == null
        ? 0
        : weekDays.asMap().entries
            .where((e) => state.isDayDone(weekIndex, e.key, e.value))
            .length;
    final isWeekDone = daysComplete == weekDays.length;
    final summary = _weekSummary(weekIndex);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: GraceWayColor.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? GraceWayColor.golden.withValues(alpha: 0.4)
              : GraceWayColor.cardBorder,
          width: isCurrent ? 1.0 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  // Week number badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isWeekDone
                          ? GraceWayColor.sage.withValues(alpha: 0.25)
                          : isCurrent
                              ? GraceWayColor.golden.withValues(alpha: 0.15)
                              : GraceWayColor.surfaceOverlay,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: isWeekDone
                          ? const Icon(Icons.check, color: GraceWayColor.sage, size: 16)
                          : Text(
                              '${weekIndex + 1}',
                              style: TextStyle(
                                color: isCurrent
                                    ? GraceWayColor.golden
                                    : GraceWayColor.softGold,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Week ${weekIndex + 1}',
                          style: TextStyle(
                            color: isCurrent
                                ? GraceWayColor.warmWhite
                                : GraceWayColor.softGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (summary.isNotEmpty)
                          Text(
                            summary,
                            style: TextStyle(
                              color:
                                  GraceWayColor.softGold.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '$daysComplete/7',
                    style: TextStyle(
                      color: GraceWayColor.softGold.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: GraceWayColor.softGold.withValues(alpha: 0.5),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          // Rows
          if (isExpanded)
            Column(
              children: [
                Divider(
                  height: 1,
                  color: GraceWayColor.cardBorder,
                ),
                ...List.generate(weekDays.length, (d) {
                  return _DayRow(
                    weekIndex: weekIndex,
                    dayIndex: d,
                    provider: provider,
                    onTap: () => onDayTap(d),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  String _weekSummary(int w) {
    // Brief list of first book names encountered across the week's NT and Torah columns.
    final days = BibleReadingPlanData.weeks[w];
    final books = <String>{};
    for (final day in days) {
      for (final s in BibleReadingSection.ordered) {
        final refs = day.refsForSection(s);
        if (refs.isNotEmpty) {
          // Extract book name: label like "Gen 1" → "Gen"
          final label = refs.first.label;
          final space = label.indexOf(' ');
          if (space > 0) books.add(label.substring(0, space));
          if (books.length >= 4) break;
        }
      }
      if (books.length >= 4) break;
    }
    return books.join(' · ');
  }
}

// ── Day row ────────────────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final int weekIndex;
  final int dayIndex;
  final BibleReadingProvider provider;
  final VoidCallback onTap;

  const _DayRow({
    required this.weekIndex,
    required this.dayIndex,
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final state = provider.state;
    final dayPlan = BibleReadingPlanData.weeks[weekIndex][dayIndex];
    final isDone = state?.isDayDone(weekIndex, dayIndex, dayPlan) ?? false;
    final isCurrent = provider.currentWeekIndex == weekIndex &&
        provider.currentDayIndex == dayIndex;
    final dayName = BibleReadingPlanData.dayNames[dayIndex];
    final summary = dayPlan.abbreviatedSummary;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isDone
              ? GraceWayColor.sage.withValues(alpha: 0.07)
              : isCurrent
                  ? GraceWayColor.golden.withValues(alpha: 0.04)
                  : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: GraceWayColor.cardBorder,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Done / current indicator
            SizedBox(
              width: 20,
              child: isDone
                  ? const Icon(Icons.check_circle,
                      color: GraceWayColor.sage, size: 16)
                  : isCurrent
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: GraceWayColor.golden,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
            ),
            const SizedBox(width: 6),
            // Day name
            SizedBox(
              width: 30,
              child: Text(
                dayName,
                style: TextStyle(
                  color: isCurrent
                      ? GraceWayColor.warmWhite
                      : GraceWayColor.softGold,
                  fontSize: 12,
                  fontWeight:
                      isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Summary
            Expanded(
              child: Text(
                summary,
                style: TextStyle(
                  color: isDone
                      ? GraceWayColor.sage.withValues(alpha: 0.8)
                      : GraceWayColor.softGold.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right,
                color: GraceWayColor.softGold, size: 14),
          ],
        ),
      ),
    );
  }
}
