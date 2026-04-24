import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../../../data/services/local_voice_cache_service.dart';
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
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  late JournalEntry _entry;
  QuillController? _textController;
  String? _lastSeenText;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _lastSeenText = _entry.text;
    _rebuildTextController(_entry.text);

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final fresh = context.read<JournalProvider>().getEntry(widget.entry.id);
    final latest = fresh ?? _entry;
    if (latest.text != _lastSeenText) {
      _rebuildTextController(latest.text);
      _lastSeenText = latest.text;
      // No setState — widget is already rebuilding due to the dependency change.
      if (fresh != null) _entry = fresh;
    }
  }

  @override
  void dispose() {
    _textController?.dispose();
    _player.dispose();
    super.dispose();
  }

  void _rebuildTextController(String? text) {
    // Save old reference BEFORE clearing — State.dispose() will handle the new
    // _textController, so we must defer disposal of the OLD one separately.
    final oldController = _textController;
    _textController = null;
    if (text != null && text.isNotEmpty) {
      try {
        _textController = QuillController(
          document: Document.fromJson(jsonDecode(text) as List),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
      } catch (_) {
        // Corrupt Delta JSON — leave controller null so text section is hidden.
      }
    }
    // Defer disposal: QuillRawEditor.didUpdateWidget calls
    // oldWidget.controller.removeListener(...) during the next rebuild.
    // Disposing the old controller before that runs triggers a
    // debugAssertNotDisposed assertion crash in debug mode.
    if (oldController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => oldController.dispose());
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _togglePlayback() async {
    final current = context.read<JournalProvider>().getEntry(_entry.id) ?? _entry;
    final remoteUrl = current.voiceUrl;
    if (remoteUrl == null) return;

    if (_isPlaying) {
      await _player.pause();
    } else {
      // Prefer local cached file for offline playback.
      final localPath = LocalVoiceCacheService.instance.getPath(current.id);
      final source = (localPath != null && File(localPath).existsSync())
          ? DeviceFileSource(localPath) as Source
          : UrlSource(remoteUrl);
      if (_position == Duration.zero) {
        await _player.play(source);
      } else {
        await _player.resume();
      }
    }
  }

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
            child: Text('Cancel',
                style: TextStyle(color: theme.accentAction)),
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    theme.heroImageAsset,
                    fit: BoxFit.cover,
                  ),
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
          // Upload pending banner
          if (entry.uploadPending)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.accentMuted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.accentMuted),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: theme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Media uploading...',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

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

          // Images
          if (entry.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...entry.imageUrls
                .map((url) => _NetworkImageTile(url: url, theme: theme)),
          ],

          // Voice playback
          if (entry.voiceUrl != null && !entry.uploadPending) ...[
            const SizedBox(height: 20),
            _VoicePlaybackBar(
              theme: theme,
              isPlaying: _isPlaying,
              position: _position,
              duration: _duration,
              onToggle: _togglePlayback,
              onSeek: (pos) => _player.seek(pos),
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

// ── Network Image Tile ───────────────────────────────────────────────────────

class _NetworkImageTile extends StatefulWidget {
  final String url;
  final JournalTheme theme;

  const _NetworkImageTile({required this.url, required this.theme});

  @override
  State<_NetworkImageTile> createState() => _NetworkImageTileState();
}

class _NetworkImageTileState extends State<_NetworkImageTile> {
  bool _expanded = false;

  static const _thumbSize = 88.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _expanded ? _expandedImage() : _thumbnail(),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail() {
    return SizedBox(
      width: _thumbSize,
      height: _thumbSize,
      child: CachedNetworkImage(
        imageUrl: widget.url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Container(
          color: widget.theme.bgCard,
          child: Icon(Icons.broken_image_outlined,
              color: widget.theme.textSecondary, size: 28),
        ),
      ),
    );
  }

  Widget _expandedImage() {
    return SizedBox(
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: widget.url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Container(
          height: 160,
          color: widget.theme.bgCard,
          child: Center(
            child: Icon(Icons.broken_image_outlined,
                color: widget.theme.textSecondary, size: 32),
          ),
        ),
      ),
    );
  }
}

// ── Voice Playback Bar ───────────────────────────────────────────────────────

class _VoicePlaybackBar extends StatelessWidget {
  final JournalTheme theme;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;

  const _VoicePlaybackBar({
    required this.theme,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onToggle,
    required this.onSeek,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total =
        duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
    final current =
        position.inMilliseconds.toDouble().clamp(0.0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.textSecondary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.accentAction.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: theme.accentAction.withValues(alpha: 0.35)),
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: 20,
                color: theme.accentAction,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: theme.accentAction.withValues(alpha: 0.8),
                inactiveTrackColor:
                    theme.textSecondary.withValues(alpha: 0.2),
                thumbColor: theme.accentAction,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                trackHeight: 2,
              ),
              child: Slider(
                value: current,
                min: 0,
                max: total,
                onChanged: (v) => onSeek(Duration(milliseconds: v.toInt())),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_fmt(position)} / ${_fmt(duration)}',
            style: TextStyle(
              fontSize: 11,
              color: theme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
