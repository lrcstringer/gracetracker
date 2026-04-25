import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../../domain/entities/journal_theme.dart';
import '../../providers/journal_provider.dart';
import '../../theme/app_theme.dart';
import 'journal_entry_composer.dart';

class JournalEntryDetailView extends StatefulWidget {
  final JournalEntry entry;

  const JournalEntryDetailView({super.key, required this.entry});

  @override
  State<JournalEntryDetailView> createState() => _JournalEntryDetailViewState();
}

class _JournalEntryDetailViewState extends State<JournalEntryDetailView> {
  late JournalEntry _entry;
  QuillController? _textController;
  String? _lastSeenText;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _lastSeenText = _entry.text;
    _rebuildTextController(_entry.text);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final fresh = context.read<JournalProvider>().getEntry(widget.entry.id);
    final latest = fresh ?? _entry;
    if (latest.text != _lastSeenText) {
      _rebuildTextController(latest.text);
      _lastSeenText = latest.text;
      if (fresh != null) _entry = fresh;
    }
  }

  @override
  void dispose() {
    _textController?.dispose();
    super.dispose();
  }

  void _rebuildTextController(String? text) {
    final oldController = _textController;
    _textController = null;
    if (text != null && text.isNotEmpty) {
      try {
        _textController = QuillController(
          document: Document.fromJson(jsonDecode(text) as List),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      } catch (_) {}
    }
    if (oldController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => oldController.dispose());
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _openEdit() async {
    final provider = context.read<JournalProvider>();
    final toEdit = provider.getEntry(_entry.id) ?? _entry;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => JournalEntryComposer(initialEntry: toEdit)),
    );

    if (mounted) {
      final updated = context.read<JournalProvider>().getEntry(_entry.id);
      if (updated != null) {
        setState(() {
          if (updated.text != _lastSeenText) {
            _rebuildTextController(updated.text);
            _lastSeenText = updated.text;
          }
          _entry = updated;
        });
      }
    }
  }

  Future<void> _confirmDelete(JournalTheme theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.bgCard,
        title: Text('Delete entry?',
            style: TextStyle(color: theme.textPrimary, fontSize: 16)),
        content: Text(
          'This entry will be permanently deleted.',
          style: TextStyle(
              color: theme.textSecondary.withValues(alpha: 0.85),
              fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: theme.accentAction)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final toDelete =
          context.read<JournalProvider>().getEntry(_entry.id) ?? _entry;
      await context.read<JournalProvider>().deleteEntry(toDelete);
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const theme = JournalTheme.parchment;

    final fresh = context.select<JournalProvider, JournalEntry?>(
      (p) => p.getEntry(widget.entry.id),
    );
    final entry = fresh ?? _entry;
    final dateStr = _formatDate(entry.createdAt);

    return Scaffold(
      backgroundColor: theme.bgPrimary,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: theme.bgPrimary,
            foregroundColor: theme.textPrimary,
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
              title: Text(
                dateStr,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(theme.heroImageAsset, fit: BoxFit.cover),
                  DecoratedBox(
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
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 26, color: theme.textPrimary),
                onPressed: _openEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 26, color: theme.textPrimary),
                onPressed: () => _confirmDelete(theme),
                tooltip: 'Delete',
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Source chip
                _SourceChipRow(entry: entry, theme: theme),

                // Body text
                if (_textController != null) ...[
                  const SizedBox(height: 12),
                  DefaultTextStyle(
                    style: DefaultTextStyle.of(context).style.copyWith(
                      color: theme.textPrimary,
                      fontSize: 16,
                      height: 1.7,
                    ),
                    child: QuillEditor.basic(
                      controller: _textController!,
                      config: const QuillEditorConfig(
                        scrollable: false,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday', 'Sunday',
    ];
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return '$dayName, ${dt.day} $monthName ${dt.year}';
  }
}

// ── Source Chip Row ─────────────────────────────────────────────────────────

class _SourceChipRow extends StatelessWidget {
  final JournalEntry entry;
  final JournalTheme theme;

  const _SourceChipRow({required this.entry, required this.theme});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    String label;
    IconData icon;

    if (entry.habitName != null) {
      chipColor = GraceWayColor.golden;
      label = entry.habitName!;
      icon = Icons.repeat;
    } else {
      chipColor = theme.textSecondary;
      label = 'Journal';
      icon = Icons.book_outlined;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: chipColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: chipColor.withValues(alpha: 0.8)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: chipColor.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
