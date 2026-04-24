import 'package:flutter/material.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/services/daily_score_service.dart';
import '../../theme/app_theme.dart';

class WeekStripView extends StatelessWidget {
  final List<Habit> habits;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const WeekStripView({
    super.key,
    required this.habits,
    required this.selectedDate,
    required this.onDateSelected,
  });

  static final _scoreService = DailyScoreService.instance;
  static const _dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  List<DateTime> _weekDates() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final daysSinceSunday = today.weekday % 7; // Sun=0..Sat=6
    final weekStart = todayStart.subtract(Duration(days: daysSinceSunday));
    return List.generate(7, (i) => weekStart.add(Duration(days: i)));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final dates = _weekDates();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: dates.asMap().entries.map((e) {
        final date = e.value;
        final isFuture = date.isAfter(todayStart);
        final isToday = _isSameDay(date, todayStart);
        final isSelected = _isSameDay(date, selectedDate);
        final tier = isFuture
            ? DayTier.nothing
            : _scoreService.tierForHabits(habits, date);

        return GestureDetector(
          onTap: isFuture ? null : () => onDateSelected(date),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _dayLabels[e.key].substring(0, 1),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  color: isToday
                      ? GraceWayColor.golden
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              _DayTile(
                date: date,
                tier: tier,
                isFuture: isFuture,
                isSelected: isSelected,
                isToday: isToday,
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 10,
                  color: isToday
                      ? GraceWayColor.golden
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DayTile extends StatelessWidget {
  final DateTime date;
  final DayTier tier;
  final bool isFuture;
  final bool isSelected;
  final bool isToday;

  const _DayTile({
    required this.date,
    required this.tier,
    required this.isFuture,
    required this.isSelected,
    required this.isToday,
  });

  Color _tileColor() {
    if (isFuture) return Colors.white.withValues(alpha: 0.04);
    switch (tier) {
      case DayTier.nothing:
        return GraceWayColor.surfaceOverlay;
      case DayTier.partial:
        return GraceWayColor.golden.withValues(alpha: 0.2);
      case DayTier.substantial:
        return GraceWayColor.golden.withValues(alpha: 0.55);
      case DayTier.full:
        return GraceWayColor.golden.withValues(alpha: 0.85);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _tileColor();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: isSelected
            ? Border.all(color: GraceWayColor.golden, width: 2)
            : isToday && tier == DayTier.nothing
                ? Border.all(color: GraceWayColor.golden.withValues(alpha: 0.4), width: 1)
                : null,
        boxShadow: tier == DayTier.full && !isFuture
            ? [BoxShadow(color: GraceWayColor.golden.withValues(alpha: 0.4), blurRadius: 6)]
            : null,
      ),
    );
  }
}
