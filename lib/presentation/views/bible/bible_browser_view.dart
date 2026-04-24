import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/entities/bible_entities.dart';
import '../../providers/bible_provider.dart';
import '../../theme/app_theme.dart';
import 'bible_book_picker_sheet.dart';
import 'bible_bookmarks_sheet.dart';
import 'bible_search_sheet.dart';

class BibleBrowserView extends StatefulWidget {
  final int? initialBook;
  final int? initialChapter;
  final int? highlightVerse;
  /// Human-readable reference like "John 3:16" — takes priority over
  /// [initialBook]/[initialChapter]/[highlightVerse] when provided.
  final String? initialReference;
  /// When provided, a "Use as Scripture Focus" option appears in the long-press
  /// verse action sheet. The callback receives the selected verse, then both
  /// the action sheet and this view are popped.
  final void Function(BibleVerse)? onVerseSelected;

  const BibleBrowserView({
    super.key,
    this.initialBook,
    this.initialChapter,
    this.highlightVerse,
    this.initialReference,
    this.onVerseSelected,
  });

  @override
  State<BibleBrowserView> createState() => _BibleBrowserViewState();
}

class _BibleBrowserViewState extends State<BibleBrowserView> {
  final _scrollController = ScrollController();
  final _verseKeys = <int, GlobalKey>{};
  // Track which chapter's keys are currently in _verseKeys so we only
  // recreate them when the chapter actually changes (not on every rebuild).
  int? _keyedBookNum;
  int? _keyedChapter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialLoad());
  }

  Future<void> _initialLoad() async {
    if (!mounted) return;
    final provider = context.read<BibleProvider>();

    if (!provider.isReady) {
      await provider.ensureReady();
    }

    // Reference string takes priority (e.g. "John 3:16").
    if (widget.initialReference != null) {
      await provider.openByReference(widget.initialReference!);
      if (mounted && provider.highlightVerse != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _scrollToVerse(provider.highlightVerse!);
      }
      return;
    }

    final bookNum = widget.initialBook ?? 1;
    final chapter = widget.initialChapter ?? 1;
    final highlight = widget.highlightVerse;

    // If already on the right chapter, just scroll to the verse.
    if (provider.currentChapter?.book.bookNum == bookNum &&
        provider.currentChapter?.chapter == chapter &&
        provider.currentChapter?.verses.isNotEmpty == true) {
      if (highlight != null) {
        provider.clearHighlight();
        await Future.delayed(Duration.zero);
        if (mounted) _scrollToVerse(highlight);
      }
      return;
    }

    await provider.navigateTo(bookNum, chapter, highlightVerse: highlight);
    if (highlight != null) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _scrollToVerse(highlight);
    }
  }

  void _scrollToVerse(int verseNum) {
    final key = _verseKeys[verseNum];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.2,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<BibleProvider>(
      builder: (context, provider, _) {
        if (provider.isInitialising) {
          return _InitialisingScreen(progress: provider.initProgress);
        }
        return Scaffold(
          backgroundColor: GraceWayColor.charcoal,
          appBar: _buildAppBar(context, provider),
          body: _buildBody(context, provider),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, BibleProvider provider) {
    final chapter = provider.currentChapter;
    final title = chapter != null
        ? '${chapter.book.name} · ${chapter.chapter}'
        : 'Bible';

    return AppBar(
      backgroundColor: GraceWayColor.charcoal,
      foregroundColor: GraceWayColor.warmWhite,
      elevation: 0,
      title: GestureDetector(
        onTap: () => _showBookPicker(context, provider),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: GraceWayColor.warmWhite,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more,
                size: 18, color: GraceWayColor.softGold),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, size: 22),
          tooltip: 'Search',
          onPressed: () => _showSearch(context, provider),
        ),
        PopupMenuButton<_MenuAction>(
          icon: const Icon(Icons.more_vert, size: 22),
          color: GraceWayColor.cardBackground,
          onSelected: (action) => _handleMenu(context, provider, action),
          itemBuilder: (_) => [
            _menuItem(_MenuAction.bookmarks, Icons.bookmark_outline,
                'My Bookmarks'),
            _menuItem(
                _MenuAction.fontUp, Icons.text_increase, 'Larger Text'),
            _menuItem(
                _MenuAction.fontDown, Icons.text_decrease, 'Smaller Text'),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<_MenuAction> _menuItem(
      _MenuAction action, IconData icon, String label) {
    return PopupMenuItem(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: 18, color: GraceWayColor.golden),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: GraceWayColor.warmWhite, fontSize: 14)),
        ],
      ),
    );
  }

  void _handleMenu(
      BuildContext context, BibleProvider provider, _MenuAction action) {
    switch (action) {
      case _MenuAction.bookmarks:
        _showBookmarks(context, provider);
      case _MenuAction.fontUp:
        provider.increaseFontSize();
      case _MenuAction.fontDown:
        provider.decreaseFontSize();
    }
  }

  Widget _buildBody(BuildContext context, BibleProvider provider) {
    if (provider.isChapterLoading) {
      return const Center(
        child: CircularProgressIndicator(color: GraceWayColor.golden),
      );
    }

    final chapter = provider.currentChapter;
    if (chapter == null || chapter.isEmpty) {
      return const Center(
        child: Text('No content',
            style: TextStyle(color: GraceWayColor.softGold)),
      );
    }

    // Only rebuild keys when the chapter actually changes, not on every
    // provider notification — avoids remounting all verse rows unnecessarily.
    if (chapter.book.bookNum != _keyedBookNum ||
        chapter.chapter != _keyedChapter) {
      _verseKeys.clear();
      for (final v in chapter.verses) {
        _verseKeys[v.verseNum] = GlobalKey();
      }
      _keyedBookNum = chapter.book.bookNum;
      _keyedChapter = chapter.chapter;
    }

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: _ChapterHeader(
                    book: chapter.book, chapter: chapter.chapter),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final verse = chapter.verses[i];
                    final isHighlighted =
                        provider.highlightVerse == verse.verseNum;
                    final isBookmarked = provider.isBookmarked(
                        verse.bookNum, verse.chapter, verse.verseNum);
                    return _VerseRow(
                      key: _verseKeys[verse.verseNum],
                      verse: verse,
                      isHighlighted: isHighlighted,
                      isBookmarked: isBookmarked,
                      fontSize: provider.fontSize,
                      onLongPress: () =>
                          _showVerseActions(context, provider, verse),
                    );
                  },
                  childCount: chapter.verses.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
        _ChapterNavBar(provider: provider),
      ],
    );
  }

  // ── Sheets / actions ─────────────────────────────────────────────────────────

  void _showBookPicker(BuildContext context, BibleProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const BibleBookPickerSheet(),
      ),
    );
  }

  void _showSearch(BuildContext context, BibleProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const BibleSearchSheet(),
      ),
    );
  }

  void _showBookmarks(BuildContext context, BibleProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: const BibleBookmarksSheet(),
      ),
    );
  }

  void _showVerseActions(
      BuildContext context, BibleProvider provider, BibleVerse verse) {
    final isBookmarked =
        provider.isBookmarked(verse.bookNum, verse.chapter, verse.verseNum);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: GraceWayColor.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: GraceWayColor.softGold.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                verse.reference,
                style: TextStyle(
                  color: GraceWayColor.golden,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Divider(
                color: GraceWayColor.cardBackground, height: 1),
            _ActionTile(
              icon: Icons.copy_outlined,
              label: 'Copy Verse',
              onTap: () {
                Navigator.pop(context);
                _copyVerse(context, verse);
              },
            ),
            _ActionTile(
              icon: Icons.share_outlined,
              label: 'Share Verse',
              onTap: () {
                Navigator.pop(context);
                _shareVerse(verse);
              },
            ),
            _ActionTile(
              icon: isBookmarked
                  ? Icons.bookmark
                  : Icons.bookmark_border_outlined,
              label: isBookmarked ? 'Remove Bookmark' : 'Bookmark',
              iconColor:
                  isBookmarked ? GraceWayColor.golden : GraceWayColor.softGold,
              onTap: () {
                Navigator.pop(context);
                provider.toggleBookmark(verse);
              },
            ),
            if (widget.onVerseSelected != null)
              _ActionTile(
                icon: Icons.auto_stories_outlined,
                label: 'Use as Scripture Focus',
                onTap: () {
                  Navigator.pop(context); // close action sheet
                  widget.onVerseSelected!(verse);
                  Navigator.pop(context); // close BibleBrowserView
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _copyVerse(BuildContext context, BibleVerse verse) {
    Clipboard.setData(ClipboardData(
      text: '"${verse.text}" — ${verse.reference} (WEB)',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${verse.reference} copied'),
        backgroundColor: GraceWayColor.cardBackground,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareVerse(BibleVerse verse) {
    Share.share('"${verse.text}" — ${verse.reference} (WEB)');
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _InitialisingScreen extends StatelessWidget {
  final double progress;
  const _InitialisingScreen({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 56, color: GraceWayColor.golden),
              const SizedBox(height: 32),
              Text(
                'Preparing Bible…',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 20,
                  color: GraceWayColor.warmWhite,
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor:
                      GraceWayColor.cardBackground,
                  valueColor: const AlwaysStoppedAnimation(GraceWayColor.golden),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                progress > 0
                    ? '${(progress * 100).round()}%'
                    : 'Loading…',
                style: TextStyle(
                  fontSize: 13,
                  color: GraceWayColor.softGold.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'One-time setup',
                style: TextStyle(
                  fontSize: 11,
                  color: GraceWayColor.softGold.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  final BibleBook book;
  final int chapter;

  const _ChapterHeader({required this.book, required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book name
          Text(
            book.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 3.5,
              color: GraceWayColor.golden,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          // Large chapter number
          Text(
            chapter.toString(),
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 64,
              height: 1.0,
              color: GraceWayColor.warmWhite.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            color: GraceWayColor.golden.withValues(alpha: 0.2),
            thickness: 0.5,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _VerseRow extends StatelessWidget {
  final BibleVerse verse;
  final bool isHighlighted;
  final bool isBookmarked;
  final double fontSize;
  final VoidCallback onLongPress;

  const _VerseRow({
    super.key,
    required this.verse,
    required this.isHighlighted,
    required this.isBookmarked,
    required this.fontSize,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? GraceWayColor.golden.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isHighlighted
              ? Border(
                  left: BorderSide(
                    color: GraceWayColor.golden.withValues(alpha: 0.6),
                    width: 2.5,
                  ),
                )
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse number
            SizedBox(
              width: 28,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${verse.verseNum}',
                  style: TextStyle(
                    fontSize: fontSize * 0.65,
                    color: GraceWayColor.golden.withValues(
                        alpha: isHighlighted ? 1.0 : 0.6),
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            // Verse text — plain Text so the outer GestureDetector.onLongPress
            // wins cleanly (SelectableText registers its own LongPressRecognizer
            // which would compete and suppress the action sheet).
            // Copy/Share are available via the long-press action sheet instead.
            Expanded(
              child: Text(
                verse.text,
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: fontSize,
                  color: isHighlighted
                      ? GraceWayColor.warmWhite
                      : GraceWayColor.warmWhite.withValues(alpha: 0.88),
                  height: 1.75,
                ),
                textAlign: TextAlign.justify,
              ),
            ),
            // Bookmark indicator
            if (isBookmarked)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 4),
                child: Icon(
                  Icons.bookmark,
                  size: 14,
                  color: GraceWayColor.golden.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChapterNavBar extends StatelessWidget {
  final BibleProvider provider;
  const _ChapterNavBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasPrev = provider.hasPreviousChapter;
    final hasNext = provider.hasNextChapter;

    // Previous chapter label
    String prevLabel = '';
    if (hasPrev) {
      final book = provider.currentBook;
      final ch = provider.currentChapterNum;
      if (ch > 1) {
        prevLabel = '${book.name} ${ch - 1}';
      } else {
        final prevBook = BibleBook.byNum(book.bookNum - 1);
        if (prevBook != null) {
          prevLabel = '${prevBook.name} ${prevBook.chapterCount}';
        }
      }
    }

    // Next chapter label
    String nextLabel = '';
    if (hasNext) {
      final book = provider.currentBook;
      final ch = provider.currentChapterNum;
      if (ch < book.chapterCount) {
        nextLabel = '${book.name} ${ch + 1}';
      } else {
        final nextBook = BibleBook.byNum(book.bookNum + 1);
        if (nextBook != null) nextLabel = '${nextBook.name} 1';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: GraceWayColor.charcoal,
        border: Border(
          top: BorderSide(
            color: GraceWayColor.golden.withValues(alpha: 0.12),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Previous
            Expanded(
              child: hasPrev
                  ? TextButton.icon(
                      onPressed: provider.previousChapter,
                      icon: const Icon(Icons.chevron_left,
                          size: 20, color: GraceWayColor.golden),
                      label: Text(
                        prevLabel,
                        style: const TextStyle(
                          color: GraceWayColor.softGold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // Next
            Expanded(
              child: hasNext
                  ? TextButton.icon(
                      onPressed: provider.nextChapter,
                      icon: Text(
                        nextLabel,
                        style: const TextStyle(
                          color: GraceWayColor.softGold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      label: const Icon(Icons.chevron_right,
                          size: 20, color: GraceWayColor.golden),
                      iconAlignment: IconAlignment.end,
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          color: iconColor ?? GraceWayColor.softGold, size: 22),
      title: Text(
        label,
        style: const TextStyle(color: GraceWayColor.warmWhite, fontSize: 15),
      ),
      onTap: onTap,
    );
  }
}

enum _MenuAction { bookmarks, fontUp, fontDown }
