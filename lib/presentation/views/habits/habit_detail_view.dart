import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../domain/entities/habit.dart';
import '../../providers/habit_provider.dart';
import '../../providers/store_provider.dart';
import '../../../domain/services/milestone_service.dart';
import '../../theme/app_theme.dart';
import '../shared/graceway_paywall_view.dart';
import 'edit_habit_view.dart';
import 'heatmap_view.dart';

class HabitDetailView extends StatefulWidget {
  final Habit habit;
  final ScrollController? scrollController;

  const HabitDetailView({super.key, required this.habit, this.scrollController});

  @override
  State<HabitDetailView> createState() => _HabitDetailViewState();
}

class _HabitDetailViewState extends State<HabitDetailView> {
  static const _milestoneService = MilestoneService.instance;

  late Habit _liveHabit;
  late HabitProvider _habitProvider;
  QuillController? _notesController;

  // Canonical getter used everywhere in the view — always the freshest data.
  Habit get _habit => _liveHabit;

  @override
  void initState() {
    super.initState();
    _liveHabit = widget.habit;
    _rebuildNotesController(_liveHabit.notes);
    _habitProvider = context.read<HabitProvider>();
    _habitProvider.addListener(_onHabitProviderChanged);
  }

  @override
  void dispose() {
    _habitProvider.removeListener(_onHabitProviderChanged);
    _notesController?.dispose();
    super.dispose();
  }

  /// Called whenever HabitProvider notifies. Looks up this habit by ID and,
  /// if any editable field changed (e.g. after saving from EditHabitView),
  /// updates [_liveHabit] and rebuilds the notes controller when needed.
  void _onHabitProviderChanged() {
    if (!mounted) return;
    final updated = _habitProvider.habits.firstWhere(
      (h) => h.id == _liveHabit.id,
      orElse: () => _liveHabit,
    );
    if (identical(updated, _liveHabit)) return;
    setState(() {
      if (updated.notes != _liveHabit.notes) {
        _rebuildNotesController(updated.notes);
      }
      _liveHabit = updated;
    });
  }

