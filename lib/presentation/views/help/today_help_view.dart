import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'help_widgets.dart';

class TodayHelpView extends StatelessWidget {
  const TodayHelpView({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = GraceWayColor.golden;
    const sage = GraceWayColor.sage;

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        title: const Text('Today — Help'),
        backgroundColor: GraceWayColor.charcoal,
        foregroundColor: GraceWayColor.warmWhite,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero ─────────────────────────────────────────────────────
            const HelpHero(
              icon: Icons.wb_sunny_outlined,
              accentColor: accent,
              title: 'Gift',
              subtitle:
                  'Your daily hub for gratitude,\nhabit check-ins, and spiritual consistency.',
            ),

            // ── Features ─────────────────────────────────────────────────
            const HelpSectionTitle(title: 'What you can do'),
            HelpFeatureGrid(
              cards: const [
                HelpFeatureCard(
                  icon: Icons.auto_awesome,
                  iconColor: accent,
                  iconBg: Color(0x26D4A843),
                  title: 'Daily Gratitude',
                  description:
                      'Write one thing you\'re thankful for and share it with your circle.',
                ),
                HelpFeatureCard(
                  icon: Icons.check_circle_outline,
                  iconColor: sage,
                  iconBg: Color(0x267A9E7E),
                  title: 'Habit Check-ins',
                  description:
                      'Tap each habit card when you\'ve completed it for the day.',
                ),
                HelpFeatureCard(
                  icon: Icons.calendar_view_week_outlined,
                  iconColor: Color(0xFF9BA8C9),
                  iconBg: Color(0x1A9BA8C9),
                  title: 'Week Navigation',
                  description:
                      'Jump to any day in the current week to log past check-ins.',
                ),
                HelpFeatureCard(
                  icon: Icons.add_circle_outline,
                  iconColor: GraceWayColor.warmCoral,
                  iconBg: Color(0x1AD4836B),
                  title: 'Add Habits',
                  description:
                      'Tap the + button to create new habits and grow your daily practice.',
                ),
              ],
            ),

            // ── Quick-look diagram ────────────────────────────────────────
            const HelpSectionTitle(title: 'Screen at a glance'),
            _ScreenDiagram(),

            // ── Steps ────────────────────────────────────────────────────
            const HelpSectionTitle(title: 'How to use'),
            const HelpStep(
              number: 1,
              icon: Icons.wb_sunny_outlined,
              accentColor: accent,
              title: 'Open the app daily',
              description:
                  'Today\'s date is selected automatically each time you open the app.',
            ),
            const SizedBox(height: 0),
            const HelpStep(
              number: 2,
              icon: Icons.edit_outlined,
              accentColor: accent,
              title: 'Write your gratitude',
              description:
                  'Tap the golden card, type what you\'re thankful for, then tap "Thank you, Lord."',
            ),
            const HelpStep(
              number: 3,
              icon: Icons.check_circle_outline,
              accentColor: sage,
              title: 'Check off your habits',
              description:
                  'Tap a habit card once you\'ve completed it. It will animate to show it\'s done.',
            ),
            const HelpStep(
              number: 4,
              icon: Icons.calendar_view_week_outlined,
              accentColor: Color(0xFF9BA8C9),
              title: 'Log a past day',
              description:
                  'Tap any earlier day in the week strip to retroactively log check-ins.',
            ),
            const HelpStep(
              number: 5,
              icon: Icons.add_circle_outline,
              accentColor: GraceWayColor.warmCoral,
              title: 'Add a new habit',
              description:
                  'Tap the + button (bottom-right) to add a habit. Free plan allows 2 habits; upgrade for unlimited.',
              isLast: true,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ScreenDiagram extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: GraceWayColor.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GraceWayColor.cardBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _DiagramRow(
              icon: Icons.calendar_view_week_outlined,
              color: const Color(0xFF9BA8C9),
              label: 'Week strip — tap a day to navigate',
            ),
            _divider(),
            _DiagramRow(
              icon: Icons.auto_awesome,
              color: GraceWayColor.golden,
              label: 'Daily Gratitude card (golden)',
            ),
            _divider(),
            _DiagramRow(
              icon: Icons.check_circle_outline,
              color: GraceWayColor.sage,
              label: 'Habit cards grouped by category',
            ),
            _divider(),
            _DiagramRow(
              icon: Icons.add_circle_outline,
              color: GraceWayColor.warmCoral,
              label: '+ FAB — add a new habit',
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(
        color: GraceWayColor.warmWhite.withValues(alpha: 0.07),
        height: 1,
      );
}

class _DiagramRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _DiagramRow(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: GraceWayColor.warmWhite.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
