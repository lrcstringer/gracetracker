import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'help_widgets.dart';

class CirclesHelpView extends StatelessWidget {
  const CirclesHelpView({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = GraceWayColor.sage;
    const golden = GraceWayColor.golden;

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        title: const Text('Circles — Help'),
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
              icon: Icons.groups_outlined,
              accentColor: accent,
              title: 'Prayer Circles',
              subtitle:
                  'Pray together with family and friends.\nSpur one another on in love and good deeds.',
            ),

            // ── Features ──────────────────────────────────────────────────
            const HelpSectionTitle(title: 'What circles give you'),
            HelpFeatureGrid(
              cards: const [
                HelpFeatureCard(
                  icon: Icons.groups_outlined,
                  iconColor: accent,
                  iconBg: Color(0x267A9E7E),
                  title: 'Prayer Circles',
                  description:
                      'Create private circles with family, friends, or accountability partners.',
                ),
                HelpFeatureCard(
                  icon: Icons.bar_chart_rounded,
                  iconColor: golden,
                  iconBg: Color(0x26D4A843),
                  title: 'Shared Progress',
                  description:
                      'See each member\'s check-in progress so you can pray for and encourage one another.',
                ),
                HelpFeatureCard(
                  icon: Icons.calendar_today_outlined,
                  iconColor: Color(0xFF9BA8C9),
                  iconBg: Color(0x1A9BA8C9),
                  title: 'Sunday Summary',
                  description:
                      'A weekly highlight reel of your circle\'s activity, delivered on Sundays.',
                ),
                HelpFeatureCard(
                  icon: Icons.link_outlined,
                  iconColor: GraceWayColor.warmCoral,
                  iconBg: Color(0x1AD4836B),
                  title: 'Easy Invites',
                  description:
                      'Share a simple invite code so anyone can join your circle in seconds.',
                ),
              ],
            ),

            // ── Circle anatomy ────────────────────────────────────────────
            const HelpSectionTitle(title: 'Circle card explained'),
            _CircleCardAnatomy(),

            // ── Steps ─────────────────────────────────────────────────────
            const HelpSectionTitle(title: 'How to use'),
            const HelpStep(
              number: 1,
              icon: Icons.login_outlined,
              accentColor: accent,
              title: 'Sign in to get started',
              description:
                  'Tap "Sign in with Google" or "Sign in with Apple" on the Circles screen.',
            ),
            const HelpStep(
              number: 2,
              icon: Icons.add_circle_outline,
              accentColor: golden,
              title: 'Create or join a circle',
              description:
                  'Tap the + button and choose "Create a Circle" or "Join with Code" to get connected.',
            ),
            const HelpStep(
              number: 3,
              icon: Icons.link_outlined,
              accentColor: GraceWayColor.warmCoral,
              title: 'Invite others',
              description:
                  'Open your circle, find the invite code, and share it with friends or family.',
            ),
            const HelpStep(
              number: 4,
              icon: Icons.auto_awesome,
              accentColor: golden,
              title: 'Share your gratitude',
              description:
                  'After completing your daily gratitude on the Today screen, tap "Share with circle."',
            ),
            const HelpStep(
              number: 5,
              icon: Icons.groups_outlined,
              accentColor: accent,
              title: 'View your circle\'s feed',
              description:
                  'Tap any circle card to see the shared feed, member progress, and prayer requests.',
              isLast: true,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _CircleCardAnatomy extends StatelessWidget {
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
            // Mock circle card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GraceWayColor.charcoal,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: GraceWayColor.warmWhite.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: GraceWayColor.sage.withValues(alpha: 0.25),
                    child: const Text(
                      'F',
                      style: TextStyle(
                        color: GraceWayColor.sage,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Family Circle',
                              style: TextStyle(
                                color: GraceWayColor.warmWhite
                                    .withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: GraceWayColor.golden.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ADMIN',
                                style: TextStyle(
                                  color: GraceWayColor.golden,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 13,
                              color: GraceWayColor.warmWhite.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '4 members',
                              style: TextStyle(
                                color: GraceWayColor.warmWhite.withValues(alpha: 0.45),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: GraceWayColor.warmWhite.withValues(alpha: 0.25),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Legend
            _LegendRow(
              icon: Icons.circle,
              color: GraceWayColor.sage,
              label: 'Circle initial avatar',
            ),
            _LegendRow(
              icon: Icons.badge_outlined,
              color: GraceWayColor.golden,
              label: 'ADMIN badge — shown if you created the circle',
            ),
            _LegendRow(
              icon: Icons.people_outline,
              color: const Color(0xFF9BA8C9),
              label: 'Member count',
            ),
            _LegendRow(
              icon: Icons.chevron_right,
              color: GraceWayColor.warmWhite,
              label: 'Tap to open the circle',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isLast;

  const _LegendRow({
    required this.icon,
    required this.color,
    required this.label,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: GraceWayColor.warmWhite.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            color: GraceWayColor.warmWhite.withValues(alpha: 0.07),
            height: 1,
          ),
      ],
    );
  }
}