  void _rebuildNotesController(String notes) {
    _notesController?.dispose();
    _notesController = null;
    if (notes.isNotEmpty) {
      try {
        _notesController = QuillController(
          document: Document.fromJson(jsonDecode(notes) as List),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      } catch (_) {
        // Corrupt notes JSON — leave controller null so the section is hidden.
      }
    }
  }

  Color _accentColor() =>
      _habit.trackingType == HabitTrackingType.abstain
          ? GraceWayColor.sage
          : GraceWayColor.golden;

  List<DateTime> _currentWeekDates() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final daysSinceSunday = today.weekday % 7;
    final weekStart = todayStart.subtract(Duration(days: daysSinceSunday));
    return List.generate(7, (i) => weekStart.add(Duration(days: i)));
  }

  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<StoreProvider>().isPremium;
    final accent = _accentColor();
    final lifetimeStat = _milestoneService.lifetimeStat(_habit);
    final milestones = _milestoneService.milestones(_habit);
    final habitAge = _milestoneService.habitAge(_habit);
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        title: Text(
          _habit.name,
          style: const TextStyle(color: GraceWayColor.warmWhite, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: GraceWayColor.warmWhite),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: GraceWayColor.softGold.withValues(alpha: 0.8)),
            onPressed: () => _showEdit(context),
          ),
        ],
      ),
      body: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          _lifetimeStatSection(lifetimeStat, accent),
          const SizedBox(height: 20),
          _weekBreakdownSection(),
          const SizedBox(height: 20),
          _heatmapSection(isPremium, accent),
          const SizedBox(height: 20),
          _milestoneSection(milestones, accent),
          const SizedBox(height: 20),
          if (_habit.trigger.isNotEmpty || _habit.copingPlan.isNotEmpty) ...[
            _anchoringSection(),
            const SizedBox(height: 20),
          ],
          _purposeSection(),
          if (_habit.hasPrayerItems) ...[
            const SizedBox(height: 20),
            _prayerItemsSection(),
          ],
          if (_notesController != null) ...[
            const SizedBox(height: 20),
            _notesDisplaySection(),
          ],
          if (_habit.referenceUrl.isNotEmpty) ...[
            const SizedBox(height: 20),
            _referenceUrlRow(),
          ],
          const SizedBox(height: 20),
          _habitInfoSection(habitAge),
        ],
      ),
    );
  }

  Widget _lifetimeStatSection(LifetimeStat stat, Color accent) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [accent.withValues(alpha: 0.25), accent.withValues(alpha: 0.04)],
            ),
          ),
          child: Icon(_habitIcon(), color: accent, size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          stat.primaryValue,
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w800,
            color: accent,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          stat.description,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: GraceWayColor.softGold),
        ),
        if (stat.detail != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_habit.trackingType == HabitTrackingType.abstain)
                Icon(Icons.shield_outlined, size: 13, color: GraceWayColor.sage.withValues(alpha: 0.6)),
              if (_habit.trackingType == HabitTrackingType.abstain)
                const SizedBox(width: 4),
              Text(
                stat.detail!,
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.45)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _weekBreakdownSection() {
    final dates = _currentWeekDates();
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: GraceWayColor.softGold)),
          const SizedBox(height: 12),
          Row(
            children: dates.asMap().entries.map((e) {
              final date = e.value;
              final isToday = date.year == todayStart.year &&
                  date.month == todayStart.month &&
                  date.day == todayStart.day;
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      _dayLabels[e.key],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                        color: isToday ? GraceWayColor.golden : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _weekDayVisual(date),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _weekDayVisual(DateTime date) {
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isFuture = date.isAfter(todayStart);
    final isActive = _habit.isActive(date);
    final entry = _habit.entryFor(date);

    switch (_habit.trackingType) {
      case HabitTrackingType.timed:
        return _timedDayBar(entry, isFuture, isActive);
      case HabitTrackingType.count:
        return _countDayVisual(entry, isFuture, isActive);
      case HabitTrackingType.checkIn:
        return _checkInDayCircle(entry, isFuture, isActive);
      case HabitTrackingType.abstain:
        return _abstainDayShield(entry, isFuture, isActive);
    }
  }

  Widget _timedDayBar(dynamic entry, bool isFuture, bool isActive) {
    final value = entry?.value ?? 0.0;
    final target = _habit.dailyTarget;
    final ratio = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    final completed = entry?.isCompleted ?? false;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 16,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            if (!isFuture && isActive)
              Container(
                width: 16,
                height: (40 * ratio).clamp(2.0, 40.0).toDouble(),
                decoration: BoxDecoration(
                  color: completed ? GraceWayColor.golden : GraceWayColor.mutedSage,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          (!isFuture && isActive && value > 0) ? '${value.toInt()}' : ' ',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: completed ? GraceWayColor.golden : Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _countDayVisual(dynamic entry, bool isFuture, bool isActive) {
    final value = entry?.value ?? 0.0;
    final completed = entry?.isCompleted ?? false;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (!isFuture && isActive && value > 0)
                ? (completed
                    ? GraceWayColor.golden.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.04))
                : Colors.white.withValues(alpha: isFuture || !isActive ? 0.02 : 0.04),
          ),
          child: (!isFuture && isActive && value > 0)
              ? Center(
                  child: Text(
                    '${value.toInt()}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: completed
                          ? GraceWayColor.golden
                          : GraceWayColor.softGold.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 4),
        const Text(' ', style: TextStyle(fontSize: 9)),
      ],
    );
  }

  Widget _checkInDayCircle(dynamic entry, bool isFuture, bool isActive) {
    final completed = entry?.isCompleted ?? false;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed
                ? GraceWayColor.golden
                : Colors.white.withValues(alpha: isFuture || !isActive ? 0.02 : 0.04),
          ),
          child: completed
              ? const Icon(Icons.check, size: 14, color: GraceWayColor.charcoal)
              : null,
        ),
        const SizedBox(height: 4),
        const Text(' ', style: TextStyle(fontSize: 9)),
      ],
    );
  }

  Widget _abstainDayShield(dynamic entry, bool isFuture, bool isActive) {
    final confirmed = entry?.isCompleted ?? false;

    return Column(
      children: [
        Icon(
          confirmed ? Icons.shield_rounded : Icons.shield_outlined,
          size: 24,
          color: confirmed
              ? GraceWayColor.sage
              : Colors.white.withValues(alpha: isFuture || !isActive ? 0.08 : 0.2),
        ),
        const SizedBox(height: 4),
        const Text(' ', style: TextStyle(fontSize: 9)),
      ],
    );
  }

  Widget _heatmapSection(bool isPremium, Color accent) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: GraceWayDecorations.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Activity',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
                  const Spacer(),
                  Text(isPremium ? 'Last 12 weeks' : 'Current week',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                ],
              ),
              const SizedBox(height: 12),
              HeatmapView(habit: _habit, weekCount: isPremium ? 12 : 1),
            ],
          ),
        ),
        if (isPremium) ...[
          const SizedBox(height: 20),
          Container(
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
                HeatmapView(habit: _habit, weekCount: 52),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _showPaywall(context),
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
                        child: IgnorePointer(child: HeatmapView(habit: _habit, weekCount: 52)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.lock_outline, size: 13, color: GraceWayColor.golden),
                      const SizedBox(width: 6),
                      Text('Unlock with Grace Tracker Pro',
                          style: TextStyle(
                              fontSize: 12, color: GraceWayColor.softGold)),
                      const Spacer(),
                      Icon(Icons.chevron_right,
                          size: 13, color: Colors.white.withValues(alpha: 0.3)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _milestoneSection(List<Milestone> milestones, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Milestones',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
          const SizedBox(height: 14),
          ...milestones.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: m.isReached
                        ? accent.withValues(alpha: 0.2)
                        : GraceWayColor.surfaceOverlay,
                  ),
                  child: Icon(
                    m.isReached ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: m.isReached ? accent : Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: m.isReached
                              ? GraceWayColor.warmWhite
                              : Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      if (m.progressHint != null && !m.isReached)
                        Text(
                          m.progressHint!,
                          style: TextStyle(
                              fontSize: 11, color: accent.withValues(alpha: 0.6)),
                        )
                      else if (!m.isReached)
                        Text('Keep going',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.2))),
                    ],
                  ),
                ),
                if (m.isReached)
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: accent.withValues(alpha: 0.6)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _anchoringSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_habit.trigger.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.access_time,
                  size: 13, color: GraceWayColor.golden.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text('Trigger',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: GraceWayColor.golden.withValues(alpha: 0.7))),
            ]),
            const SizedBox(height: 4),
            Text(_habit.trigger,
                style: const TextStyle(fontSize: 14, color: GraceWayColor.warmWhite)),
          ],
          if (_habit.trigger.isNotEmpty && _habit.copingPlan.isNotEmpty)
            const SizedBox(height: 10),
          if (_habit.copingPlan.isNotEmpty) ...[
            Row(children: [
              Icon(Icons.shield_outlined,
                  size: 13, color: GraceWayColor.warmCoral.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text('Coping Plan',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: GraceWayColor.warmCoral.withValues(alpha: 0.7))),
            ]),
            const SizedBox(height: 4),
            Text(_habit.copingPlan,
                style: const TextStyle(fontSize: 14, color: GraceWayColor.warmWhite)),
          ],
        ],
      ),
    );
  }

  // ── Prayer Items ────────────────────────────────────────────────────────────

  void _savePrayerItems(List<PrayerItem> items) {
    _habitProvider.updateHabit(_habit.copyWith(prayerItems: items));
  }

  void _addPrayerItem() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GraceWayColor.cardBackground,
        title: const Text('Add Prayer Item',
            style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          style: const TextStyle(color: GraceWayColor.warmWhite, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'What would you like to pray for?',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: GraceWayColor.inputBackground,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              final updated = [..._habit.prayerItems, PrayerItem.create(text)];
              _savePrayerItems(updated);
            },
            child: const Text('Add', style: TextStyle(color: GraceWayColor.golden)),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _cyclePrayerItemStatus(PrayerItem item) {
    final next = switch (item.status) {
      PrayerItemStatus.praying => PrayerItemStatus.unanswered,
      PrayerItemStatus.unanswered => PrayerItemStatus.answered,
      PrayerItemStatus.answered => PrayerItemStatus.praying,
    };
    final answeredAt = next == PrayerItemStatus.answered
        ? DateTime.now().toIso8601String()
        : null;
    final updated = _habit.prayerItems
        .map((p) => p.id == item.id
            ? p.copyWith(status: next, answeredAt: answeredAt)
            : p)
        .toList();
    _savePrayerItems(updated);
  }

  void _deletePrayerItem(String id) {
    final updated = _habit.prayerItems.where((p) => p.id != id).toList();
    _savePrayerItems(updated);
  }

  Widget _prayerItemsSection() {
    final active = _habit.prayerItems
        .where((p) => p.status != PrayerItemStatus.answered)
        .toList();
    final answered = _habit.prayerItems
        .where((p) => p.status == PrayerItemStatus.answered)
        .toList();
    final canAdd = _habit.prayerItems.length < 10;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Prayer List',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: GraceWayColor.softGold)),
          const Spacer(),
          if (canAdd)
            GestureDetector(
              onTap: _addPrayerItem,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_circle_outline_rounded,
                    size: 16, color: GraceWayColor.golden.withValues(alpha: 0.8)),
                const SizedBox(width: 4),
                Text('Add',
                    style: TextStyle(
                        fontSize: 12, color: GraceWayColor.golden.withValues(alpha: 0.8))),
              ]),
            )
          else
            Text('10/10',
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
        ]),
        if (_habit.prayerItems.isEmpty) ...[
          const SizedBox(height: 16),
          Center(
            child: Text('Tap Add to record your first prayer item.',
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: 0.35))),
          ),
        ] else ...[
          if (active.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...active.map((item) => _prayerItemRow(item)),
          ],
          if (answered.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('ANSWERED',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      color: GraceWayColor.sage.withValues(alpha: 0.6))),
            ),
            ...answered.map((item) => _prayerItemRow(item)),
          ],
        ],
      ]),
    );
  }

  Widget _prayerItemRow(PrayerItem item) {
    final isAnswered = item.status == PrayerItemStatus.answered;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.text,
                style: TextStyle(
                    fontSize: 14,
                    color: isAnswered
                        ? Colors.white.withValues(alpha: 0.4)
                        : GraceWayColor.warmWhite,
                    decoration: isAnswered ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white.withValues(alpha: 0.3))),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _cyclePrayerItemStatus(item),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(item.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _statusColor(item.status).withValues(alpha: 0.35)),
                ),
                child: Text(item.status.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _statusColor(item.status))),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _deletePrayerItem(item.id),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.close_rounded,
                size: 16, color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
      ]),
    );
  }

  Color _statusColor(PrayerItemStatus status) {
    switch (status) {
      case PrayerItemStatus.praying:
        return GraceWayColor.golden;
      case PrayerItemStatus.unanswered:
        return GraceWayColor.warmCoral;
      case PrayerItemStatus.answered:
        return GraceWayColor.sage;
    }
  }

  Widget _notesDisplaySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.softGold),
          ),
          const SizedBox(height: 10),
          QuillEditor.basic(
            controller: _notesController!,
            config: QuillEditorConfig(
              scrollable: false,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _referenceUrlRow() {
    final url = _habit.referenceUrl;
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: GraceWayDecorations.card,
        child: Row(
          children: [
            Icon(Icons.link_rounded,
                size: 16, color: GraceWayColor.softGold.withValues(alpha: 0.7)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                url,
                style: TextStyle(
                  fontSize: 13,
                  color: GraceWayColor.softGold.withValues(alpha: 0.9),
                  decoration: TextDecoration.underline,
                  decorationColor: GraceWayColor.softGold.withValues(alpha: 0.4),
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new_rounded,
                size: 14, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _purposeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: GraceWayDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Why',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
          const SizedBox(height: 8),
          Text(
            _habit.purposeStatement,
            style: TextStyle(
                fontSize: 15, color: GraceWayColor.warmWhite, height: 1.5),
          ),
        ],
      ),
    );
  }


  Widget _habitInfoSection(int habitAge) {
    final activedays = _habit.activeDaySet.toList()..sort();
    const dayNames = {1: 'Sun', 2: 'Mon', 3: 'Tue', 4: 'Wed', 5: 'Thu', 6: 'Fri', 7: 'Sat'};
    final activeDaysSummary = activedays.map((d) => dayNames[d] ?? '').where((s) => s.isNotEmpty).join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GraceWayDecorations.card,
      child: Column(
        children: [
          _infoRow('Tracking type', _habit.trackingType.name[0].toUpperCase() + _habit.trackingType.name.substring(1)),
          const SizedBox(height: 8),
          _infoRow('Started', '$habitAge days ago'),
          const SizedBox(height: 8),
          _infoRow('Total entries', '${_habit.entries.where((e) => e.isCompleted).length}'),
          if (_habit.activeDaySet.length < 7) ...[
            const SizedBox(height: 8),
            _infoRow('Active days', activeDaysSummary),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: GraceWayColor.softGold)),
      ],
    );
  }

  IconData _habitIcon() {
    if (_habit.trackingType == HabitTrackingType.abstain) return Icons.shield_rounded;
    switch (_habit.category) {
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

  void _showEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: GraceWayColor.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (ctx, sc) => EditHabitView(habit: _habit, scrollController: sc),
      ),
    );
  }
}
