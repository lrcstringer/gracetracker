import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/journal_theme.dart';
import '../../providers/habit_provider.dart';
import '../../providers/journal_provider.dart';
import '../../theme/app_theme.dart';
import 'doodle_canvas_screen.dart';

const _kMaxRecordSeconds = 180; // 3 minutes
const _kMaxImagesPerEntry = 3;
const _kMaxImageBytes = 10 * 1024 * 1024; // 10 MB

class JournalEntryComposer extends StatefulWidget {
  /// If provided, the composer opens in edit mode.
  final JournalEntry? initialEntry;

  // Pre-filled context (new entry only).
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
  final _imagePicker = ImagePicker();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  // Images
  final List<String> _existingImageUrls = [];
  final List<String> _removedImageUrls = [];
  final List<String> _newImagePaths = [];

  // Voice
  String? _existingVoiceUrl;
  bool _removeExistingVoice = false;
  String? _newVoicePath;

  bool _isRecording = false;
  bool _isPlayingBack = false;
  Duration _recordingDuration = Duration.zero;

  int _timerGeneration = 0;
  String? _tmpVoicePath;

  bool _isSaving = false;

  Habit? _linkedHabit;

  // Dictation
  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  int _dictationStartIndex = 0;
  String _lastDictationText = '';

  bool get _isEditMode => widget.initialEntry != null;
  int get _totalImageCount => _existingImageUrls.length + _newImagePaths.length;

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
    if (e != null) {
      _existingImageUrls.addAll(e.imageUrls);
      _existingVoiceUrl = e.voiceUrl;
    }
    if (!_isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editorFocusNode.requestFocus();
      });
    }

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlayingBack = state == PlayerState.playing);
      }
    });

    _speech.initialize(onError: (_) {
      if (mounted) setState(() => _isListening = false);
    }).then((available) {
      if (mounted) setState(() => _speechAvailable = available);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _recorder.dispose();
    _player.dispose();
    if (_tmpVoicePath != null) {
      try { File(_tmpVoicePath!).deleteSync(); } catch (_) {}
    }
    super.dispose();
  }

  // ── Voice dictation ─────────────────────────────────────────────────────

  Future<void> _toggleDictation() async {
    if (_isListening) {
      await _speech.stop();
      setState(() { _isListening = false; _lastDictationText = ''; });
      return;
    }
    if (!_speechAvailable) return;

    // Android speech recognition uses Google's network API — guard offline.
    if (Platform.isAndroid) {
      final results = await Connectivity().checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Voice dictation requires an internet connection on Android.'),
            duration: Duration(seconds: 3),
          ));
        }
        return;
      }
    }

    _editorFocusNode.requestFocus();
    final sel = _textController.selection;
    _dictationStartIndex = sel.isValid ? sel.baseOffset : _textController.document.length - 1;
    _lastDictationText = '';
    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        if (words.isEmpty) return;
        // Replace previous partial result with latest recognised words.
        _textController.replaceText(
          _dictationStartIndex,
          _lastDictationText.length,
          words,
          TextSelection.collapsed(offset: _dictationStartIndex + words.length),
        );
        _lastDictationText = words;
        if (result.finalResult) {
          // Append a trailing space and advance the cursor.
          final end = _dictationStartIndex + words.length;
          _textController.replaceText(end, 0, ' ',
              TextSelection.collapsed(offset: end + 1));
          _dictationStartIndex = end + 1;
          _lastDictationText = '';
          if (mounted) setState(() => _isListening = false);
        }
      },
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        autoPunctuation: true,
      ),
    );
  }

  // ── Image picking ───────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    if (_totalImageCount >= _kMaxImagesPerEntry) {
      _showSnack('Maximum $_kMaxImagesPerEntry images per entry');
      return;
    }

    final permission =
        source == ImageSource.camera ? Permission.camera : Permission.photos;
    final status = await permission.request();
    if (!status.isGranted) {
      _showPermissionDenied(
          source == ImageSource.camera ? 'Camera' : 'Photo library');
      return;
    }

    final xfile = await _imagePicker.pickImage(
        source: source, imageQuality: 80);
    if (xfile == null || !mounted) return;

    if (File(xfile.path).lengthSync() > _kMaxImageBytes) {
      _showSnack('Image is too large (max 10 MB). Please choose a smaller photo.');
      return;
    }

    if (_kMaxImagesPerEntry - _totalImageCount <= 0) return;
    setState(() => _newImagePaths.add(xfile.path));
  }

  void _removeNewImage(int index) =>
      setState(() => _newImagePaths.removeAt(index));

  void _removeExistingImage(String url) {
    setState(() {
      _existingImageUrls.remove(url);
      _removedImageUrls.add(url);
    });
  }

  // ── Voice recording ─────────────────────────────────────────────────────

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _showPermissionDenied('Microphone');
      return;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final path = '${appDir.path}/journal_voice_tmp.m4a';

    await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc), path: path);

    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
      _newVoicePath = null;
    });
    _startDurationTimer();
  }

  void _startDurationTimer() {
    final generation = ++_timerGeneration;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isRecording || _timerGeneration != generation) {
        return false;
      }
      final next = _recordingDuration + const Duration(seconds: 1);
      if (next.inSeconds >= _kMaxRecordSeconds) {
        setState(() => _recordingDuration =
            const Duration(seconds: _kMaxRecordSeconds));
        await _stopRecording();
        return false;
      }
      setState(() => _recordingDuration = next);
      return true;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    _tmpVoicePath = path;
    setState(() {
      _isRecording = false;
      _newVoicePath = path;
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlayingBack) {
      await _player.stop();
      return;
    }
    final source = _newVoicePath != null
        ? DeviceFileSource(_newVoicePath!)
        : (_existingVoiceUrl != null ? UrlSource(_existingVoiceUrl!) : null);
    if (source == null) return;
    await _player.play(source);
  }

  void _discardVoice() {
    _player.stop();
    setState(() {
      _newVoicePath = null;
      _removeExistingVoice = true;
      _existingVoiceUrl = null;
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_isRecording) {
      await _stopRecording();
      if (!mounted) return;
    }

    final plainText = _textController.document.toPlainText().trim();
    final hasContent = plainText.isNotEmpty ||
        _newImagePaths.isNotEmpty ||
        _newVoicePath != null ||
        _existingImageUrls.isNotEmpty ||
        (_existingVoiceUrl != null && !_removeExistingVoice);

    if (!hasContent) {
      _showSnack('Add some content before saving');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final deltaJson = plainText.isNotEmpty
          ? jsonEncode(_textController.document.toDelta().toJson())
          : null;
      final provider = context.read<JournalProvider>();
      if (_isEditMode) {
        await provider.updateEntry(
          widget.initialEntry!,
          text: deltaJson,
          clearText: deltaJson == null,
          newImageLocalPaths: _newImagePaths,
          newVoiceLocalPath: _newVoicePath,
          removedImageUrls:
              _removedImageUrls.isNotEmpty ? _removedImageUrls : null,
          removeVoice: _removeExistingVoice,
        );
      } else {
        await provider.saveEntry(
          text: deltaJson,
          imageLocalPaths: _newImagePaths,
          voiceLocalPath: _newVoicePath,
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

  void _showPermissionDenied(String resource) {
    const theme = JournalTheme.parchment;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.bgCard,
        title: Text('$resource access denied',
            style: TextStyle(color: theme.textPrimary, fontSize: 16)),
        content: Text(
          'Please allow $resource access in Settings to use this feature.',
          style: TextStyle(
              color: theme.textSecondary.withValues(alpha: 0.85),
              fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: theme.accentAction)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Open Settings',
                style: TextStyle(color: theme.accentAction)),
          ),
        ],
      ),
    );
  }

  void _showImageSourceSheet(JournalTheme theme) {
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
            ListTile(
              leading: Icon(Icons.camera_alt_outlined,
                  color: theme.textSecondary),
              title: Text('Take a photo',
                  style: TextStyle(color: theme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: theme.textSecondary),
              title: Text('Choose from library',
                  style: TextStyle(color: theme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDoodleCanvas(JournalTheme theme) async {
    final path = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            DoodleCanvasScreen(accentColor: theme.accentAction),
      ),
    );
    if (path != null && mounted) {
      setState(() => _newImagePaths.add(path));
    }
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
                        style: TextStyle(
                            color: theme.textPrimary, fontSize: 15),
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

    final hasVoice = _newVoicePath != null ||
        (_existingVoiceUrl != null && !_removeExistingVoice);

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
                customButtons: [
                  QuillToolbarCustomButtonOptions(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: _isListening ? Colors.red : theme.textSecondary,
                      size: 18,
                    ),
                    onPressed: _speechAvailable ? _toggleDictation : null,
                    tooltip: _isListening ? 'Stop dictation' : 'Dictate',
                  ),
                ],
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

          Divider(
              color: theme.textSecondary.withValues(alpha: 0.15),
              height: 24),

          // Images section
          _ImagesSection(
            theme: theme,
            existingUrls: _existingImageUrls,
            newPaths: _newImagePaths,
            totalCount: _totalImageCount,
            onAddTap: () => _showImageSourceSheet(theme),
            onDoodleTap: () => _openDoodleCanvas(theme),
            onRemoveExisting: _removeExistingImage,
            onRemoveNew: _removeNewImage,
          ),

          const SizedBox(height: 16),

          // Voice section
          _VoiceSection(
            theme: theme,
            isRecording: _isRecording,
            hasVoice: hasVoice,
            isPlaying: _isPlayingBack,
            recordingDuration: _recordingDuration,
            onToggleRecord: _toggleRecording,
            onTogglePlayback: _togglePlayback,
            onDiscard: _discardVoice,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: chipColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13,
                    color: chipColor.withValues(alpha: 0.8)),
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

// ── Images Section ──────────────────────────────────────────────────────────

class _ImagesSection extends StatelessWidget {
  final JournalTheme theme;
  final List<String> existingUrls;
  final List<String> newPaths;
  final int totalCount;
  final VoidCallback onAddTap;
  final VoidCallback onDoodleTap;
  final ValueChanged<String> onRemoveExisting;
  final ValueChanged<int> onRemoveNew;

  const _ImagesSection({
    required this.theme,
    required this.existingUrls,
    required this.newPaths,
    required this.totalCount,
    required this.onAddTap,
    required this.onDoodleTap,
    required this.onRemoveExisting,
    required this.onRemoveNew,
  });

  @override
  Widget build(BuildContext context) {
    final showAddButton = totalCount < _kMaxImagesPerEntry;
    if (totalCount == 0 && !showAddButton) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_outlined,
                size: 16, color: theme.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Photos',
              style: TextStyle(
                fontSize: 13,
                color: theme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final url in existingUrls)
                _ImageThumb.network(
                    url: url,
                    theme: theme,
                    onRemove: () => onRemoveExisting(url)),

              for (var i = 0; i < newPaths.length; i++)
                _ImageThumb.file(
                    path: newPaths[i],
                    theme: theme,
                    onRemove: () => onRemoveNew(i)),

              if (showAddButton) ...[
                GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: theme.textSecondary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 22, color: theme.textSecondary),
                        const SizedBox(height: 4),
                        Text(
                          'Add\nPhoto',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onDoodleTap,
                  child: Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: theme.textSecondary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.draw_outlined,
                            size: 22, color: theme.textSecondary),
                        const SizedBox(height: 4),
                        Text(
                          'Add\nDoodle',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final Widget child;
  final JournalTheme theme;
  final VoidCallback onRemove;

  const _ImageThumb({
    required this.child,
    required this.theme,
    required this.onRemove,
  });

  factory _ImageThumb.network({
    required String url,
    required JournalTheme theme,
    required VoidCallback onRemove,
  }) {
    return _ImageThumb(
      theme: theme,
      onRemove: onRemove,
      child: Image.network(
        url,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.broken_image, color: theme.textSecondary),
      ),
    );
  }

  factory _ImageThumb.file({
    required String path,
    required JournalTheme theme,
    required VoidCallback onRemove,
  }) {
    return _ImageThumb(
      theme: theme,
      onRemove: onRemove,
      child: Image.file(
        File(path),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.broken_image, color: theme.textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(right: 8, top: 8),
          clipBehavior: Clip.antiAlias,
          decoration:
              BoxDecoration(borderRadius: BorderRadius.circular(10)),
          child: child,
        ),
        Positioned(
          top: 0,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: theme.bgPrimary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close,
                  size: 14, color: theme.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Voice Section ───────────────────────────────────────────────────────────

class _VoiceSection extends StatelessWidget {
  final JournalTheme theme;
  final bool isRecording;
  final bool hasVoice;
  final bool isPlaying;
  final Duration recordingDuration;
  final VoidCallback onToggleRecord;
  final VoidCallback onTogglePlayback;
  final VoidCallback onDiscard;

  const _VoiceSection({
    required this.theme,
    required this.isRecording,
    required this.hasVoice,
    required this.isPlaying,
    required this.recordingDuration,
    required this.onToggleRecord,
    required this.onTogglePlayback,
    required this.onDiscard,
  });

  static const _warningThreshold = 30;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (isRecording) return _buildRecordingState();
    if (hasVoice) return _buildPlaybackState();
    return _buildIdleState();
  }

  // ── Idle ──────────────────────────────────────────────────────────────────

  Widget _buildIdleState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_none_outlined,
              size: 18, color: theme.textSecondary),
          const SizedBox(width: 10),
          Text(
            'Voice note',
            style: TextStyle(fontSize: 14, color: theme.textSecondary),
          ),
          const SizedBox(width: 6),
          Text(
            '· 3 min max',
            style: TextStyle(
              fontSize: 12,
              color: theme.textSecondary.withValues(alpha: 0.55),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onToggleRecord,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.accentAction.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: theme.accentAction.withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.mic, size: 20, color: theme.accentAction),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recording ────────────────────────────────────────────────────────────

  Widget _buildRecordingState() {
    final elapsed =
        recordingDuration.inSeconds.clamp(0, _kMaxRecordSeconds);
    final progress = elapsed / _kMaxRecordSeconds;
    final secondsRemaining = _kMaxRecordSeconds - elapsed;
    final isWarning = secondsRemaining <= _warningThreshold;

    const recordingRed = Color(0xFFE05C5C);
    const warningAmber = Color(0xFFD4843B);
    final ringColor = isWarning ? warningAmber : recordingRed;
    final dotVisible = recordingDuration.inSeconds.isEven;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
      decoration: BoxDecoration(
        color: theme.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ringColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // Status row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedOpacity(
                opacity: dotVisible ? 1.0 : 0.25,
                duration: const Duration(milliseconds: 600),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: ringColor, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  isWarning
                      ? '${secondsRemaining}s remaining'
                      : 'Recording',
                  key: ValueKey(isWarning),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isWarning ? warningAmber : theme.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Progress ring with time
          SizedBox(
            width: 144,
            height: 144,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(144, 144),
                  painter: _RecordingRingPainter(
                    progress: progress,
                    ringColor: ringColor,
                    trackColor:
                        theme.textSecondary.withValues(alpha: 0.15),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmt(recordingDuration),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w300,
                        color: theme.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '/ 3:00',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Stop button
          GestureDetector(
            onTap: onToggleRecord,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ringColor.withValues(alpha: 0.1),
                border: Border.all(
                    color: ringColor.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Icon(Icons.stop_rounded, size: 28, color: ringColor),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tap to stop',
            style:
                TextStyle(fontSize: 12, color: theme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  Widget _buildPlaybackState() {
    final showDuration = recordingDuration > Duration.zero;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: theme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.accentAction.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Play / stop button
          GestureDetector(
            onTap: onTogglePlayback,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.accentAction.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: theme.accentAction.withValues(alpha: 0.35)),
              ),
              child: Icon(
                isPlaying
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                size: 22,
                color: theme.accentAction,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voice note',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.textPrimary,
                ),
              ),
              if (showDuration) ...[
                const SizedBox(height: 2),
                Text(
                  _fmt(recordingDuration),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.accentAction.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          // Discard button
          GestureDetector(
            onTap: onDiscard,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.textSecondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline,
                  size: 18, color: theme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recording Ring Painter ────────────────────────────────────────────────────

class _RecordingRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;

  const _RecordingRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 7.0;
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RecordingRingPainter old) =>
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.trackColor != trackColor;
}
