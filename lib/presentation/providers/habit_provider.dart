import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/remote/auth_service.dart';
import '../../domain/entities/habit.dart';
import '../../domain/entities/habit_entry.dart';
import '../../domain/repositories/habit_repository.dart';
import '../../domain/repositories/circle_repository.dart';
import '../../domain/services/daily_score_service.dart';

class HabitProvider extends ChangeNotifier {
  final HabitRepository _repository;
  final bool Function() _isAuthenticated;
  final CircleRepository _circleRepository;

  HabitProvider(
    this._repository,
    this._isAuthenticated,
    this._circleRepository,
  ) : _prevAuthenticated = AuthService.shared.isAuthenticated {
    AuthService.shared.addListener(_onAuthChanged);
  }

  List<Habit> _habits = [];
  bool _isLoading = false;
  String? _checkInPulseHabitId;
  bool _showingAddHabit = false;
  bool _loadInProgress = false;
  bool _prevAuthenticated;

  @override
  void dispose() {
    AuthService.shared.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final isNow = AuthService.shared.isAuthenticated;
    if (!_prevAuthenticated && isNow) {
      // Signed in — reload habits from Firestore.
      loadHabits();
    } else if (_prevAuthenticated && !isNow) {
      // Signed out — clear habits immediately.
      _habits = [];
      notifyListeners();
    }
    _prevAuthenticated = isNow;
  }

  List<Habit> get habits => List.unmodifiable(_habits);
  List<Habit> get sortedHabits =>
      [..._habits]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  bool get isLoading => _isLoading;
  String? get checkInPulseHabitId => _checkInPulseHabitId;
  bool get showingAddHabit => _showingAddHabit;

  Future<void> loadHabits() async {
    // Guard against concurrent loads to avoid double ensureGratitudeHabit inserts.
    if (_loadInProgress) return;
    _loadInProgress = true;
    _isLoading = true;
    notifyListeners();
    _habits = await _repository.loadHabits();
    _isLoading = false;
    await ensureGratitudeHabit();
    notifyListeners();
    _loadInProgress = false;
    // Run one-time migration to populate the new category fields.
    unawaited(migrateCategories());
  }

