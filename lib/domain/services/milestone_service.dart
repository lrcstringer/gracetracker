import '../entities/habit.dart';

class Milestone {
  final String id;
  final double threshold;
  final String message;
  final bool isReached;
  final String? progressHint;

  const Milestone({
    required this.id,
    required this.threshold,
    required this.message,
    required this.isReached,
    this.progressHint,
  });

  Milestone copyWith({String? progressHint}) => Milestone(
    id: id, threshold: threshold, message: message,
    isReached: isReached, progressHint: progressHint ?? this.progressHint,
  );
}

class LifetimeStat {
  final String primaryValue;
  final String description;
  final String? detail;

  const LifetimeStat({required this.primaryValue, required this.description, this.detail});
}

class MilestoneService {
  static const MilestoneService instance = MilestoneService._();
  const MilestoneService._();

  LifetimeStat lifetimeStat(Habit habit) {
    switch (habit.trackingType) {
      case HabitTrackingType.timed:
        final totalMinutes = habit.totalValue();
        final hours = totalMinutes ~/ 60;
        final mins = totalMinutes.toInt() % 60;
        return LifetimeStat(
          primaryValue: hours > 0 ? '${hours}h ${mins}m' : '${mins}m',
          description: 'given to God through ${habit.name.toLowerCase()}',
          detail: totalMinutes >= 60 ? '${totalMinutes.toInt()} total minutes' : null,
        );
      case HabitTrackingType.count:
        return LifetimeStat(
          primaryValue: '${habit.totalValue().toInt()}',
          description: 'total ${habit.targetUnit.isEmpty ? "completed" : habit.targetUnit}',
        );
      case HabitTrackingType.checkIn:
        final days = habit.totalCompletedDays();
        return LifetimeStat(
          primaryValue: '$days',
          description: days == 1 ? 'day of ${habit.name.toLowerCase()}' : 'days of ${habit.name.toLowerCase()}',
        );
      case HabitTrackingType.abstain:
        final consecutive = _consecutiveCleanDays(habit);
        final total = habit.totalCompletedDays();
        return LifetimeStat(
          primaryValue: '$total',
          description: 'total clean days',
          detail: '$consecutive consecutive days strong',
        );
    }
  }

  List<Milestone> milestones(Habit habit) {
    var result = _buildMilestones(habit);
    final nextIndex = result.indexWhere((m) => !m.isReached);
    if (nextIndex >= 0) {
      final current = _currentValue(habit);
      final remaining = result[nextIndex].threshold - current;
      if (remaining > 0) {
        result[nextIndex] = result[nextIndex].copyWith(progressHint: _progressHint(habit, remaining));
      }
    }
    return result;
  }

  Milestone? checkForNewMilestone(Habit habit, {required double previousValue, required double newValue}) {
    final thresholds = _thresholds(habit);
    for (final t in thresholds) {
      if (previousValue < t && newValue >= t) {
        return _milestoneFor(habit, t);
      }
    }
    return null;
  }

