import 'package:flutter/material.dart';
import '../../../domain/entities/habit.dart';
import '../../theme/app_theme.dart';

class HabitSetupScreen extends StatefulWidget {
  final HabitCategory category;
  final void Function(
    String name,
    HabitTrackingType trackingType,
    double dailyTarget,
    String targetUnit,
    Set<int> activeDays,
  ) onComplete;

  const HabitSetupScreen({super.key, required this.category, required this.onComplete});

  @override
  State<HabitSetupScreen> createState() => _HabitSetupScreenState();
}

class _HabitSetupScreenState extends State<HabitSetupScreen> {
  final _nameController = TextEditingController();
  HabitTrackingType _trackingType = HabitTrackingType.checkIn;
  double _dailyTarget = 1;
  String _targetUnit = '';
  final Set<int> _activeDays = {1, 2, 3, 4, 5, 6, 7};

  @override
  void initState() {
    super.initState();
    _nameController.text = _defaultName(widget.category);
    _nameController.addListener(() => setState(() {}));
    _trackingType = widget.category.suggestedTrackingType;
    _dailyTarget = _defaultTarget(widget.category);
    _targetUnit = _defaultUnit(widget.category);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _defaultName(HabitCategory category) {
    switch (category) {
      case HabitCategory.exercise: return 'Exercise';
      case HabitCategory.scripture: return 'Bible Reading';
      case HabitCategory.service: return 'Serve Someone';
      case HabitCategory.prayer: return 'Daily Prayer';
      default: return '';
    }
  }

  double _defaultTarget(HabitCategory category) {
    switch (category) {
      case HabitCategory.exercise: return 30;
      case HabitCategory.scripture: return 15;
      case HabitCategory.prayer: return 20;
      default: return 1;
    }
  }

  String _defaultUnit(HabitCategory category) {
    switch (category) {
      case HabitCategory.exercise:
      case HabitCategory.scripture:
      case HabitCategory.prayer: return 'minutes';
      default: return '';
    }
  }

  IconData _categoryIcon() {
    switch (widget.category) {
      case HabitCategory.exercise: return Icons.fitness_center;
      case HabitCategory.scripture: return Icons.menu_book_rounded;
      case HabitCategory.service: return Icons.volunteer_activism_rounded;
      case HabitCategory.prayer: return Icons.self_improvement_rounded;
      default: return Icons.brush_rounded;
    }
  }

  void _submit() {
    widget.onComplete(
      _nameController.text.trim(),
      _trackingType,
      _dailyTarget,
      _targetUnit,
      _activeDays,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nameEmpty = _nameController.text.trim().isEmpty;

    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_categoryIcon(), size: 20, color: GraceWayColor.golden),
              const SizedBox(width: 10),
              Text(
                widget.category.rawValue,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: GraceWayColor.softGold,
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _nameSection(),
            const SizedBox(height: 24),
            _trackingSection(),
            const SizedBox(height: 24),
            if (_trackingType == HabitTrackingType.timed) ...[
              _timedTargetSection(),
              const SizedBox(height: 24),
            ],
            if (_trackingType == HabitTrackingType.count) ...[
              _countTargetSection(),
              const SizedBox(height: 24),
            ],
            _dayOfWeekSection(),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: nameEmpty ? null : _submit,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text(
              'Set this activity',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: GraceWayColor.golden,
              foregroundColor: GraceWayColor.charcoal,
              disabledBackgroundColor: GraceWayColor.golden.withValues(alpha: 0.25),
              disabledForegroundColor: GraceWayColor.charcoal.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _nameSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Activity Name',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: GraceWayColor.softGold.withValues(alpha: 0.6),
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _nameController,
        autofocus: widget.category == HabitCategory.custom,
        style: const TextStyle(fontSize: 16, color: GraceWayColor.warmWhite),
        decoration: InputDecoration(
          hintText: 'e.g. Morning sketching',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          filled: true,
          fillColor: GraceWayColor.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: GraceWayColor.golden.withValues(alpha: 0.5), width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    ]);
  }

  Widget _trackingSection() {
    const types = [HabitTrackingType.checkIn, HabitTrackingType.timed, HabitTrackingType.count];
    const labels = {
      HabitTrackingType.checkIn: 'Yes / No',
      HabitTrackingType.timed: 'Timed',
      HabitTrackingType.count: 'Count',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'How do you want to track this?',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: GraceWayColor.softGold.withValues(alpha: 0.6),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: types.map((type) {
          final selected = _trackingType == type;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: type != types.last ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() {
                  _trackingType = type;
                  if (type == HabitTrackingType.timed) {
                    _dailyTarget = 30;
                    _targetUnit = 'minutes';
                  } else if (type == HabitTrackingType.count) {
                    _dailyTarget = 1;
                    _targetUnit = '';
                  } else {
                    _dailyTarget = 1;
                    _targetUnit = '';
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? GraceWayColor.golden : GraceWayColor.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      labels[type]!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected ? GraceWayColor.charcoal : GraceWayColor.softGold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _timedTargetSection() {
    const minuteOptions = [15.0, 20.0, 30.0, 45.0, 60.0];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Daily Goal (minutes)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: GraceWayColor.softGold.withValues(alpha: 0.6),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: minuteOptions.map((mins) {
          final selected = _dailyTarget == mins;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: mins != minuteOptions.last ? 8 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _dailyTarget = mins),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? GraceWayColor.golden : GraceWayColor.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${mins.toInt()}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: selected ? GraceWayColor.charcoal : GraceWayColor.softGold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _countTargetSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Daily Goal',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: GraceWayColor.softGold.withValues(alpha: 0.6),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Text(
          '${_dailyTarget.toInt()}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: GraceWayColor.golden),
        ),
        const SizedBox(width: 12),
        Column(children: [
          GestureDetector(
            onTap: () => setState(() => _dailyTarget = (_dailyTarget + 1).clamp(1, 100)),
            child: const Icon(Icons.keyboard_arrow_up, color: GraceWayColor.golden),
          ),
          GestureDetector(
            onTap: () => setState(() => _dailyTarget = (_dailyTarget - 1).clamp(1, 100)),
            child: const Icon(Icons.keyboard_arrow_down, color: GraceWayColor.golden),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: TextEditingController(text: _targetUnit)
              ..selection = TextSelection.collapsed(offset: _targetUnit.length),
            onChanged: (v) => _targetUnit = v,
            style: const TextStyle(fontSize: 15, color: GraceWayColor.warmWhite),
            decoration: InputDecoration(
              hintText: 'Unit (e.g. glasses)',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
              filled: true,
              fillColor: GraceWayColor.cardBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _dayOfWeekSection() {
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Active days',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: GraceWayColor.softGold.withValues(alpha: 0.6),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final day = i + 1;
          final selected = _activeDays.contains(day);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) {
                _activeDays.remove(day);
              } else {
                _activeDays.add(day);
              }
            }),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? GraceWayColor.golden : GraceWayColor.cardBackground,
                border: Border.all(
                  color: selected ? GraceWayColor.golden : GraceWayColor.cardBorder,
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  dayLabels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? GraceWayColor.charcoal : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    ]);
  }
}
