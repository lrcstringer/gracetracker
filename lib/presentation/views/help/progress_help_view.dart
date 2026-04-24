import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'help_widgets.dart';

class ProgressHelpView extends StatelessWidget {
  const ProgressHelpView({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = GraceWayColor.sage;
    const golden = GraceWayColor.golden;

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        title: const Text('Progress — Help'),
        backgroundColor: GraceWayColor.charcoal,
        foregroundColor: GraceWayColor.warmWhite,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero ──────────────────────────────────────────────────────
            const HelpHero(
              icon: Icons.bar_chart_rounded,
              accentColor: accent,
              title: 'Progress',
              subtitle:
                  'Celebrate your journey.\nSee how your faithfulness adds up over time.',
            ),

            // ── Features ──────────────────────────────────────────────────
            const HelpSectionTitle(title: 'What you can see'),
            HelpFeatureGrid(
              cards: const [
                HelpFeatureCard(
                  icon: Icons.emoji_events_outlined,
                  iconColor: golden,
                  iconBg: Color(0x26D4A843),
                  title: 'Journey Stats',
                  description:
                      'All-time totals: days of gratitude, check-ins, and milestones.',
                ),
                HelpFeatureCard(
                  icon: Icons.donut_large_outlined,
                  iconColor: accent,
                  iconBg: Color(0x267A9E7E),
                  title: 'This Week',
                  description:
                      'A visual tier ring shows how strong your current week is.',
                ),
                HelpFeatureCard(
                  icon: Icons.grid_view_outlined,
                  iconColor: Color(0xFF9BA8C9),
                  iconBg: Color(0x1A9BA8C9),
                  title: 'Habit Dot Grid',
                  description:
                      'Each habit row shows 7 coloured dots — one per day of the week.',
                ),
                HelpFeatureCard(
                  icon: Icons.calendar_month_outlined,
                  iconColor: GraceWayColor.warmCoral,
                  iconBg: Color(0x1AD4836B),
                  title: 'Year Heatmap',
                  description:
                      '52 weeks of activity in one view. Premium feature.',
                ),
              ],
            ),

            // ── Week tier guide ───────────────────────────────────────────
            const HelpSectionTitle(title: 'Week tiers'),
            _WeekTierGuide(),

            // ── Steps ─────────────────────────────────────────────────────
            const HelpSectionTitle(title: 'Reading your progress'),
            const HelpStep(
              number: 1,
              icon: Icons.emoji_events_outlined,
              accentColor: golden,
              title: 'Check your all-time count',
              description:
                  'The large number at the top is every day you\'ve given since you started.',
            ),
            const HelpStep(
              number: 2,
              icon: Icons.donut_large_outlined,
              accentColor: accent,
              title: 'Read this week\'s ring',
              description:
                  'The circular ring fills as your week grows — aim for "Beautiful week" (full ring).',
            ),
            const HelpStep(
              number: 3,
              icon: Icons.grid_view_outlined,
              accentColor: Color(0xFF9BA8C9),
              title: 'Spot habits you missed',
              description:
                  'Unfilled dots in the habit grid show days a habit wasn\'t checked off.',
            ),
            const HelpStep(
              number: 4,
              icon: Icons.star_outline,
              accentColor: golden,
              title: 'Watch for milestones',
              description:
                  'Milestone callout cards appear when a habit is approaching a streak goal.',
            ),
            const HelpStep(
              number: 5,
              icon: Icons.calendar_month_outlined,
              accentColor: GraceWayColor.warmCoral,
              title: 'Unlock the year heatmap',
              description:
                  'Tap the blurred heatmap section to upgrade and see your full 52-week history.',
              isLast: true,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _WeekTierGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tiers = [
      _TierRow(
        color: GraceWayColor.warmWhite.withValues(alpha: 0.15),
        label: 'Just getting started',
        note: '0 habits completed',
      ),
      _TierRow(
        color: GraceWayColor.sage.withValues(alpha: 0.4),
        label: 'Something given',
        note: 'A few habits done',
      ),
      _TierRow(
        color: GraceWayColor.sage,
        label: 'Strong week',
        note: 'Most habits completed',
      ),
      _TierRow(
        color: GraceWayColor.golden,
        label: 'Beautiful week',
        note: 'All habits completed',
        isTop: true,
      ),
    ];

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
          children: tiers
              .map((t) => t)
              .expand((t) => [t, if (t != tiers.last) Divider(color: GraceWayColor.warmWhite.withValues(alpha: 0.07), height: 1)])
              .toList(),
        ),
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final Color color;
  final String label;
  final String note;
  final bool isTop;

  const _TierRow({
    required this.color,
    required this.label,
    required this.note,
    this.isTop = false,
  });

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
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              color: color.withValues(alpha: 0.12),
            ),
            child: isTop
                ? Icon(Icons.star, color: color, size: 16)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isTop ? color : GraceWayColor.warmWhite.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  note,
                  style: TextStyle(
                    color: GraceWayColor.warmWhite.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