  List<Milestone> milestonesHitDuringWeek(Habit habit, List<DateTime> weekDates) {
    final results = <Milestone>[];
    final thresholds = _thresholds(habit);

    final entriesBefore = habit.entries.where((e) {
      if (weekDates.isEmpty) return false;
      final firstDay = DateTime(weekDates.first.year, weekDates.first.month, weekDates.first.day);
      return e.date.isBefore(firstDay) && e.isCompleted;
    }).toList();

    final entriesDuring = habit.entries.where((e) {
      return weekDates.any((d) => _isSameDay(e.date, d)) && e.isCompleted;
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    double valueBefore;
    switch (habit.trackingType) {
      case HabitTrackingType.timed:
      case HabitTrackingType.count:
        // Use allTimeTotalValue when available — stays accurate beyond the 400-day in-memory window.
        if (habit.allTimeTotalValue != null) {
          final duringTotal = entriesDuring.fold(0.0, (s, e) => s + e.value);
          valueBefore = habit.allTimeTotalValue! - duringTotal;
        } else {
          valueBefore = entriesBefore.fold(0.0, (s, e) => s + e.value);
        }
      case HabitTrackingType.checkIn:
      case HabitTrackingType.abstain:
        // Use allTimeCompletedCount when available — stays accurate beyond the 400-day in-memory window.
        if (habit.allTimeCompletedCount != null) {
          valueBefore = (habit.allTimeCompletedCount! - entriesDuring.length).toDouble();
        } else {
          valueBefore = entriesBefore.length.toDouble();
        }
    }

    var running = valueBefore;
    for (final entry in entriesDuring) {
      final prev = running;
      switch (habit.trackingType) {
        case HabitTrackingType.timed:
        case HabitTrackingType.count:
          running += entry.value;
        case HabitTrackingType.checkIn:
        case HabitTrackingType.abstain:
          running += 1;
      }
      for (final t in thresholds) {
        if (prev < t && running >= t) {
          final m = _milestoneFor(habit, t);
          if (m != null) results.add(m);
        }
      }
    }
    return results;
  }

  int consecutiveCleanDays(Habit habit) => _consecutiveCleanDays(habit);

  int habitAge(Habit habit) {
    final created = DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    return todayDay.difference(created).inDays.clamp(0, double.maxFinite.toInt());
  }

  // Private

  double _currentValue(Habit habit) {
    switch (habit.trackingType) {
      case HabitTrackingType.timed:
      case HabitTrackingType.count:
        return habit.totalValue();
      case HabitTrackingType.checkIn:
      case HabitTrackingType.abstain:
        return habit.totalCompletedDays().toDouble();
    }
  }

  List<double> _thresholds(Habit habit) {
    switch (habit.trackingType) {
      case HabitTrackingType.timed: return [60, 600, 3000, 6000, 30000, 60000];
      case HabitTrackingType.count: return [100, 500, 1000, 5000];
      case HabitTrackingType.checkIn: return [7, 30, 100, 365];
      case HabitTrackingType.abstain: return [7, 14, 30, 60, 90, 180, 365];
    }
  }

  List<Milestone> _buildMilestones(Habit habit) {
    switch (habit.trackingType) {
      case HabitTrackingType.timed:
        final total = habit.totalValue();
        return [
          (60.0, '1 hour'), (600, '10 hours'), (3000, '50 hours'),
          (6000, '100 hours'), (30000, '500 hours'), (60000, '1,000 hours'),
        ].map((t) => Milestone(
          id: 'timed_${t.$1.toInt()}', threshold: t.$1.toDouble(),
          message: '${t.$2} given to God through ${habit.name.toLowerCase()}.',
          isReached: total >= t.$1,
        )).toList();

      case HabitTrackingType.count:
        final total = habit.totalValue();
        final unit = habit.targetUnit.isEmpty ? 'completed' : habit.targetUnit;
        return [
          (100.0, '100'), (500, '500'), (1000, '1,000'), (5000, '5,000'),
        ].map((t) => Milestone(
          id: 'count_${t.$1.toInt()}', threshold: t.$1.toDouble(),
          message: '${t.$2} $unit. Every one counts.',
          isReached: total >= t.$1,
        )).toList();

      case HabitTrackingType.checkIn:
        final days = habit.totalCompletedDays().toDouble();
        return [
          (7.0, '7 days'), (30, '30 days'), (100, '100 days'), (365, '365 days'),
        ].map((t) => Milestone(
          id: 'checkin_${t.$1.toInt()}', threshold: t.$1.toDouble(),
          message: '${t.$2} of ${habit.name.toLowerCase()}. That\'s faithfulness.',
          isReached: days >= t.$1,
        )).toList();

      case HabitTrackingType.abstain:
        final total = habit.totalCompletedDays().toDouble();
        return [
          (7.0, '7 days'), (14, '14 days'), (30, '30 days'), (60, '60 days'),
          (90, '90 days'), (180, '180 days'), (365, '365 days'),
        ].map((t) => Milestone(
          id: 'abstain_${t.$1.toInt()}', threshold: t.$1.toDouble(),
          message: '${t.$2} of freedom. Those days still stand.',
          isReached: total >= t.$1,
        )).toList();
    }
  }

  Milestone? _milestoneFor(Habit habit, double threshold) {
    switch (habit.trackingType) {
      case HabitTrackingType.timed:
        final labels = {60.0: '1 hour', 600.0: '10 hours', 3000.0: '50 hours', 6000.0: '100 hours', 30000.0: '500 hours', 60000.0: '1,000 hours'};
        final label = labels[threshold];
        if (label == null) return null;
        return Milestone(id: 'timed_${threshold.toInt()}', threshold: threshold, message: '$label given to God through ${habit.name.toLowerCase()}. What an offering.', isReached: true);
      case HabitTrackingType.count:
        final unit = habit.targetUnit.isEmpty ? 'completed' : habit.targetUnit;
        final formatted = threshold >= 1000 ? '${(threshold / 1000).toStringAsFixed(0)},000' : threshold.toInt().toString();
        return Milestone(id: 'count_${threshold.toInt()}', threshold: threshold, message: '$formatted $unit. Every single one counted.', isReached: true);
      case HabitTrackingType.checkIn:
        return Milestone(id: 'checkin_${threshold.toInt()}', threshold: threshold, message: '${threshold.toInt()} days of ${habit.name.toLowerCase()}. ${threshold.toInt()} times you chose to show up.', isReached: true);
      case HabitTrackingType.abstain:
        return Milestone(id: 'abstain_${threshold.toInt()}', threshold: threshold, message: '${threshold.toInt()} days of freedom. This is who you\'re becoming.', isReached: true);
    }
  }

  String _progressHint(Habit habit, double remaining) {
    switch (habit.trackingType) {
      case HabitTrackingType.timed:
        final hours = remaining ~/ 60;
        final mins = remaining.toInt() % 60;
        return hours > 0 ? '${hours}h ${mins}m to go' : '$mins minutes to go';
      case HabitTrackingType.count:
        return '${remaining.toInt()} more to go';
      case HabitTrackingType.checkIn:
      case HabitTrackingType.abstain:
        final d = remaining.toInt();
        return '$d more day${d == 1 ? "" : "s"} to go';
    }
  }

  int _consecutiveCleanDays(Habit habit) {
    if (habit.trackingType != HabitTrackingType.abstain) return 0;
    var count = 0;
    var checkDate = DateTime.now();
    checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day);
    while (true) {
      final entry = habit.entryFor(checkDate);
      if (entry?.isCompleted == true) {
        count++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return count;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
