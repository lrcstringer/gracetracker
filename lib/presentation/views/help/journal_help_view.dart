import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'help_widgets.dart';

class JournalHelpView extends StatelessWidget {
  const JournalHelpView({super.key});

  @override
  Widget build(BuildContext context) {
    const accentLight = Color(0xFFBFA88A);
    const golden = GraceWayColor.golden;

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        title: const Text('Journal — Help'),
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
              icon: Icons.menu_book_outlined,
              accentColor: accentLight,
              title: 'Journal',
              subtitle:
                  'Your private space for reflection,\nprayer notes, and spiritual insights.',
            ),

            // ── Features ──────────────────────────────────────────────────
            const HelpSectionTitle(title: 'What you can do'),
            HelpFeatureGrid(
              cards: const [
                HelpFeatureCard(
                  icon: Icons.edit_outlined,
                  iconColor: accentLight,
                  iconBg: Color(0x26BFA88A),
                  title: 'Write Entries',
                  description:
                      'Capture reflections, prayers, or insights. Add text, photos, and voice notes.',
                ),
                HelpFeatureCard(
                  icon: Icons.label_outline,
                  iconColor: golden,
                  iconBg: Color(0x26D4A843),
                  title: 'Tag by Source',
                  description:
                      'Link entries to a habit or a fruit of the Spirit for easy filtering later.',
                ),
                HelpFeatureCard(
                  icon: Icons.palette_outlined,
                  iconColor: GraceWayColor.sage,
                  iconBg: Color(0x267A9E7E),
                  title: 'Journal Themes',
                  description:
                      'Switch visual themes — parchment, night, and more — from the palette icon.',
                ),
                HelpFeatureCard(
                  icon: Icons.search_outlined,
                  iconColor: Color(0xFF9BA8C9),
                  iconBg: Color(0x1A9BA8C9),
                  title: 'Search & Sort',
                  description:
                      'Find any entry by keyword or sort by date, habit, or fruit.',
                ),
              ],
            ),

            // ── Entry anatomy ─────────────────────────────────────────────
            const HelpSectionTitle(title: 'Entry card explained'),
            _EntryAnatomy(),

            // ── Steps ─────────────────────────────────────────────────────
            const HelpSectionTitle(title: 'How to use'),
            const HelpStep(
              number: 1,
              icon: Icons.edit_outlined,
              accentColor: accentLight,
              title: 'Create a new entry',
              description:
                  'Tap the pencil (✏️) button in the bottom-right corner to open the composer.',
            ),
            const HelpStep(
              number: 2,
              icon: Icons.text_fields_outlined,
              accentColor: accentLight,
              title: 'Write your reflection',
              description:
                  'Type freely. You can also attach a photo or record a voice memo.',
            ),
            const HelpStep(
              number: 3,
              icon: Icons.label_outline,
              accentColor: golden,
              title: 'Tag your entry',
              description:
                  'Choose a habit or fruit of the Spirit to categorise the entry for future filtering.',
            ),
            const HelpStep(
              number: 4,
              icon: Icons.push_pin_outlined,
              accentColor: GraceWayColor.warmCoral,
              title: 'Pin an important entry',
              description:
                  'Long-press any entry card and choose "Pin" to keep it at the top of your list.',
            ),
            const HelpStep(
              number: 5,
              icon: Icons.search_outlined,
              accentColor: Color(0xFF9BA8C9),
              title: 'Search your entries',
              description:
                  'Tap the search bar at the top and type any keyword to filter results in real time.',
            ),
            const HelpStep(
              number: 6,
              icon: Icons.palette_outlined,
              accentColor: GraceWayColor.sage,
              title: 'Change the theme',
              description:
                  'Tap the palette 🎨 icon in the top bar to switch between journal visual themes.',
              isLast: true,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _EntryAnatomy extends StatelessWidget {
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
            _AnatomyRow(
              icon: Icons.calendar_today_outlined,
              color: const Color(0xFF9BA8C9),
              label: 'Entry date',
            ),
            _divider(),
            _AnatomyRow(
              icon: Icons.push_pin_outlined,
              color: GraceWayColor.warmCoral,
              label: 'Pin icon (pinned entries appear at top)',
            ),
            _divider(),
            _AnatomyRow(
              icon: Icons.label_outline,
              color: GraceWayColor.golden,
              label: 'Source chip: habit name, fruit, or "Journal"',
            ),
            _divider(),
            _AnatomyRow(
              icon: Icons.image_outlined,
              color: GraceWayColor.sage,
              label: 'Media indicators: photo 📷 or voice 🎤',
            ),
            _divider(),
            _AnatomyRow(
              icon: Icons.notes_outlined,
              color: const Color(0xFFBFA88A),
              label: 'Text preview — tap to read full entry',
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

class _AnatomyRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _AnatomyRow(
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
