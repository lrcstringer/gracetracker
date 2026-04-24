import 'package:flutter/material.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/services/daily_score_service.dart';
import '../../theme/app_theme.dart';

/// Aggregated heatmap across all habits.
///
/// Layout: 7 fixed rows (Sun–Sat) × weekCount scrollable columns (weeks).
/// Oldest week is on the left; newest is on the right and visible by default.
/// For weekCount == 1 a simple 7-tile row is used instead.
class AllHabitsHeatmapView extends StatelessWidget {
  final List<Habit> habits;
  final int weekCount;

  const AllHabitsHeatmapView({super.key, required this.habits, required this.weekCount});

  static final _scoreService = DailyScoreService.instance;

  static const _tileSize = 10.0;
  static const _gap = 2.0;
  static const _stride = _tileSize + _gap;
  static const _dayLabelWidth = 14.0;
  static const _monthRowHeight = 13.0;
  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _monthAbbrs = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  List<List<_AggDay>> _buildWeeks() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final daysSinceSunday = today.weekday % 7;
    final currentWeekStart = todayStart.subtract(Duration(days: daysSinceSunday));

    return List.generate(weekCount, (i) {
      final weekStart = currentWeekStart.add(Duration(days: (i - (weekCount - 1)) * 7));
      return List.generate(7, (d) {
        final date = weekStart.add(Duration(days: d));
        final isFuture = date.isAfter(todayStart);
        final score = isFuture ? 0.0 : _scoreService.dailyScore(habits, date);
        final tier = isFuture ? DayTier.nothing : _scoreService.tierForScore(score);
        return _AggDay(date: date, isFuture: isFuture, tier: tier);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _buildWeeks();

    // Single week: render as a plain horizontal row.
    if (weeks.length == 1) {
      return Row(
        children: weeks.first.map((day) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: AspectRatio(
              aspectRatio: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: _tileFill(day),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        )).toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed day labels — not scrollable.
        Padding(
          padding: const EdgeInsets.only(top: _monthRowHeight + 1),
          child: Column(
            children: List.generate(7, (i) => SizedBox(
              width: _dayLabelWidth,
              height: _stride,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _dayLabels[i],
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            )),
          ),
        ),
        // Scrollable grid — starts scrolled to the newest (rightmost) week.
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month markers row.
                SizedBox(
                  height: _monthRowHeight,
                  child: Row(
                    children: List.generate(weeks.length, (i) {
                      final sunday = weeks[i].first.date;
                      final showMonth = i == 0 ||
                          sunday.month != weeks[i - 1].first.date.month;
                      return SizedBox(
                        width: _stride,
                        child: showMonth
                            ? Text(
                                _monthAbbrs[sunday.month - 1],
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              )
                            : null,
                      );
                    }),
                  ),
                ),
                // 7 day rows.
                ...List.generate(7, (dayIndex) => Row(
                  children: weeks.map((week) {
                    final day = week[dayIndex];
                    return Padding(
                      padding: const EdgeInsets.only(right: _gap, bottom: _gap),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: _tileSize,
                        height: _tileSize,
                        decoration: BoxDecoration(
                          color: _tileFill(day),
                          borderRadius: BorderRadius.circular(2),
                          border: day.tier == DayTier.partial && !day.isFuture
                              ? Border.all(
                                  color: GraceWayColor.golden.withValues(alpha: 0.5),
                                  width: 0.5)
                              : null,
                          boxShadow: day.tier == DayTier.full && !day.isFuture
                              ? [BoxShadow(
                                  color: GraceWayColor.golden.withValues(alpha: 0.35),
                                  blurRadius: 3)]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _tileFill(_AggDay day) {
    if (day.isFuture) return Colors.white.withValues(alpha: 0.02);
    switch (day.tier) {
      case DayTier.nothing:
        return GraceWayColor.surfaceOverlay;
      case DayTier.partial:
        return GraceWayColor.golden.withValues(alpha: 0.12);
      case DayTier.substantial:
        return GraceWayColor.golden.withValues(alpha: 0.55);
      case DayTier.full:
        return GraceWayColor.golden.withValues(alpha: 0.95);
    }
  }
}

class _AggDay {
  final DateTime date;
  final bool isFuture;
  final DayTier tier;
  const _AggDay({required this.date, required this.isFuture, required this.tier});
}
