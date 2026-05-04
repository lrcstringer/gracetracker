import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../../domain/entities/journal_theme.dart';
import '../../providers/journal_provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/app_theme.dart';
import 'journal_entry_composer.dart';
import 'journal_entry_detail_view.dart';
import '../shared/appbar_actions.dart';
import '../shared/graceway_paywall_view.dart';
import '../help/journal_help_view.dart';

class JournalTab extends StatefulWidget {
  const JournalTab({super.key});

  @override
  State<JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<JournalTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showSortSheet(BuildContext context, JournalProvider provider) {
    const theme = JournalTheme.parchment;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final current = provider.sortOrder;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Sort by',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              for (final order in JournalSortOrder.values)
                ListTile(
                  title: Text(_sortLabel(order),
                      style: TextStyle(
                          color: theme.textPrimary, fontSize: 14)),
                  trailing: current == order
                      ? Icon(Icons.check,
                          color: theme.textSecondary, size: 18)
                      : null,
                  onTap: () {
                    provider.setSortOrder(order);
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _sortLabel(JournalSortOrder order) {
    switch (order) {
      case JournalSortOrder.newestFirst:
        return 'Newest first';
      case JournalSortOrder.oldestFirst:
        return 'Oldest first';
      case JournalSortOrder.byHabit:
        return 'By habit';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();
    final isPremium = context.watch<StoreProvider>().isPremium;
    const theme = JournalTheme.parchment;
    final entries = provider.filteredEntries;

    return Scaffold(
      backgroundColor: theme.bgPrimary,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (isPremium) {
            Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const JournalEntryComposer()),
            );
          } else {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: GraceWayColor.charcoal,
              builder: (_) => const GraceWayPaywallView(),
            );
          }
        },
        backgroundColor: theme.textPrimary,
        foregroundColor: theme.bgCard,
        child: const Icon(Icons.edit_outlined),
      ),
      body: CustomScrollView(
        slivers: [
          // ── Hero image app bar ───────────────────────────────────────────
          SliverAppBar(
            backgroundColor: theme.bgPrimary,
            foregroundColor: theme.textPrimary,
            expandedHeight: 220,
            pinned: true,
            automaticallyImplyLeading: false,
            title: Text(
              'Grace Tracker',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    theme.heroImageAsset,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          theme.bgPrimary.withValues(alpha: 0.5),
                          theme.bgPrimary,
                        ],
                        stops: const [0.0, 0.65, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 14,
                    child: Text(
                      'Journal',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              infoIconAction(context, const JournalHelpView(),
                  color: theme.textPrimary),
              IconButton(
                icon: Icon(Icons.sort, size: 26, color: theme.textPrimary),
                onPressed: () => _showSortSheet(context, provider),
                tooltip: 'Sort',
              ),
            ],
          ),

          // ── Search bar ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: provider.setSearchQuery,
                style: TextStyle(color: theme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search entries...',
                  hintStyle: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search,
                      size: 18, color: theme.textSecondary),
                  suffixIcon: provider.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close,
                              size: 16, color: theme.textSecondary),
                          onPressed: () {
                            _searchCtrl.clear();
                            provider.setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.bgCard,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // ── Loading ──────────────────────────────────────────────────────
          if (provider.isLoading)
            SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: theme.textSecondary,
                  strokeWidth: 2,
                ),
              ),
            )

          // ── Empty state ──────────────────────────────────────────────────
          else if (entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.book_outlined,
                        size: 48,
                        color: theme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        provider.searchQuery.isNotEmpty
                            ? 'No entries match your search'
                            : 'Your spiritual journey starts here.\nTap + to add your first entry.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: theme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )

          // ── Entry list ────────────────────────────────────────────────────
          else ...[
            Builder(builder: (context) {
              final pinnedCount = entries.where((e) => e.pinned).length;
              final unpinnedCount = entries.length - pinnedCount;

              return SliverMainAxisGroup(slivers: [
                // Pinned section
                if (pinnedCount > 0) ...[
                  SliverToBoxAdapter(
                    child: _SectionLabel(
                        label: 'PINNED', icon: Icons.push_pin_rounded, theme: theme),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final entry = entries[i];
                          return _JournalEntryCard(
                            entry: entry,
                            theme: theme,
                            onTap: () => Navigator.push<void>(ctx,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        JournalEntryDetailView(entry: entry))),
                            onLongPress: () =>
                                _showPinSheet(ctx, entry, provider),
                          );
                        },
                        childCount: pinnedCount,
                      ),
                    ),
                  ),
                ],

                // Unpinned section
                if (unpinnedCount > 0) ...[
                  if (pinnedCount > 0)
                    SliverToBoxAdapter(
                      child: _SectionLabel(
                          label: 'ENTRIES', icon: null, theme: theme),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final entry = entries[pinnedCount + i];
                          return _JournalEntryCard(
                            entry: entry,
                            theme: theme,
                            onTap: () => Navigator.push<void>(ctx,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        JournalEntryDetailView(entry: entry))),
                            onLongPress: () =>
                                _showPinSheet(ctx, entry, provider),
                          );
                        },
                        childCount: unpinnedCount,
                      ),
                    ),
                  ),
                ],
              ]);
            }),
          ],
        ],
      ),
    );
  }
}

// ── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;
  final JournalTheme theme;

  const _SectionLabel({required this.label, required this.icon, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: theme.accentAction.withValues(alpha: 0.7)),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.textSecondary.withValues(alpha: 0.6),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pin sheet ────────────────────────────────────────────────────────────────

void _showPinSheet(BuildContext context, JournalEntry entry, JournalProvider provider) {
  const theme = JournalTheme.parchment;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: theme.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: theme.textSecondary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Icon(
              entry.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              color: theme.accentAction,
            ),
            title: Text(
              entry.pinned ? 'Unpin entry' : 'Pin to top',
              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w500),
            ),
            onTap: () {
              Navigator.pop(context);
              provider.togglePin(entry);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

// ── Entry Card ───────────────────────────────────────────────────────────────

class _JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final JournalTheme theme;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _JournalEntryCard({
    required this.entry,
    required this.theme,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: theme.textSecondary.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: date + media indicators
            Row(
              children: [
                if (entry.pinned) ...[
                  Icon(Icons.push_pin_rounded,
                      size: 12, color: theme.accentAction.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                ],
                Text(
                  _shortDate(entry.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textSecondary,
                  ),
                ),
                const Spacer(),
              ],
            ),

            const SizedBox(height: 8),

            // Source chip
            _SourceChip(entry: entry, theme: theme),

            // Text preview
            Builder(builder: (context) {
              final preview = JournalEntry.extractPlainText(entry.text);
              if (preview.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ── Source Chip (card) ───────────────────────────────────────────────────────

class _SourceChip extends StatelessWidget {
  final JournalEntry entry;
  final JournalTheme theme;

  const _SourceChip({required this.entry, required this.theme});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    String label;

    if (entry.habitName != null) {
      chipColor = GraceWayColor.golden;
      label = entry.habitName!;
    } else {
      chipColor = theme.textSecondary;
      label = 'Journal';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: chipColor.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
