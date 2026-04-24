import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Large gradient hero banner at the top of each Help screen.
class HelpHero extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;

  const HelpHero({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.22),
            accentColor.withValues(alpha: 0.06),
            GraceWayColor.charcoal,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: accentColor, size: 42),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: GraceWayColor.warmWhite,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: GraceWayColor.warmWhite.withValues(alpha: 0.58),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercase section label with a trailing rule line.
class HelpSectionTitle extends StatelessWidget {
  final String title;

  const HelpSectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: GraceWayColor.warmWhite.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: GraceWayColor.warmWhite.withValues(alpha: 0.09),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single feature card: coloured icon tile + title + description.
class HelpFeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;

  const HelpFeatureCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: GraceWayColor.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GraceWayColor.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 11),
          Text(
            title,
            style: const TextStyle(
              color: GraceWayColor.warmWhite,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              color: GraceWayColor.warmWhite.withValues(alpha: 0.52),
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// A timeline step: numbered circle → connector line → content card.
class HelpStep extends StatelessWidget {
  final int number;
  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;
  final bool isLast;

  const HelpStep({
    super.key,
    required this.number,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Numbered badge + vertical connector
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: GraceWayColor.warmWhite.withValues(alpha: 0.07),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 13),
            // Step content card
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: GraceWayColor.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GraceWayColor.cardBorder),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: GraceWayColor.warmWhite,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(
                                color: GraceWayColor.warmWhite
                                    .withValues(alpha: 0.52),
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        icon,
                        color: accentColor.withValues(alpha: 0.65),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2-column grid layout for feature cards.
class HelpFeatureGrid extends StatelessWidget {
  final List<HelpFeatureCard> cards;

  const HelpFeatureGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
        children: cards,
      ),
    );
  }
}
