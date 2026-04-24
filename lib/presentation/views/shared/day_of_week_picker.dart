import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class DayOfWeekPicker extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final bool isAbstain;

  const DayOfWeekPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.isAbstain = false,
  });

  static const _days = [
    (id: 1, label: 'S'),
    (id: 2, label: 'M'),
    (id: 3, label: 'T'),
    (id: 4, label: 'W'),
    (id: 5, label: 'T'),
    (id: 6, label: 'F'),
    (id: 7, label: 'S'),
  ];

  static const _names = {1: 'Sun', 2: 'Mon', 3: 'Tue', 4: 'Wed', 5: 'Thu', 6: 'Fri', 7: 'Sat'};

  String get _description {
    final sorted = selected.toList()..sort();
    final names = sorted.map((d) => _names[d] ?? '').where((s) => s.isNotEmpty);
    return '${names.join(', ')} · ${selected.length} days/week';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAbstain ? 'Which days are you committing to this?' : 'Which days will you do this?',
          style: TextStyle(
            color: GraceWayColor.softGold.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _days.map((day) {
            final isSelected = selected.contains(day.id);
            return GestureDetector(
              onTap: () {
                final updated = Set<int>.from(selected);
                if (isSelected) {
                  if (updated.length > 1) updated.remove(day.id);
                } else {
                  updated.add(day.id);
                }
                onChanged(updated);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? GraceWayColor.golden : GraceWayColor.surfaceOverlay,
                ),
                alignment: Alignment.center,
                child: Text(
                  day.label,
                  style: TextStyle(
                    color: isSelected ? GraceWayColor.charcoal : GraceWayColor.softGold.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (selected.length < 7) ...[
          const SizedBox(height: 6),
          Text(
            _description,
            style: TextStyle(
              color: GraceWayColor.softGold.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}
