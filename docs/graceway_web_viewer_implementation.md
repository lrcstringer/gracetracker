# GraceWay WEB Viewer Implementation Guide

## Overview

Two-mode Scripture viewer for GraceWay:
1. **Modal Mode** (in-context): User taps a quoted verse → full chapter opens in modal with that verse highlighted
2. **Full Browser Mode** (standalone): AppBar icon → full Scripture navigation interface with book/chapter/verse selection and search

Both modes share underlying data layer (SQLite), but have distinct UI presentations.

---

## Architecture Overview

```
GraceWay App
├── Assets & Data
│   └── Bible Data Layer
│       └── SQLite Database (WEB bundled as asset)
├── Services
│   └── BibleService (query verses/chapters)
├── UI Components
│   ├── VerseQuote Widget (habit display)
│   │   └── onTap → VerseViewerModal (Modal Mode)
│   ├── BibleViewerPage (Full Browser Mode)
│   └── Shared
│       ├── ChapterDisplay (formatted scripture rendering)
│       ├── VerseHighlight (visual emphasis)
│       └── VerseNavigator (book/chapter/verse picker)
└── State Management
    └── BibleProvider (Riverpod/Bloc for selected verse, font size, etc.)
```

---

## Part 1: Data Layer Setup

### 1.1 Bundle SQLite Database

**File structure:**
```
android/app/src/main/assets/bible/
├── bible.db (WEB translation in SQLite)
└── _manifest.json (metadata: book list, verse counts per chapter)

ios/Runner/
└── bible.db (same file)
```

