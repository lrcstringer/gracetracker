import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/journal_theme.dart';
import '../../providers/habit_provider.dart';
import '../../providers/journal_provider.dart';
import '../../theme/app_theme.dart';

class JournalEntryComposer extends StatefulWidget {
  final JournalEntry? initialEntry;

  final String? habitId;
  final String? habitName;
  final String sourceType;

  const JournalEntryComposer({
    super.key,
    this.initialEntry,
    this.habitId,
    this.habitName,
    this.sourceType = 'free',
  });

  @override
  State<JournalEntryComposer> createState() => _JournalEntryComposerState();
}

class _JournalEntryComposerState extends State<JournalEntryComposer> {
  late final QuillController _textController;
  late final FocusNode _editorFocusNode;
  late final ScrollController _editorScrollController;

  bool _isSaving = false;
  Habit? _linkedHabit;

  bool get _isEditMode => widget.initialEntry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.initialEntry;
    _editorFocusNode = FocusNode();
    _editorScrollController = ScrollController();
    if (e?.text != null && e!.text!.isNotEmpty) {
      try {
        _textController = QuillController(
          document: Document.fromJson(jsonDecode(e.text!) as List),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        _textController = QuillController.basic();
      }
    } else {
      _textController = QuillController.basic();
    }
    if (!_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editorFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final plainText = _textController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      _showSnack('Add some content before saving');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final deltaJson = jsonEncode(_textController.document.toDelta().toJson());
      final provider = context.read<JournalProvider>();
      if (_isEditMode) {
        await provider.updateEntry(
          widget.initialEntry!,
          text: deltaJson,
          clearText: false,
          newImageLocalPaths: const [],
          newVoiceLocalPath: null,
          removedImageUrls: null,
          removeVoice: false,
        );
      } else {
        await provider.saveEntry(
          text: deltaJson,
          imageLocalPaths: const [],
          voiceLocalPath: null,
          habitId: _linkedHabit?.id ?? widget.habitId,
          habitName: _linkedHabit?.name ?? widget.habitName,
          sourceType: _linkedHabit != null ? 'linked' : widget.sourceType,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('Could not save entry. Please try again.');
      }
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ── Habit picker ────────────────────────────────────────────────────────

  void _showHabitPicker(JournalTheme theme) {
    final habits = context.read<HabitProvider>().habits;
    if (habits.isEmpty) {
      _showSnack('No habits found');
      return;
    }
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Link to a Habit',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            Divider(color: theme.textSecondary.withValues(alpha: 0.15), height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final habit in habits)
                    ListTile(
                      leading: Icon(Icons.repeat,
                          color: GraceWayColor.golden, size: 20),
                      title: Text(
                        habit.name,
                        style: TextStyle(color: theme.textPrimary, fontSize: 15),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _linkedHabit = habit);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const theme = JournalTheme.parchment;

    final habitName = widget.initialEntry?.habitName ?? _linkedHabit?.name ?? widget.habitName;
    final sourceType = widget.initialEntry?.sourceType ?? (_linkedHabit != null ? 'linked' : widget.sourceType);

    return Scaffold(
      backgroundColor: theme.bgPrimary,
      appBar: AppBar(
        backgroundColor: theme.bgPrimary,
        foregroundColor: theme.textPrimary,
        title: Text(
          _isEditMode ? 'Edit Entry' : 'New Entry',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.accentAction,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text('Save',
                  style: TextStyle(
                    color: theme.accentAction,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  )),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Source chip / habit link
          if (!_isEditMode && widget.sourceType == 'free')
            _linkedHabit != null
                ? _SourceChip(
                    habitName: habitName,
                    sourceType: sourceType,
                    theme: theme,
                    onClear: () => setState(() => _linkedHabit = null),
                  )
                : _LinkHabitButton(
                    theme: theme,
                    onTap: () => _showHabitPicker(theme),
                  )
          else if (sourceType != 'free' || habitName != null)
            _SourceChip(
              habitName: habitName,
              sourceType: sourceType,
              theme: theme,
            ),

          // Toolbar
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.textSecondary.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
            ),
            child: QuillSimpleToolbar(
              controller: _textController,
              config: QuillSimpleToolbarConfig(
                color: Colors.transparent,
                multiRowsDisplay: false,
                showDividers: true,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: false,
                showInlineCode: false,
                showColorButton: false,
                showBackgroundColorButton: false,
                showClearFormat: false,
                showSmallButton: false,
                showFontFamily: false,
                showFontSize: false,
                showAlignmentButtons: false,
                showLeftAlignment: false,
                showCenterAlignment: false,
                showRightAlignment: false,
                showJustifyAlignment: false,
                showHeaderStyle: false,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: true,
                showCodeBlock: false,
                showQuote: false,
                showIndent: false,
                showLink: false,
                showUndo: true,
                showRedo: true,
                showDirection: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                iconTheme: QuillIconTheme(
                  iconButtonUnselectedData: IconButtonData(
                    color: theme.textSecondary,
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                  ),
                  iconButtonSelectedData: IconButtonData(
                    color: theme.accentAction,
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Rich-text editor
          DefaultTextStyle(
            style: DefaultTextStyle.of(context).style.copyWith(
              color: theme.textPrimary,
              fontSize: 16,
              height: 1.6,
              decoration: TextDecoration.none,
            ),
            child: QuillEditor.basic(
              controller: _textController,
              focusNode: _editorFocusNode,
              scrollController: _editorScrollController,
              config: QuillEditorConfig(
                placeholder: 'Write something...',
                minHeight: 150,
                scrollable: false,
                padding: EdgeInsets.zero,
                customStyles: DefaultStyles(
                  placeHolder: DefaultTextBlockStyle(
                    TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: theme.textSecondary.withValues(alpha: 0.5),
                      decoration: TextDecoration.none,
                      fontStyle: FontStyle.italic,
                    ),
                    const HorizontalSpacing(0, 0),
                    VerticalSpacing.zero,
                    VerticalSpacing.zero,
                    null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Source Chip ─────────────────────────────────────────────────────────────

class _SourceChip extends StatelessWidget {
  final String? habitName;
  final String sourceType;
  final JournalTheme theme;
  final VoidCallback? onClear;

  const _SourceChip({
    this.habitName,
    required this.sourceType,
    required this.theme,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    String label;
    IconData icon;

    if (habitName != null) {
      chipColor = GraceWayColor.golden;
      label = habitName!;
      icon = Icons.repeat;
    } else {
      chipColor = theme.textSecondary;
      label = 'Journal';
      icon = Icons.book_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
          if (onClear != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 14,
                  color: chipColor.withValues(alpha: 0.6)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Link Habit Button ────────────────────────────────────────────────────────

class _LinkHabitButton extends StatelessWidget {
  final JournalTheme theme;
  final VoidCallback onTap;

  const _LinkHabitButton({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 14,
                color: theme.textSecondary.withValues(alpha: 0.6)),
            const SizedBox(width: 5),
            Text(
              'Link to a habit',
              style: TextStyle(
                fontSize: 13,
                color: theme.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
