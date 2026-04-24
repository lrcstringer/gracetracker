import 'package:flutter/material.dart';
import '../../../domain/entities/habit.dart';
import '../../theme/app_theme.dart';

class HabitSelectionScreen extends StatelessWidget {
  final void Function(HabitCategory) onSelect;
  const HabitSelectionScreen({super.key, required this.onSelect});

  static const _options = [
    _ActivityOption(
      label: 'Exercise',
      subtitle: 'Movement, sport, a daily walk',
      icon: Icons.fitness_center,
      category: HabitCategory.exercise,
    ),
    _ActivityOption(
      label: 'Creativity',
      subtitle: 'Write, draw, make music, create',
      icon: Icons.brush_rounded,
      category: HabitCategory.custom,
    ),
    _ActivityOption(
      label: "God's Word",
      subtitle: 'Bible reading, devotions, study',
      icon: Icons.menu_book_rounded,
      category: HabitCategory.scripture,
    ),
    _ActivityOption(
      label: 'Prayer',
      subtitle: 'Daily time talking with God',
      icon: Icons.self_improvement_rounded,
      category: HabitCategory.prayer,
    ),
    _ActivityOption(
      label: 'Breaking Patterns',
      subtitle: 'Overcoming bad/persistent habits, optionally with support partners and our Freedom Path activities guide',
      icon: Icons.shield_rounded,
      category: HabitCategory.abstain,
      color: GraceWayColor.warmCoral,
    ),
    _ActivityOption(
      label: 'Service',
      subtitle: 'Give, help, volunteer, serve',
      icon: Icons.volunteer_activism_rounded,
      category: HabitCategory.service,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'One small activity\nto start.',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: GraceWayColor.warmWhite,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Pick something simple \u2014 you\u2019re not committing to forever. You can change or delete this any time.',
              style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5), height: 1.5),
            ),
            const SizedBox(height: 28),
            ..._options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ActivityTile(option: opt, onTap: () => onSelect(opt.category)),
            )),
          ]),
        ),
      ),
    ]);
  }
}

class _ActivityOption {
  final String label;
  final String subtitle;
  final IconData icon;
  final HabitCategory category;
  final Color? color;

  const _ActivityOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.category,
    this.color,
  });
}

class _ActivityTile extends StatelessWidget {
  final _ActivityOption option;
  final VoidCallback onTap;

  const _ActivityTile({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: GraceWayColor.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GraceWayColor.cardBorder, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (option.color ?? GraceWayColor.golden).withValues(alpha: 0.1),
            ),
            child: Icon(option.icon, size: 20, color: option.color ?? GraceWayColor.golden),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                option.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: GraceWayColor.warmWhite,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                option.subtitle,
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
              ),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white.withValues(alpha: 0.3)),
        ]),
      ),
    );
  }
}
