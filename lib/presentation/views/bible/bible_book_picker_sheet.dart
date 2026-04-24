import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/bible_entities.dart';
import '../../providers/bible_provider.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet for selecting a book and chapter.
/// Shows OT / NT toggle → scrollable book chips → chapter grid.
class BibleBookPickerSheet extends StatefulWidget {
  const BibleBookPickerSheet({super.key});

  @override
  State<BibleBookPickerSheet> createState() => _BibleBookPickerSheetState();
}

class _BibleBookPickerSheetState extends State<BibleBookPickerSheet> {
  bool _showOT = true;
  BibleBook? _selectedBook;

  @override
  void initState() {
    super.initState();
    final provider = context.read<BibleProvider>();
    final current = provider.currentChapter?.book;
    if (current != null) {
      _showOT = current.isOldTestament;
      _selectedBook = current;
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = _showOT ? BibleBook.oldTestament : BibleBook.newTestament;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
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
            // Handle
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
            const SizedBox(height: 12),

            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Go to…',
                      style: TextStyle(
                        color: GraceWayColor.warmWhite,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      )),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 20, color: GraceWayColor.softGold),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // OT / NT toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _TestamentTab(
                    label: 'Old Testament',
                    selected: _showOT,
                    onTap: () => setState(() {
                      _showOT = true;
                      _selectedBook = null;
                    }),
                  ),
                  const SizedBox(width: 8),
                  _TestamentTab(
                    label: 'New Testament',
                    selected: !_showOT,
                    onTap: () => setState(() {
                      _showOT = false;
                      _selectedBook = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(
                height: 1,
                color: GraceWayColor.golden.withValues(alpha: 0.12)),

            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Book chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: books.map((book) {
                      final isSelected = _selectedBook?.bookNum == book.bookNum;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedBook = book),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? GraceWayColor.golden.withValues(alpha: 0.15)
                                : GraceWayColor.charcoal,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? GraceWayColor.golden
                                  : GraceWayColor.softGold.withValues(alpha: 0.2),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            book.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? GraceWayColor.golden
                                  : GraceWayColor.softGold,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Chapter grid (shown after book is selected)
                  if (_selectedBook != null) ...[
                    const SizedBox(height: 20),
                    Divider(
                        height: 1,
                        color: GraceWayColor.golden.withValues(alpha: 0.12)),
                    const SizedBox(height: 16),
                    Text(
                      'Chapter',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: GraceWayColor.softGold.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ChapterGrid(
                      book: _selectedBook!,
                      onChapterTap: (ch) {
                        Navigator.pop(context);
                        context.read<BibleProvider>().navigateTo(
                              _selectedBook!.bookNum,
                              ch,
                            );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestamentTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TestamentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? GraceWayColor.golden.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? GraceWayColor.golden
                : GraceWayColor.softGold.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            color:
                selected ? GraceWayColor.golden : GraceWayColor.softGold,
          ),
        ),
      ),
    );
  }
}

class _ChapterGrid extends StatelessWidget {
  final BibleBook book;
  final ValueChanged<int> onChapterTap;

  const _ChapterGrid({required this.book, required this.onChapterTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: book.chapterCount,
      itemBuilder: (_, i) {
        final ch = i + 1;
        return GestureDetector(
          onTap: () => onChapterTap(ch),
          child: Container(
            decoration: BoxDecoration(
              color: GraceWayColor.charcoal,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: GraceWayColor.softGold.withValues(alpha: 0.2),
              ),
            ),
            child: Center(
              child: Text(
                '$ch',
                style: const TextStyle(
                  fontSize: 13,
                  color: GraceWayColor.warmWhite,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