  /// One-time migration: assigns categoryId/subcategoryId to habits that
  /// still use the legacy [HabitCategory] enum only.
  /// Guarded by a per-user SharedPreferences flag so it runs at most once per
  /// user per device. Skipped entirely when not authenticated.
  Future<void> migrateCategories() async {
    // Skip if not signed in — habits haven't loaded from Firestore yet anyway.
    if (!_isAuthenticated()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final flagKey = 'habitCategoryMigrationComplete_$uid';
    if (prefs.getBool(flagKey) == true) return;

    final unmigrated = _habits.where((h) => h.categoryId == null).toList();
    if (unmigrated.isEmpty) {
      await prefs.setBool(flagKey, true);
      return;
    }

    final updates = <String, Map<String, String?>>{};
    for (final habit in unmigrated) {
      final (catId, subId, catName, subName) = _mapLegacyCategory(habit);
      updates[habit.id] = {
        'categoryId': catId,
        'subcategoryId': subId,
        'categoryName': catName,
        'subcategoryName': subName,
      };
    }

    await _repository.batchUpdateCategoryFields(updates);
    await prefs.setBool(flagKey, true);

    // Reload so _habits reflects the new fields (includes gratitude dedup).
    _habits = await _repository.loadHabits();
    await ensureGratitudeHabit();
    notifyListeners();
  }

  /// Maps a legacy [HabitCategory] enum value to the new two-level IDs + names.
  static (String, String, String, String) _mapLegacyCategory(Habit habit) {
    return switch (habit.category) {
      HabitCategory.exercise => (
          'caring_for_myself',
          'exercise',
          'Caring for Myself & Growing Personally',
          'Exercise'
        ),
      HabitCategory.scripture => (
          'loving_the_lord',
          'gods_word',
          'Loving the Lord & Spiritual Growth',
          "God's Word"
        ),
      HabitCategory.rest => (
          'caring_for_myself',
          'rest_and_renewal',
          'Caring for Myself & Growing Personally',
          'Rest & Renewal'
        ),
      HabitCategory.fasting => (
          'loving_the_lord',
          'fasting',
          'Loving the Lord & Spiritual Growth',
          'Fasting'
        ),
      HabitCategory.study => (
          'caring_for_myself',
          'reading_and_learning',
          'Caring for Myself & Growing Personally',
          'Reading & Learning'
        ),
      HabitCategory.service => (
          'caring_for_others',
          'service_and_generosity',
          'Caring for Others & Connecting with Others',
          'Service & Generosity'
        ),
      HabitCategory.connection => (
          'caring_for_others',
          'connection_and_community',
          'Caring for Others & Connecting with Others',
          'Connection & Community'
        ),
      HabitCategory.health => (
          'caring_for_myself',
          'health_and_nutrition',
          'Caring for Myself & Growing Personally',
          'Health & Nutrition'
        ),
      HabitCategory.abstain => (
          'caring_for_myself',
          'breaking_habits',
          'Caring for Myself & Growing Personally',
          'Breaking Habits'
        ),
      HabitCategory.gratitude => (
          'loving_the_lord',
          'worship',
          'Loving the Lord & Spiritual Growth',
          'Worship'
        ),
      HabitCategory.prayer => (
          'loving_the_lord',
          'prayer',
          'Loving the Lord & Spiritual Growth',
          'Prayer'
        ),
      HabitCategory.custom =>
        ('create_my_own', 'custom', 'Create My Own', habit.name),
    };
  }

  Future<void> ensureGratitudeHabit() async {
    final gratitudes = _habits
        .where((h) => h.category == HabitCategory.gratitude)
        .toList();

    // Deduplicate: if more than one exists, delete the extras, keeping the
    // built-in one (or the first if none are flagged built-in).
    if (gratitudes.length > 1) {
      final keeper = gratitudes.firstWhere(
        (h) => h.isBuiltIn,
        orElse: () => gratitudes.first,
      );
      for (final dup in gratitudes.where((h) => h.id != keeper.id)) {
        await _repository.deleteHabit(dup.id);
        _habits.remove(dup);
      }
      notifyListeners();
      return;
    }

    if (gratitudes.isEmpty) {
      final gratitude = Habit.create(
        name: 'Daily Gratitude',
        category: HabitCategory.gratitude,
        trackingType: HabitTrackingType.checkIn,
        purposeStatement:
            'Give thanks in all circumstances; for this is God\u2019s will for you in Christ Jesus.',
        isBuiltIn: true,
        sortOrder: 0,
      );
      await _repository.insertHabit(gratitude);
      _habits = [gratitude, ..._habits];
      notifyListeners();
    }
  }

  Future<void> addHabit({
    required String name,
    required HabitCategory category,
    required HabitTrackingType trackingType,
    required String purpose,
    required double dailyTarget,
    required String targetUnit,
    Set<int> activeDays = const {1, 2, 3, 4, 5, 6, 7},
    String trigger = '',
    String copingPlan = '',
    String sourceType = 'user_created',
    String? sourceActionId,
    String? categoryId,
    String? subcategoryId,
    String? categoryName,
    String? subcategoryName,
    String notes = '',
    String referenceUrl = '',
  }) async {
    final created = Habit.create(
      name: name,
      category: category,
      trackingType: trackingType,
      purposeStatement: purpose,
      dailyTarget: dailyTarget,
      targetUnit: targetUnit,
      sortOrder: _habits.length,
      activeDays: activeDays,
      trigger: trigger,
      copingPlan: copingPlan,
      sourceType: sourceType,
      sourceActionId: sourceActionId,
      notes: notes,
      referenceUrl: referenceUrl,
    );
    final habit = (categoryId != null)
        ? created.copyWith(
            categoryId: categoryId,
            subcategoryId: subcategoryId,
            categoryName: categoryName,
            subcategoryName: subcategoryName,
          )
        : created;
    await _repository.insertHabit(habit);
    _habits = [..._habits, habit];
    notifyListeners();
  }

  Future<void> updateHabit(Habit habit) async {
    await _repository.updateHabit(habit);
    _habits = [
      for (final h in _habits) h.id == habit.id ? habit : h,
    ];
    notifyListeners();
  }

  Future<void> deleteHabit(Habit habit) async {
    if (habit.isBuiltIn) return;
    await _repository.deleteHabit(habit.id);
    _habits = _habits.where((h) => h.id != habit.id).toList();
    notifyListeners();
  }

  Future<void> archiveHabit(Habit habit) async {
    if (habit.isBuiltIn) return;
    await _repository.setArchived(habit.id, archived: true);
    _habits = _habits.where((h) => h.id != habit.id).toList();
    notifyListeners();
  }

  Future<void> unarchiveHabit(Habit habit) async {
    await _repository.setArchived(habit.id, archived: false);
    await loadHabits();
  }

  Future<List<Habit>> loadArchivedHabits() {
    return _repository.loadArchivedHabits();
  }

  /// Deletes all user-created habits and clears all entries + aggregates for
  /// built-in habits. Reloads from the repository when done.
  Future<void> resetAllData() async {
    final active = List<Habit>.from(_habits);
    final archived = await _repository.loadArchivedHabits();
    await Future.wait([
      for (final h in active)
        h.isBuiltIn
            ? _repository.clearHabitEntries(h.id)
            : _repository.deleteHabit(h.id),
      for (final h in archived)
        _repository.deleteHabit(h.id),
    ]);
    await loadHabits();
  }

  Future<void> reorderHabits(List<Habit> reordered) async {
    _habits = reordered;
    await _repository.updateHabitSortOrders(reordered);
    notifyListeners();
  }

  // Check-in methods

  Future<void> checkInHabit(Habit habit,
      {DateTime? date, bool retroactive = false}) async {
    final target = _dayStart(date ?? DateTime.now());
    await _upsertEntry(habit,
        targetDate: target,
        value: habit.dailyTarget,
        isCompleted: true);
    if (!retroactive) unawaited(_syncHeatmapToCircles());
    _checkInPulseHabitId = habit.id;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1200));
    _checkInPulseHabitId = null;
    notifyListeners();
  }

  Future<void> checkInGratitude(Habit habit,
      {String? note, DateTime? date}) async {
    final target = _dayStart(date ?? DateTime.now());
    await _upsertEntry(habit,
        targetDate: target, value: 1, isCompleted: true, gratitudeNote: note);
    unawaited(_syncHeatmapToCircles());
    _checkInPulseHabitId = habit.id;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1200));
    _checkInPulseHabitId = null;
    notifyListeners();
  }

  Future<void> updateTimedEntry(Habit habit, double minutes,
      {DateTime? date}) async {
    final target = _dayStart(date ?? DateTime.now());
    final completed = minutes >= habit.dailyTarget;
    await _upsertEntry(habit,
        targetDate: target, value: minutes, isCompleted: completed);
    if (completed) {
      unawaited(_syncHeatmapToCircles());
      _checkInPulseHabitId = habit.id;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 1200));
      _checkInPulseHabitId = null;
    }
    notifyListeners();
  }

  Future<void> updateCountEntry(Habit habit, double count,
      {DateTime? date}) async {
    final target = _dayStart(date ?? DateTime.now());
    final completed = count >= habit.dailyTarget;
    await _upsertEntry(habit,
        targetDate: target, value: count, isCompleted: completed);
    if (completed) {
      unawaited(_syncHeatmapToCircles());
      _checkInPulseHabitId = habit.id;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 1200));
      _checkInPulseHabitId = null;
    }
    notifyListeners();
  }

  void setShowingAddHabit(bool value) {
    _showingAddHabit = value;
    notifyListeners();
  }

  // Heatmap sync

  Future<void> _syncHeatmapToCircles() async {
    if (!_isAuthenticated()) return;
    try {
      final today = DateTime.now();
      final dayStart = _dayStart(today);
      // Build Sunday-to-today date range for the current week.
      final weekday = dayStart.weekday % 7; // 0 = Sunday
      final sunday = dayStart.subtract(Duration(days: weekday));
      final days = List.generate(
        weekday + 1,
        (i) => sunday.add(Duration(days: i)),
      );
      final weekData = days.map((d) {
        final score = DailyScoreService.instance.dailyScore(_habits, d);
        return {
          'date': d.toIso8601String().substring(0, 10),
          'score': score
        };
      }).toList();

      final circles = await _circleRepository.listCircles();
      for (final circle in circles) {
        await _circleRepository.submitHeatmapData(circle.id, weekData);
      }
    } catch (_) {
      // Fire-and-forget — never surface heatmap sync errors to the user.
    }
  }

  // Private helpers

  Future<void> _upsertEntry(
    Habit habit, {
    required DateTime targetDate,
    required double value,
    required bool isCompleted,
    String? gratitudeNote,
  }) async {
    final existing = habit.entryFor(targetDate);
    final HabitEntry entry;

    if (existing != null) {
      // Preserve the existing gratitude note when no new note is provided.
      entry = existing.copyWith(
        value: value,
        isCompleted: isCompleted,
        gratitudeNote: gratitudeNote ?? existing.gratitudeNote,
      );
    } else {
      entry = HabitEntry.create(
        habitId: habit.id,
        date: targetDate,
        value: value,
        isCompleted: isCompleted,
        gratitudeNote: gratitudeNote,
      );
    }

    final deltaCompleted =
        (isCompleted ? 1 : 0) - (existing?.isCompleted == true ? 1 : 0);
    final deltaValue = value - (existing?.value ?? 0.0);
    await _repository.upsertEntry(entry,
        deltaCompleted: deltaCompleted, deltaValue: deltaValue);

    // Replace the habit in _habits with an updated immutable copy.
    _habits = [
      for (final h in _habits)
        if (h.id == habit.id)
          _withUpdatedEntry(h, entry, previous: existing)
        else
          h,
    ];
  }

  /// Returns a copy of [habit] with [entry] inserted or replaced in its entries list.
  /// Also adjusts [allTimeCompletedCount] and [allTimeTotalValue] by the delta between
  /// [previous] and the new [entry], keeping cached aggregates in sync after in-session check-ins.
  static Habit _withUpdatedEntry(Habit habit, HabitEntry entry, {HabitEntry? previous}) {
    final entries = List<HabitEntry>.from(habit.entries);
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
    }

    // Update cached aggregate counts if they are present.
    int? newAllTimeCompleted = habit.allTimeCompletedCount;
    double? newAllTimeTotalValue = habit.allTimeTotalValue;

    if (newAllTimeCompleted != null) {
      final wasCompleted = previous?.isCompleted ?? false;
      if (!wasCompleted && entry.isCompleted) {
        newAllTimeCompleted += 1;
      } else if (wasCompleted && !entry.isCompleted) {
        newAllTimeCompleted = (newAllTimeCompleted - 1).clamp(0, newAllTimeCompleted);
      }
    }

    if (newAllTimeTotalValue != null) {
      newAllTimeTotalValue += entry.value - (previous?.value ?? 0.0);
    }

    return habit.copyWith(
      entries: entries,
      allTimeCompletedCount: newAllTimeCompleted,
      allTimeTotalValue: newAllTimeTotalValue,
    );
  }

  static DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
