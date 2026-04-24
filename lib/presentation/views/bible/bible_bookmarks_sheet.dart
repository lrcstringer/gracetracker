import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/bible_entities.dart';
import '../../providers/bible_provider.dart';
import '../../theme/app_theme.dart';

/// Sheet showing all saved bookmarks, sorted by most recent.
class BibleBookmarksSheet extends StatelessWidget {
  const BibleBookmarksSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: GraceWayColor.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: GraceWayColor.softGold.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.bookmark,
                      size: 18, color: GraceWayColor.golden),
                  const SizedBox(width: 8),
                  const Text(
                    'My Bookmarks',
                    style: TextStyle(
                      color: GraceWayColor.warmWhite,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 20, color: GraceWayColor.softGold),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: GraceWayColor.golden.withValues(alpha: 0.12)),

            // Bookmarks list
            Expanded(
              child: Consumer<BibleProvider>(
                builder: (context, provider, _) {
                  final bookmarks = provider.bookmarks;

                  if (bookmarks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_border_outlined,
                            size: 48,
                            color: GraceWayColor.softGold.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No bookmarks yet',
                            style: TextStyle(
                              color:
                                  GraceWayColor.softGold.withValues(alpha: 0.6),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Long-press any verse to bookmark it',
                            style: TextStyle(
                              color:
                                  GraceWayColor.softGold.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 32),
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: GraceWayColor.golden.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, i) {
                      final bookmark = bookmarks[i];
                      return _BookmarkTile(
                        bookmark: bookmark,
                        onTap: () {
                          Navigator.pop(context);
                          provider.navigateTo(
                            bookmark.bookNum,
                            bookmark.chapter,
                            highlightVerse: bookmark.verseNum,
                          );
                        },
                        onDelete: () => provider
                            .toggleBookmark(_bookmarkToVerse(bookmark)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  BibleVerse _bookmarkToVerse(BibleBookmark b) => BibleVerse(
        bookNum: b.bookNum,
        chapter: b.chapter,
        verseNum: b.verseNum,
        bookName: b.bookName,
        text: b.text,
      );
}

class _BookmarkTile extends StatelessWidget {
  final BibleBookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BookmarkTile({
    required this.bookmark,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline,
            color: Colors.redAccent, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: onTap,
        leading: const Icon(Icons.bookmark,
            size: 20, color: GraceWayColor.golden),
        title: Text(
          bookmark.reference,
          style: const TextStyle(
            color: GraceWayColor.golden,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            bookmark.text,
            style: TextStyle(
              color: GraceWayColor.warmWhite.withValues(alpha: 0.75),
              fontSize: 13,
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 18, color: GraceWayColor.softGold),
          onPressed: onDelete,
          tooltip: 'Remove bookmark',
        ),
      ),
    );
  }
}
