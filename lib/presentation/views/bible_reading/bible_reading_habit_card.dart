import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/bible_reading_plan.dart';
import '../../providers/bible_reading_provider.dart';
import '../../theme/app_theme.dart';
import 'bible_reading_grid_view.dart';

class BibleReadingHabitCard extends StatelessWidget {
  const BibleReadingHabitCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BibleReadingProvider>();

    // Only surface the card once the user has started the plan.
    // Discovery happens via the Kingdom Life Premium section.
    if (provider.isNotStarted) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const BibleReadingGridView()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: GraceWayColor.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: GraceWayColor.golden.withValues(alpha: 0.25),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(provider: provider),
              const SizedBox(height: 10),
              _Body(provider: provider),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final BibleReadingProvider provider;
  const _Header({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.menu_book_rounded, color: GraceWayColor.golden, size: 18),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Bible in a Year',
            style: TextStyle(
              color: GraceWayColor.warmWhite,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Icon(Icons.chevron_right, color: GraceWayColor.softGold, size: 20),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final BibleReadingProvider provider;
  const _Body({required this.provider});

  @override
  Widget build(BuildContext context) {
    switch (provider.status) {
      case BibleReadingPlanStatus.notStarted:
        return _NotStartedBody();
      case BibleReadingPlanStatus.pending:
        return _PendingBody(provider: provider);
      case BibleReadingPlanStatus.active:
        return _ActiveBody(provider: provider);
    }
  }
}

class _NotStartedBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Read through the entire Bible in one year. Tap to get started.',
      style: TextStyle(
        color: GraceWayColor.softGold.withValues(alpha: 0.7),
        fontSize: 12,
      ),
    );
  }
}

class _PendingBody extends StatelessWidget {
  final BibleReadingProvider provider;
  const _PendingBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    final days = provider.daysUntilLive ?? 0;
    return Text(
      days == 0
          ? 'Your plan begins this Sunday.'
          : 'Your plan begins in $days ${days == 1 ? 'day' : 'days'}.',
      style: TextStyle(
        color: GraceWayColor.softGold.withValues(alpha: 0.8),
        fontSize: 12,
      ),
    );
  }
}

class _ActiveBody extends StatelessWidget {
  final BibleReadingProvider provider;
  const _ActiveBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    final weekIndex = provider.currentWeekIndex ?? 0;
    final daysRead = provider.totalDaysRead;
    final progress = daysRead / 364.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Week ${weekIndex + 1} of 52',
              style: const TextStyle(
                color: GraceWayColor.softGold,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$daysRead days read',
              style: TextStyle(
                color: GraceWayColor.softGold.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: GraceWayColor.golden.withValues(alpha: 0.15),
            valueColor: const AlwaysStoppedAnimation<Color>(GraceWayColor.golden),
          ),
        ),
      ],
    );
  }
}