**Get the database:**
- Option A: Download pre-built WEB SQLite from [Bible SuperSearch](https://www.biblesupersearch.com/bible-downloads/)
- Option B: Convert JSON from [TehShrike's repo](https://github.com/TehShrike/world-english-bible) using provided Python script
- Option C: Use [eBible.org WEB](https://ebible.org/eng-web/) and convert XML → SQLite

**Expected schema:**
```sql
CREATE TABLE verses (
  id INTEGER PRIMARY KEY,
  book_num INTEGER,        -- 1-66 (OT+NT)
  chapter INTEGER,
  verse_num INTEGER,
  verse_text TEXT,
  translation TEXT         -- 'WEB'
);

CREATE INDEX idx_book_chapter_verse 
  ON verses(book_num, chapter, verse_num);
```

### 1.2 Bible Service (Business Logic)

**File:** `lib/services/bible_service.dart`

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';

class VerseData {
  final int bookNum;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;

  VerseData({
    required this.bookNum,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
  });
}

class ChapterData {
  final String bookName;
  final int chapter;
  final List<VerseData> verses;

  ChapterData({
    required this.bookName,
    required this.chapter,
    required this.verses,
  });
}

class BibleService {
  static final BibleService _instance = BibleService._internal();
  late Database _db;
  bool _initialized = false;

  // Book metadata (OT + NT)
  static const List<String> BOOKS = [
    // Old Testament (1-39)
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
    'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
    '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra',
    'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
    'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah', 'Lamentations',
    'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
    'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
    'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    // New Testament (40-66)
    'Matthew', 'Mark', 'Luke', 'John', 'Acts',
    'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy',
    '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
    '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
    'Jude', 'Revelation'
  ];

  factory BibleService() {
    return _instance;
  }

  BibleService._internal();

  /// Initialize database from bundled asset
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final dbPath = await _getLocalDbPath();
      _db = await openDatabase(dbPath);
      _initialized = true;
    } catch (e) {
      print('Bible DB init error: $e');
      rethrow;
    }
  }

  /// Extract bundled database to app documents (run once on first launch)
  Future<String> _getLocalDbPath() async {
    const String dbFileName = 'bible.db';
    
    // Check if already extracted
    final String documentsPath = (await getDatabasesPath());
    final File localFile = File(join(documentsPath, dbFileName));

    if (await localFile.exists()) {
      return localFile.path;
    }

    // Extract from assets
    final ByteData data = await rootBundle.load('assets/bible/$dbFileName');
    final List<int> bytes = data.buffer.asUint8List();
    await localFile.writeAsBytes(bytes);
    
    return localFile.path;
  }

  /// Get entire chapter with all verses
  Future<ChapterData> getChapter(int bookNum, int chapter) async {
    final bookName = BOOKS[bookNum - 1];
    
    final List<Map<String, dynamic>> result = await _db.query(
      'verses',
      where: 'book_num = ? AND chapter = ?',
      whereArgs: [bookNum, chapter],
      orderBy: 'verse_num ASC',
    );

    final verses = result.map((row) => VerseData(
      bookNum: row['book_num'],
      bookName: bookName,
      chapter: row['chapter'],
      verse: row['verse_num'],
      text: row['verse_text'],
    )).toList();

    return ChapterData(
      bookName: bookName,
      chapter: chapter,
      verses: verses,
    );
  }

  /// Get single verse
  Future<VerseData?> getVerse(int bookNum, int chapter, int verse) async {
    final bookName = BOOKS[bookNum - 1];
    
    final List<Map<String, dynamic>> result = await _db.query(
      'verses',
      where: 'book_num = ? AND chapter = ? AND verse_num = ?',
      whereArgs: [bookNum, chapter, verse],
    );

    if (result.isEmpty) return null;

    final row = result.first;
    return VerseData(
      bookNum: row['book_num'],
      bookName: bookName,
      chapter: row['chapter'],
      verse: row['verse_num'],
      text: row['verse_text'],
    );
  }

  /// Parse verse reference string (e.g., "John 3:16" or "John 3")
  /// Returns (bookNum, chapter, verse?) or null if invalid
  Map<String, int>? parseVerseReference(String reference) {
    try {
      final parts = reference.trim().split(RegExp(r'[\s:]+'));
      
      // Handle two-word book names (e.g., "1 Samuel", "Song of Solomon")
      String bookName;
      List<String> numbers;
      
      if (reference.contains(RegExp(r'^\d+'))) {
        // Numbered book like "1 John" or "2 Peter"
        if (parts.length >= 3) {
          bookName = '${parts[0]} ${parts[1]}';
          numbers = parts.skip(2).toList();
        } else {
          return null;
        }
      } else {
        bookName = parts[0];
        numbers = parts.skip(1).toList();
      }

      final bookNum = BOOKS.indexOf(bookName) + 1;
      if (bookNum == 0) return null;

      final chapter = int.tryParse(numbers[0]);
      if (chapter == null) return null;

      final verse = numbers.length > 1 ? int.tryParse(numbers[1]) : null;

      return {
        'bookNum': bookNum,
        'chapter': chapter,
        if (verse != null) 'verse': verse,
      };
    } catch (e) {
      return null;
    }
  }

  /// Get verse count for a chapter (for validation)
  Future<int> getVerseCount(int bookNum, int chapter) async {
    final result = await _db.rawQuery(
      'SELECT MAX(verse_num) as max_verse FROM verses WHERE book_num = ? AND chapter = ?',
      [bookNum, chapter],
    );
    
    return result.isNotEmpty ? (result.first['max_verse'] as int?) ?? 0 : 0;
  }

  /// Search verses by keyword (simple text match)
  Future<List<VerseData>> searchVerses(String keyword, {int limit = 50}) async {
    final List<Map<String, dynamic>> result = await _db.query(
      'verses',
      where: 'verse_text LIKE ?',
      whereArgs: ['%$keyword%'],
      limit: limit,
    );

    return result.map((row) {
      final bookNum = row['book_num'] as int;
      return VerseData(
        bookNum: bookNum,
        bookName: BOOKS[bookNum - 1],
        chapter: row['chapter'],
        verse: row['verse_num'],
        text: row['verse_text'],
      );
    }).toList();
  }

  Future<void> close() async {
    if (_initialized) {
      await _db.close();
    }
  }
}
```

---

## Part 2: UI Components

### 2.1 Shared Verse Rendering Widget

**File:** `lib/widgets/chapter_display.dart`

This renders scripture beautifully: justified text, verse numbers as superscript, poetic/prose formatting.

```dart
import 'package:flutter/material.dart';
import '../services/bible_service.dart';

class ChapterDisplay extends StatelessWidget {
  final ChapterData chapter;
  final int? highlightVerse; // Verse to highlight (scroll to + color)
  final double fontSize;
  final bool showVerseNumbers;

  const ChapterDisplay({
    Key? key,
    required this.chapter,
    this.highlightVerse,
    this.fontSize = 16.0,
    this.showVerseNumbers = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter header
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                '${chapter.bookName} ${chapter.chapter}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Verses
            RichText(
              textAlign: TextAlign.justify,
              text: _buildVerseRichText(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _buildVerseRichText(BuildContext context, bool isDark) {
    final spans = <TextSpan>[];
    
    for (final verse in chapter.verses) {
      final isHighlighted = verse.verse == highlightVerse;
      
      // Verse number as superscript
      if (showVerseNumbers) {
        spans.add(TextSpan(
          text: '${verse.verse}',
          style: TextStyle(
            fontSize: fontSize * 0.65,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            baselineShift: 8.0,
          ),
        ));
        spans.add(const TextSpan(text: ' '));
      }

      // Verse text
      spans.add(TextSpan(
        text: verse.text,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.6,
          color: isHighlighted ? Colors.amber[700] : null,
          backgroundColor: isHighlighted 
            ? Colors.amber[200]?.withOpacity(0.4)
            : null,
          fontWeight: isHighlighted ? FontWeight.w600 : null,
        ),
      ));

      spans.add(const TextSpan(text: ' '));
    }

    return TextSpan(children: spans);
  }
}
```

### 2.2 Verse Reference Picker

**File:** `lib/widgets/verse_reference_picker.dart`

Compact UI for choosing book/chapter/verse or entering text.

```dart
import 'package:flutter/material.dart';
import '../services/bible_service.dart';

class VerseReferencePicker extends StatefulWidget {
  final Function(int bookNum, int chapter, int? verse) onSelected;
  final int? initialBookNum;
  final int? initialChapter;
  final int? initialVerse;

  const VerseReferencePicker({
    Key? key,
    required this.onSelected,
    this.initialBookNum,
    this.initialChapter,
    this.initialVerse,
  }) : super(key: key);

  @override
  State<VerseReferencePicker> createState() => _VerseReferencePickerState();
}

class _VerseReferencePickerState extends State<VerseReferencePicker> {
  late int selectedBookNum;
  late int selectedChapter;
  int? selectedVerse;
  late TextEditingController referenceController;

  @override
  void initState() {
    super.initState();
    selectedBookNum = widget.initialBookNum ?? 43; // John
    selectedChapter = widget.initialChapter ?? 3;
    selectedVerse = widget.initialVerse;
    referenceController = TextEditingController();
  }

  @override
  void dispose() {
    referenceController.dispose();
    super.dispose();
  }

  void _handleReferenceInput(String input) {
    if (input.isEmpty) return;

    final parsed = BibleService().parseVerseReference(input);
    if (parsed != null) {
      setState(() {
        selectedBookNum = parsed['bookNum']!;
        selectedChapter = parsed['chapter']!;
        selectedVerse = parsed['verse'];
      });
      widget.onSelected(selectedBookNum, selectedChapter, selectedVerse);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid verse reference (e.g., "John 3:16")')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Text input for direct reference
            TextField(
              controller: referenceController,
              decoration: InputDecoration(
                hintText: 'e.g., "John 3:16" or "Romans 12"',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _handleReferenceInput(referenceController.text),
                ),
              ),
              onSubmitted: _handleReferenceInput,
            ),
            const SizedBox(height: 24.0),

            // Book picker
            Text('Select Book', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8.0),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: BibleService.BOOKS.length,
                itemBuilder: (context, index) {
                  final bookNum = index + 1;
                  final isSelected = selectedBookNum == bookNum;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: FilterChip(
                      label: Text(BibleService.BOOKS[index]),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => selectedBookNum = bookNum);
                          referenceController.clear();
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24.0),

            // Chapter picker
            Text('Chapter', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8.0),
            _ChapterSpinner(
              selectedChapter: selectedChapter,
              onChanged: (chapter) => setState(() => selectedChapter = chapter),
            ),
            const SizedBox(height: 24.0),

            // Verse picker (optional)
            Text('Verse (optional)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8.0),
            _VerseSpinner(
              selectedVerse: selectedVerse,
              bookNum: selectedBookNum,
              chapter: selectedChapter,
              onChanged: (verse) => setState(() => selectedVerse = verse),
            ),
            const SizedBox(height: 24.0),

            // Confirm button
            ElevatedButton(
              onPressed: () {
                widget.onSelected(selectedBookNum, selectedChapter, selectedVerse);
                Navigator.pop(context);
              },
              child: const Text('View Scripture'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterSpinner extends StatelessWidget {
  final int selectedChapter;
  final Function(int) onChanged;

  const _ChapterSpinner({
    required this.selectedChapter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value: selectedChapter,
      items: List.generate(150, (i) => i + 1)
          .map((ch) => DropdownMenuItem(value: ch, child: Text('$ch')))
          .toList(),
      onChanged: (ch) => onChanged(ch ?? selectedChapter),
    );
  }
}

class _VerseSpinner extends StatelessWidget {
  final int? selectedVerse;
  final int bookNum;
  final int chapter;
  final Function(int?) onChanged;

  const _VerseSpinner({
    required this.selectedVerse,
    required this.bookNum,
    required this.chapter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: BibleService().getVerseCount(bookNum, chapter),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final verseCount = snapshot.data ?? 0;
        if (verseCount == 0) {
          return const Text('No verses found');
        }

        return DropdownButton<int?>(
          value: selectedVerse,
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('(entire chapter)'),
            ),
            ...List.generate(verseCount, (i) => i + 1)
                .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                .toList(),
          ],
          onChanged: (v) => onChanged(v),
        );
      },
    );
  }
}
```

### 2.3 Modal Mode: Verse Tap Handler

**File:** `lib/widgets/verse_quote.dart`

When user taps a quoted verse in habit display, opens modal.

```dart
import 'package:flutter/material.dart';
import '../screens/bible_viewer_modal.dart';

class VerseQuote extends StatelessWidget {
  final String verseReference; // e.g., "John 3:16"
  final String verseText;
  final bool tappable;

  const VerseQuote({
    Key? key,
    required this.verseReference,
    required this.verseText,
    this.tappable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: tappable
          ? () => _showBibleViewerModal(context)
          : null,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          border: Border.left(
            width: 4.0,
            color: Colors.amber[700]!,
          ),
          color: Colors.amber[50],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verseReference,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.amber[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              verseText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (tappable) ...[
              const SizedBox(height: 8.0),
              Text(
                'Tap to open in Bible',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.amber[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBibleViewerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => BibleViewerModal(
        initialReference: verseReference,
      ),
    );
  }
}
```

---

## Part 3: Full Browser Modes

### 3.1 Modal Mode: BibleViewerModal

**File:** `lib/screens/bible_viewer_modal.dart`

Lightweight bottom sheet for in-context scripture viewing.

```dart
import 'package:flutter/material.dart';
import '../services/bible_service.dart';
import '../widgets/chapter_display.dart';
import '../widgets/verse_reference_picker.dart';

class BibleViewerModal extends StatefulWidget {
  final String? initialReference;

  const BibleViewerModal({
    Key? key,
    this.initialReference,
  }) : super(key: key);

  @override
  State<BibleViewerModal> createState() => _BibleViewerModalState();
}

class _BibleViewerModalState extends State<BibleViewerModal> {
  late int bookNum;
  late int chapter;
  int? highlightVerse;
  late Future<ChapterData> _chapterFuture;

  @override
  void initState() {
    super.initState();
    _parseInitialReference();
    _loadChapter();
  }

  void _parseInitialReference() {
    if (widget.initialReference != null) {
      final parsed = BibleService().parseVerseReference(widget.initialReference!);
      if (parsed != null) {
        bookNum = parsed['bookNum']!;
        chapter = parsed['chapter']!;
        highlightVerse = parsed['verse'];
      } else {
        bookNum = 43; // John
        chapter = 3;
        highlightVerse = null;
      }
    } else {
      bookNum = 43;
      chapter = 3;
      highlightVerse = null;
    }
  }

  void _loadChapter() {
    _chapterFuture = BibleService().getChapter(bookNum, chapter);
  }

  void _handleReferenceSelected(int newBook, int newChapter, int? newVerse) {
    setState(() {
      bookNum = newBook;
      chapter = newChapter;
      highlightVerse = newVerse;
      _loadChapter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          child: Column(
            children: [
              // Header with reference picker button
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      '${BibleService.BOOKS[bookNum - 1]} $chapter',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showPickerDialog(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Chapter content
              Expanded(
                child: FutureBuilder<ChapterData>(
                  future: _chapterFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    return ChapterDisplay(
                      chapter: snapshot.data!,
                      highlightVerse: highlightVerse,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => VerseReferencePicker(
        onSelected: _handleReferenceSelected,
        initialBookNum: bookNum,
        initialChapter: chapter,
        initialVerse: highlightVerse,
      ),
    );
  }
}
```

### 3.2 Full Browser Mode: BibleViewerPage

**File:** `lib/screens/bible_viewer_page.dart`

Standalone full-screen Scripture browser (AppBar icon launches this).

```dart
import 'package:flutter/material.dart';
import '../services/bible_service.dart';
import '../widgets/chapter_display.dart';
import '../widgets/verse_reference_picker.dart';

class BibleViewerPage extends StatefulWidget {
  final String? initialReference;

  const BibleViewerPage({
    Key? key,
    this.initialReference,
  }) : super(key: key);

  @override
  State<BibleViewerPage> createState() => _BibleViewerPageState();
}

class _BibleViewerPageState extends State<BibleViewerPage> {
  late int bookNum;
  late int chapter;
  int? highlightVerse;
  late Future<ChapterData> _chapterFuture;
  double fontSize = 16.0;

  @override
  void initState() {
    super.initState();
    _parseInitialReference();
    _loadChapter();
  }

  void _parseInitialReference() {
    if (widget.initialReference != null) {
      final parsed = BibleService().parseVerseReference(widget.initialReference!);
      if (parsed != null) {
        bookNum = parsed['bookNum']!;
        chapter = parsed['chapter']!;
        highlightVerse = parsed['verse'];
      } else {
        bookNum = 43; // John
        chapter = 3;
        highlightVerse = null;
      }
    } else {
      bookNum = 43;
      chapter = 3;
      highlightVerse = null;
    }
  }

  void _loadChapter() {
    _chapterFuture = BibleService().getChapter(bookNum, chapter);
  }

  void _handleReferenceSelected(int newBook, int newChapter, int? newVerse) {
    setState(() {
      bookNum = newBook;
      chapter = newChapter;
      highlightVerse = newVerse;
      _loadChapter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${BibleService.BOOKS[bookNum - 1]} $chapter'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: () => _showFontSizeDialog(),
            tooltip: 'Adjust font size',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
            tooltip: 'Search scripture',
          ),
        ],
      ),
      body: FutureBuilder<ChapterData>(
        future: _chapterFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          return ChapterDisplay(
            chapter: snapshot.data!,
            highlightVerse: highlightVerse,
            fontSize: fontSize,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.edit),
        label: const Text('Go to Verse'),
        onPressed: () => _showPickerDialog(context),
      ),
    );
  }

  void _showPickerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => VerseReferencePicker(
        onSelected: _handleReferenceSelected,
        initialBookNum: bookNum,
        initialChapter: chapter,
        initialVerse: highlightVerse,
      ),
    );
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Font Size'),
        content: Slider(
          value: fontSize,
          min: 12.0,
          max: 24.0,
          divisions: 6,
          label: fontSize.toStringAsFixed(0),
          onChanged: (value) => setState(() => fontSize = value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final searchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Scripture'),
        content: TextField(
          controller: searchController,
          decoration: const InputDecoration(hintText: 'Enter keyword...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSearchResults(searchController.text);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showSearchResults(String keyword) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SearchResultsSheet(
        keyword: keyword,
        onVerseSelected: _handleReferenceSelected,
      ),
    );
  }
}

class SearchResultsSheet extends StatelessWidget {
  final String keyword;
  final Function(int, int, int?) onVerseSelected;

  const SearchResultsSheet({
    Key? key,
    required this.keyword,
    required this.onVerseSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VerseData>>(
      future: BibleService().searchVerses(keyword),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final results = snapshot.data!;
        if (results.isEmpty) {
          return const Center(child: Text('No results found'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final verse = results[index];
            return ListTile(
              title: Text('${verse.bookName} ${verse.chapter}:${verse.verse}'),
              subtitle: Text(verse.text, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () {
                onVerseSelected(verse.bookNum, verse.chapter, verse.verse);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}
```

---

## Part 4: Integration into GraceWay

### 4.1 App Entry Point: Initialize Bible Service

**File:** `lib/main.dart` (in `initializeApp()` or `runApp()`)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Bible service
  try {
    await BibleService().initialize();
  } catch (e) {
    print('Failed to initialize Bible: $e');
    // Handle gracefully—Bible features optional
  }

  runApp(const GraceWayApp());
}
```

### 4.2 AppBar Icon Integration

**File:** `lib/screens/habit_detail_screen.dart` (or wherever your main habit view is)

Add Bible icon to AppBar:

```dart
AppBar(
  title: Text(habit.name),
  actions: [
    IconButton(
      icon: const Icon(Icons.menu_book),
      tooltip: 'Open Scripture',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BibleViewerPage(),
        ),
      ),
    ),
  ],
)
```

### 4.3 Sub-category "Your Why" with Verse Quote

In your sub-category display, wrap key verses:

```dart
// Inside habit subcategory widget
VerseQuote(
  verseReference: 'Philippians 4:6',
  verseText: 'Don\'t be anxious about anything; rather, bring up all of your requests to God in prayer, with thanksgiving.',
  tappable: true,
)
```

---

## Part 5: Styling & Beautiful Formatting

### 5.1 Typography & Spacing

**File:** `lib/theme/bible_theme.dart`

```dart
final TextTheme bibleTextTheme = TextTheme(
  bodyMedium: const TextStyle(
    fontFamily: 'Georgia', // Serif for scripture
    fontSize: 16.0,
    height: 1.8, // Generous line height
    color: Color(0xFF2C2C2C),
  ),
  labelMedium: TextStyle(
    fontFamily: 'Roboto',
    fontSize: 12.0,
    color: Colors.grey[600],
    fontWeight: FontWeight.w500,
  ),
);
```

### 5.2 Color Scheme

Use complementary accent colors for highlighted verses:

```dart
const ColorScheme bibleColorScheme = ColorScheme.light(
  primary: Color(0xFF5B4B31), // Deep brown
  secondary: Color(0xFFFFC107), // Amber for highlights
  surface: Color(0xFFFAF8F3), // Warm white
);
```

### 5.3 Verse Display Enhancements

- **Poetic passages**: Render with indentation & stanza breaks
- **Quoted speech**: Italic or different color
- **Verse numbers**: Superscript, smaller font, muted color
- **Chapter headers**: Bold, larger, with horizontal rule below

---

## Part 6: State Management (Optional: Riverpod/Bloc)

For managing font size, favorite verses, reading progress across sessions:

```dart
final fontSizeProvider = StateProvider<double>((ref) => 16.0);
final currentVerseProvider = StateProvider<(int, int, int?)?>((ref) => null);
final favoriteVersesProvider = StateNotifierProvider<FavoriteVersesNotifier, List<String>>((ref) {
  return FavoriteVersesNotifier();
});
```

---

## Deployment Checklist

- [ ] WEB SQLite database downloaded and placed in `assets/bible/`
- [ ] `pubspec.yaml` includes asset:
  ```yaml
  assets:
    - assets/bible/bible.db
  ```
- [ ] `BibleService.initialize()` called in `main()`
- [ ] Modal & page screens added to navigation
- [ ] AppBar Bible icon wired to `BibleViewerPage`
- [ ] `VerseQuote` widgets integrated in habit display
- [ ] Test on both iOS (from app data) and Android (from assets)
- [ ] Beautiful theme applied (fonts, colors, spacing)

---

## Performance Optimization

1. **Lazy load chapters**: Only query when user navigates
2. **Cache recently viewed chapters**: Use `Map<(int,int), ChapterData>` in `BibleService`
3. **Index database**: Ensure `book_num, chapter, verse_num` indexed
4. **Pagination for search**: Limit results to 50, load more on scroll
5. **Avoid full-text search in SQLite**: Pre-compute search index if needed

---

## Next Steps

1. **Finalize WEB database** (convert from JSON/XML to SQLite if needed)
2. **Build `BibleService`** with test queries
3. **Create shared UI widgets** (`ChapterDisplay`, `VerseReferencePicker`)
4. **Wire up modal & page screens**
5. **Test on device** (iOS + Android)
6. **Polish styling** (fonts, colors, spacing, dark mode)
7. **Integrate into GraceWay habit flows** (AppBar icon, VerseQuote in sub-categories)

---

## References

- [sqflite Flutter package](https://pub.dev/packages/sqflite)
- [WEB Bible JSON (TehShrike)](https://github.com/TehShrike/world-english-bible)
- [Bible SuperSearch downloads](https://www.biblesupersearch.com/bible-downloads/)
- [eBible.org WEB](https://ebible.org/eng-web/)
