import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/bible_entities.dart';
import '../../providers/bible_provider.dart';
import '../../theme/app_theme.dart';

/// Full-text search sheet — debounced, shows up to 50 results.
class BibleSearchSheet extends StatefulWidget {
  const BibleSearchSheet({super.key});

  @override
  State<BibleSearchSheet> createState() => _BibleSearchSheetState();
}

class _BibleSearchSheetState extends State<BibleSearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final BibleProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<BibleProvider>();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _provider.clearSearch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: context.read<BibleProvider>().search,
                      style: const TextStyle(
                          color: GraceWayColor.warmWhite, fontSize: 15),
                      cursorColor: GraceWayColor.golden,
                      decoration: InputDecoration(
                        hintText: 'Search Scripture…',
                        hintStyle: TextStyle(
                          color: GraceWayColor.softGold.withValues(alpha: 0.5),
                          fontSize: 15,
                        ),
                        prefixIcon: const Icon(Icons.search,
                            color: GraceWayColor.golden, size: 20),
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    size: 18,
                                    color: GraceWayColor.softGold),
                                onPressed: () {
                                  _controller.clear();
                                  context.read<BibleProvider>().clearSearch();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: GraceWayColor.charcoal,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: GraceWayColor.golden, fontSize: 14)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(
                height: 1,
                color: GraceWayColor.golden.withValues(alpha: 0.12)),

            // Results
            Expanded(
              child: Consumer<BibleProvider>(
                builder: (context, provider, _) {
                  if (provider.isSearching) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: GraceWayColor.golden, strokeWidth: 2),
                    );
                  }

                  final query = _controller.text.trim();
                  if (query.isEmpty) {
                    return Center(
                      child: Text(
                        'Type to search all 31,102 verses',
                        style: TextStyle(
                          color: GraceWayColor.softGold.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  if (provider.searchResults.isEmpty) {
                    return Center(
                      child: Text(
                        'No results for "$query"',
                        style: TextStyle(
                          color: GraceWayColor.softGold.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: provider.searchResults.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: GraceWayColor.golden.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, i) {
                      final verse = provider.searchResults[i];
                      return _SearchResultTile(
                        verse: verse,
                        query: query,
                        onTap: () {
                          Navigator.pop(context);
                          provider.navigateTo(
                            verse.bookNum,
                            verse.chapter,
                            highlightVerse: verse.verseNum,
                          );
                        },
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
}

class _SearchResultTile extends StatelessWidget {
  final BibleVerse verse;
  final String query;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.verse,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      title: Text(
        verse.reference,
        style: const TextStyle(
          color: GraceWayColor.golden,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: _HighlightedText(
          text: verse.text,
          query: query,
        ),
      ),
    );
  }
}

/// Renders verse text with the search query highlighted in gold.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;

  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text,
          style: TextStyle(
            color: GraceWayColor.warmWhite.withValues(alpha: 0.75),
            fontSize: 13,
            height: 1.5,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: const TextStyle(
          color: GraceWayColor.golden,
          fontWeight: FontWeight.w700,
        ),
      ));
      start = idx + query.length;
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          color: GraceWayColor.warmWhite.withValues(alpha: 0.75),
          fontSize: 13,
          height: 1.5,
        ),
        children: spans,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}
