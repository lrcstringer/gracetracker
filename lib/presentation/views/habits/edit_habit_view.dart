import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/habit_category_model.dart';
import '../../utils/category_icons.dart';
import '../../providers/habit_provider.dart';
import '../../providers/habit_category_provider.dart';
import '../../providers/store_provider.dart';
import '../../theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/entities/accountability_partnership.dart';
import '../../providers/accountability_provider.dart';
import '../shared/graceway_paywall_view.dart';

class EditHabitView extends StatefulWidget {
  final Habit habit;
  final ScrollController? scrollController;
  const EditHabitView({super.key, required this.habit, this.scrollController});

  @override
  State<EditHabitView> createState() => _EditHabitViewState();
}

class _EditHabitViewState extends State<EditHabitView> {
  late final TextEditingController _nameController;
  late final TextEditingController _purposeController;
  late final TextEditingController _triggerController;
  late final TextEditingController _copingController;
  late final QuillController _notesController;
  final FocusNode _notesFocusNode = FocusNode();
  final ScrollController _notesScrollController = ScrollController();
  late final TextEditingController _referenceUrlController;
  late double _dailyTarget;
  late String _targetUnit;
  late Set<int> _activeDays;
  late bool _hasPrayerItems;
  String? _categoryId;
  String? _subcategoryId;
  String? _categoryName;
  String? _subcategoryName;

  static const _copingSuggestions = ['Pray first', 'Call a friend', 'Go for a walk', 'Read my verse', 'Journal it out'];

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _nameController = TextEditingController(text: h.name);
    _purposeController = TextEditingController(text: h.purposeStatement);
    _triggerController = TextEditingController(text: h.trigger);
    _copingController = TextEditingController(text: h.copingPlan);
    if (h.notes.isNotEmpty) {
      try {
        _notesController = QuillController(
          document: Document.fromJson(jsonDecode(h.notes) as List),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        _notesController = QuillController.basic();
      }
    } else {
      _notesController = QuillController.basic();
    }
    _referenceUrlController = TextEditingController(text: h.referenceUrl);
    _dailyTarget = h.dailyTarget;
    _targetUnit = h.targetUnit;
    _activeDays = h.activeDaySet;
    _hasPrayerItems = h.hasPrayerItems;
    _categoryId = h.categoryId;
    _subcategoryId = h.subcategoryId;
    _categoryName = h.categoryName;
    _subcategoryName = h.subcategoryName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purposeController.dispose();
    _triggerController.dispose();
    _copingController.dispose();
    _notesController.dispose();
    _notesFocusNode.dispose();
    _notesScrollController.dispose();
    _referenceUrlController.dispose();
    super.dispose();
  }

  bool get _nameEmpty => _nameController.text.trim().isEmpty;

  void _save() {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) return;
    final isPremium = context.read<StoreProvider>().isPremium;
    final plainNotes = _notesController.document.toPlainText().trim();
    final notesJson = plainNotes.isEmpty
        ? ''
        : jsonEncode(_notesController.document.toDelta().toJson());
    final refUrl = _referenceUrlController.text.trim();
    final updated = widget.habit.copyWith(
      name: !widget.habit.isBuiltIn ? trimmed : null,
      purposeStatement: isPremium ? _purposeController.text : null,
      dailyTarget: _dailyTarget,
      targetUnit: _targetUnit,
      activeDays: (_activeDays.toList()..sort()).join(','),
      trigger: _triggerController.text,
      copingPlan: _copingController.text,
      categoryId: _categoryId,
      subcategoryId: _subcategoryId,
      categoryName: _categoryName,
      subcategoryName: _subcategoryName,
      notes: notesJson,
      referenceUrl: refUrl,
      hasPrayerItems: _hasPrayerItems,
    );
    context.read<HabitProvider>().updateHabit(updated);
    Navigator.pop(context);
  }

  IconData _categoryIcon() {
    switch (widget.habit.category) {
      case HabitCategory.exercise: return Icons.fitness_center;
      case HabitCategory.scripture: return Icons.menu_book;
      case HabitCategory.rest: return Icons.bedtime;
      case HabitCategory.fasting: return Icons.no_food;
      case HabitCategory.study: return Icons.school;
      case HabitCategory.service: return Icons.volunteer_activism;
      case HabitCategory.connection: return Icons.people;
      case HabitCategory.health: return Icons.favorite;
      case HabitCategory.abstain: return Icons.shield_rounded;
      default: return Icons.auto_awesome;
    }
  }

  List<String> _triggerChips() {
    switch (widget.habit.category) {
      case HabitCategory.exercise: return ['After my morning coffee', 'Before work', 'During lunch break', 'After dinner'];
      case HabitCategory.scripture: return ['First thing in the morning', 'Before bed', 'During lunch', 'After prayer'];
      case HabitCategory.rest: return ['At 10pm', 'After dinner', 'When I feel tired'];
      case HabitCategory.fasting: return ['After morning prayer', 'On Wednesdays', 'Weekly'];
      case HabitCategory.study: return ['After dinner', 'Morning routine', 'Lunch break'];
      case HabitCategory.service: return ['After church', 'On weekends', 'When I see a need'];
      case HabitCategory.connection: return ['Sunday afternoon', 'After dinner', 'During commute'];
      default: return ['In the morning', 'After lunch', 'Before bed'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<StoreProvider>().isPremium;
    final isAbstain = widget.habit.trackingType == HabitTrackingType.abstain;

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        foregroundColor: GraceWayColor.warmWhite,
        title: const Text('Edit Habit',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: GraceWayColor.softGold)),
        ),
        leadingWidth: 80,
        actions: [
          TextButton(
            onPressed: _nameEmpty ? null : _save,
            child: Text('Save',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _nameEmpty ? Colors.white.withValues(alpha: 0.3) : GraceWayColor.golden,
                )),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _headerSection(),
          if (_categoryId != null) ...[
            const SizedBox(height: 16),
            _categoryChipsRow(),
          ],
          const SizedBox(height: 20),
          _nameSection(),
          const SizedBox(height: 20),
          _purposeSection(isPremium),
          if (widget.habit.trackingType == HabitTrackingType.timed) ...[
            const SizedBox(height: 20),
            _timedTargetSection(),
          ],
          if (widget.habit.trackingType == HabitTrackingType.count) ...[
            const SizedBox(height: 20),
            _countTargetSection(),
          ],
          const SizedBox(height: 20),
          _dayOfWeekSection(isAbstain),
          const SizedBox(height: 20),
          if (isAbstain) _copingSection() else _triggerSection(),
          const SizedBox(height: 20),
          if (isAbstain) ...[
            _partnerSection(),
            const SizedBox(height: 20),
          ],
          _notesSection(),
          const SizedBox(height: 20),
          _referenceUrlSection(),
          const SizedBox(height: 20),
          _prayerListToggle(),
          if (!widget.habit.isBuiltIn) ...[
            const SizedBox(height: 40),
            Row(children: [
              Expanded(child: _archiveButton()),
              const SizedBox(width: 12),
              Expanded(child: _deleteSection()),
            ]),
          ],
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _notesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: GraceWayColor.softGold.withValues(alpha: 0.5),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Personal notes, reminders, or reflections for this habit.',
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: GraceWayColor.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: GraceWayColor.golden.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QuillSimpleToolbar(
                  controller: _notesController,
                  config: QuillSimpleToolbarConfig(
                    color: Colors.transparent,
                    multiRowsDisplay: false,
                    showDividers: false,
                    showBoldButton: true,
                    showItalicButton: true,
                    showUnderLineButton: true,
                    showListBullets: true,
                    showListNumbers: true,
                    showListCheck: false,
                    showUndo: true,
                    showRedo: true,
                    showHeaderStyle: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showClearFormat: false,
                    showStrikeThrough: false,
                    showInlineCode: false,
                    showLink: false,
                    showSearchButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showSmallButton: false,
                    showFontFamily: false,
                    showFontSize: false,
                    showAlignmentButtons: false,
                    showLeftAlignment: false,
                    showCenterAlignment: false,
                    showRightAlignment: false,
                    showJustifyAlignment: false,
                    showIndent: false,
                    showQuote: false,
                    showCodeBlock: false,
                    showDirection: false,
                    iconTheme: QuillIconTheme(
                      iconButtonUnselectedData: IconButtonData(
                        color: GraceWayColor.warmWhite.withValues(alpha: 0.5),
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                      ),
                      iconButtonSelectedData: IconButtonData(
                        color: GraceWayColor.golden,
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: GraceWayColor.golden.withValues(alpha: 0.12),
                ),
                QuillEditor.basic(
                  controller: _notesController,
                  focusNode: _notesFocusNode,
                  scrollController: _notesScrollController,
                  config: QuillEditorConfig(
                    placeholder: 'Add personal notes…',
                    minHeight: 100,
                    maxHeight: 200,
                    scrollable: true,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Support/Prayer Partner section ──────────────────────────────────────

  Widget _partnerSection() {
    final accountability = context.watch<AccountabilityProvider>();
    final partnership = accountability.partnershipForHabit(widget.habit.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUPPORT/PRAYER PARTNER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: GraceWayColor.softGold.withValues(alpha: 0.5),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Invite someone to walk with you on this habit.',
          style: TextStyle(
              fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: GraceWayColor.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: GraceWayColor.warmWhite.withValues(alpha: 0.07), width: 0.5),
          ),
          child: partnership == null
              ? _inviteRow(accountability)
              : _partnershipRow(partnership, accountability),
        ),
      ],
    );
  }

  Widget _inviteRow(AccountabilityProvider accountability) {
    return GestureDetector(
      onTap: accountability.isLoading
          ? null
          : () async {
              try {
                final result = await accountability.createInvite(
                  habitId: widget.habit.id,
                  habitName: widget.habit.name,
                );
                if (!mounted) return;
                await _sharePartnerLink(result.shareUrl, result.shortCode);
              } catch (e) {
                debugPrint('createInvite failed: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Could not create invite. Try again.')),
                );
              }
            },
      child: Row(children: [
        Icon(Icons.person_add_rounded,
            size: 16,
            color: GraceWayColor.sage.withValues(alpha: 0.8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            accountability.isLoading
                ? 'Creating invite…'
                : 'Invite a support/prayer partner',
            style: TextStyle(
                fontSize: 14,
                color: GraceWayColor.sage.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500),
          ),
        ),
        if (!accountability.isLoading)
          Icon(Icons.chevron_right_rounded,
              size: 18,
              color: GraceWayColor.warmWhite.withValues(alpha: 0.25)),
      ]),
    );
  }

  Widget _partnershipRow(
      AccountabilityPartnership partnership,
      AccountabilityProvider accountability) {
    final isPending = partnership.status == PartnershipStatus.pending;
    final isActive = partnership.status == PartnershipStatus.active;
    final partnerName = isActive
        ? (partnership.partnerDisplayName ?? 'Partner')
        : null;

    return Row(children: [
      Icon(
        isActive ? Icons.handshake_rounded : Icons.hourglass_top_rounded,
        size: 16,
        color: isActive
            ? GraceWayColor.sage
            : GraceWayColor.warmWhite.withValues(alpha: 0.35),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isActive
                ? 'Walking with $partnerName'
                : 'Waiting for partner…',
            style: TextStyle(
                fontSize: 14,
                color: isActive
                    ? GraceWayColor.warmWhite
                    : GraceWayColor.warmWhite.withValues(alpha: 0.4),
                fontWeight: FontWeight.w500),
          ),
          if (isPending) ...[
            const SizedBox(height: 2),
            GestureDetector(
              onTap: () async {
                try {
                  final result = await accountability.createInvite(
                    habitId: widget.habit.id,
                    habitName: widget.habit.name,
                  );
                  if (!mounted) return;
                  await _sharePartnerLink(result.shareUrl, result.shortCode);
                } catch (e) {
                  debugPrint('createInvite (resend) failed: $e');
                }
              },
              child: Text('Resend invite',
                  style: TextStyle(
                      fontSize: 11,
                      color: GraceWayColor.sage.withValues(alpha: 0.7))),
            ),
          ],
        ]),
      ),
      if (isActive || isPending)
        GestureDetector(
          onTap: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: GraceWayColor.charcoal,
                title: Text(
                    isActive ? 'End partnership?' : 'Cancel invite?',
                    style: const TextStyle(
                        color: GraceWayColor.warmWhite, fontSize: 16)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Keep',
                        style: TextStyle(color: GraceWayColor.softGold)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(isActive ? 'End' : 'Cancel',
                        style: const TextStyle(color: GraceWayColor.warmCoral)),
                  ),
                ],
              ),
            );
            if (confirmed != true || !mounted) return;
            if (isActive) {
              await accountability.endPartnership(partnership.id);
            } else {
              await accountability.cancelPartnership(partnership.id);
            }
          },
          child: Icon(Icons.close_rounded,
              size: 16,
              color: GraceWayColor.warmWhite.withValues(alpha: 0.25)),
        ),
    ]);
  }

  Future<void> _sharePartnerLink(String url, String shortCode) async {
    await Share.share(
        'Please walk with me on my journey — open Grace Habits on your phone and accept my prayer partner invite by '
        'i) tapping the Notifications bell at the top of the screen, '
        'ii) then tapping "Enter code" and '
        'iii) then entering the code: $shortCode\n\n'
        'If you don\'t have Grace Habits, download it at this link: https://gracehabits.com');
  }

  Widget _referenceUrlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REFERENCE LINK',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: GraceWayColor.softGold.withValues(alpha: 0.5),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Attach an article, video, or resource that inspires this habit.',
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _referenceUrlController,
          keyboardType: TextInputType.url,
          autocorrect: false,
          style: const TextStyle(fontSize: 14, color: GraceWayColor.warmWhite),
          decoration: InputDecoration(
            filled: true,
            fillColor: GraceWayColor.cardBackground,
            hintText: 'https://…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: GraceWayColor.sage, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            prefixIcon: Icon(Icons.link_rounded,
                size: 18, color: GraceWayColor.softGold.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _prayerListToggle() {
    return GestureDetector(
      onTap: () => setState(() => _hasPrayerItems = !_hasPrayerItems),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: GraceWayColor.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hasPrayerItems
                ? GraceWayColor.golden.withValues(alpha: 0.3)
                : GraceWayColor.cardBorder,
            width: 0.5,
          ),
        ),
        child: Row(children: [
          Icon(Icons.format_list_bulleted_rounded,
              size: 18,
              color: _hasPrayerItems
                  ? GraceWayColor.golden
                  : Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Prayer List',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _hasPrayerItems
                          ? GraceWayColor.warmWhite
                          : Colors.white.withValues(alpha: 0.6))),
              const SizedBox(height: 2),
              Text('Track up to 10 prayer items with status on the detail screen.',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
            ]),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 22,
            decoration: BoxDecoration(
              color: _hasPrayerItems
                  ? GraceWayColor.golden
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: _hasPrayerItems
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(3),
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _archiveButton() {
    return GestureDetector(
      onTap: _confirmArchive,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: GraceWayColor.softGold.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GraceWayColor.softGold.withValues(alpha: 0.25), width: 0.5),
        ),
        child: const Center(
          child: Text(
            'Archive',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: GraceWayColor.softGold),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmArchive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GraceWayColor.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Archive habit?',
          style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        content: Text(
          '"${widget.habit.name}" will be hidden from your active habits. '
          'Your history and progress are preserved — you can restore it any time from Settings.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: GraceWayColor.softGold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive', style: TextStyle(color: GraceWayColor.softGold, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // End any partnerships before archiving so the partner is notified.
      await context
          .read<AccountabilityProvider>()
          .endPartnershipsForHabit(widget.habit.id, reason: 'archived')
          .catchError((_) {});
      if (!mounted) return;
      await context.read<HabitProvider>().archiveHabit(widget.habit);
      if (mounted) {
        Navigator.pop(context); // dismiss EditHabitView
        Navigator.pop(context); // dismiss HabitDetailView
      }
    }
  }

  Widget _deleteSection() {
    return GestureDetector(
      onTap: _confirmDelete,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: GraceWayColor.warmCoral.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GraceWayColor.warmCoral.withValues(alpha: 0.25), width: 0.5),
        ),
        child: const Center(
          child: Text(
            'Delete Habit',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: GraceWayColor.warmCoral),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final checkIns = widget.habit.totalCompletedDays();
    final habitName = widget.habit.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GraceWayColor.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete habit?',
          style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        content: Text(
          checkIns == 0
              ? '"$habitName" has no check-ins. Deleting it is permanent and cannot be undone.'
              : '"$habitName" has $checkIns ${checkIns == 1 ? 'check-in' : 'check-ins'}. Deleting it will permanently remove all your data for this habit and cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: GraceWayColor.softGold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: GraceWayColor.warmCoral, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // End any partnerships before deleting so the partner is notified.
      await context
          .read<AccountabilityProvider>()
          .endPartnershipsForHabit(widget.habit.id, reason: 'deleted')
          .catchError((_) {});
      if (!mounted) return;
      await context.read<HabitProvider>().deleteHabit(widget.habit);
      if (mounted) {
        Navigator.pop(context); // dismiss EditHabitView
        Navigator.pop(context); // dismiss HabitDetailView
      }
    }
  }

  Widget _headerSection() {
    final isAbstain = widget.habit.trackingType == HabitTrackingType.abstain;
    return Row(children: [
      Icon(_categoryIcon(), size: 18,
          color: isAbstain ? GraceWayColor.warmCoral : GraceWayColor.golden),
      const SizedBox(width: 10),
      Text(widget.habit.subcategoryName?.isNotEmpty == true
              ? widget.habit.subcategoryName!
              : (widget.habit.categoryName?.isNotEmpty == true
                  ? widget.habit.categoryName!
                  : widget.habit.category.rawValue),
          style: TextStyle(
            fontSize: 15,
            color: GraceWayColor.softGold.withValues(alpha: 0.7),
          )),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: GraceWayColor.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _trackingLabel(widget.habit.trackingType),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: GraceWayColor.softGold.withValues(alpha: 0.5)),
        ),
      ),
    ]);
  }

  String _trackingLabel(HabitTrackingType type) {
    switch (type) {
      case HabitTrackingType.timed: return 'Timed';
      case HabitTrackingType.count: return 'Count';
      case HabitTrackingType.abstain: return 'Abstain';
      case HabitTrackingType.checkIn: return 'Check-in';
    }
  }

  Widget _nameSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Habit Name',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: GraceWayColor.softGold.withValues(alpha: 0.6))),
      const SizedBox(height: 8),
      if (widget.habit.isBuiltIn)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: GraceWayColor.cardBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_nameController.text,
              style: TextStyle(fontSize: 16, color: GraceWayColor.warmWhite.withValues(alpha: 0.6))),
        )
      else
        TextField(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 16, color: GraceWayColor.warmWhite),
          decoration: InputDecoration(
            hintText: 'Habit name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: GraceWayColor.cardBackground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
    ]);
  }

  Widget _purposeSection(bool isPremium) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Your Why',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: GraceWayColor.softGold.withValues(alpha: 0.6))),
        if (!isPremium) ...[
          const Spacer(),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: GraceWayColor.charcoal,
              builder: (_) => const GraceWayPaywallView(
                contextTitle: 'Custom purpose statements',
                contextMessage: "Write your own \u2018why\u2019 for each habit. Make it personal and God-centred.",
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: GraceWayColor.golden.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.workspace_premium_rounded, size: 8, color: GraceWayColor.golden),
                const SizedBox(width: 3),
                const Text('Customise',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: GraceWayColor.golden)),
              ]),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 8),
      if (isPremium)
        TextField(
          controller: _purposeController,
          maxLines: 4,
          style: const TextStyle(fontSize: 15, color: GraceWayColor.warmWhite),
          decoration: InputDecoration(
            hintText: 'Why does this matter to you and to God?',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: GraceWayColor.cardBackground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(12),
          ),
        )
      else
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: GraceWayColor.cardBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_purposeController.text,
              style: TextStyle(fontSize: 15, color: GraceWayColor.softGold.withValues(alpha: 0.7))),
        ),
    ]);
  }

  Widget _timedTargetSection() {
    const minuteOptions = [15.0, 30.0, 45.0, 60.0];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Daily Goal (minutes)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: GraceWayColor.softGold.withValues(alpha: 0.6))),
      const SizedBox(height: 8),
      Row(
        children: minuteOptions.map((mins) {
          final selected = _dailyTarget == mins;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: mins != minuteOptions.last ? 12 : 0),
              child: GestureDetector(
                onTap: () => setState(() => _dailyTarget = mins),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? GraceWayColor.golden : GraceWayColor.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text('${mins.toInt()}',
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500,
                          color: selected ? GraceWayColor.charcoal : GraceWayColor.softGold,
                        )),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _countTargetSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Daily Goal',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: GraceWayColor.softGold.withValues(alpha: 0.6))),
      const SizedBox(height: 8),
      Row(children: [
        Text('${_dailyTarget.toInt()}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: GraceWayColor.golden)),
        const SizedBox(width: 12),
        Column(children: [
          GestureDetector(
            onTap: () => setState(() => _dailyTarget = (_dailyTarget + 1).clamp(1, 100)),
            child: const Icon(Icons.keyboard_arrow_up, color: GraceWayColor.golden),
          ),
          GestureDetector(
            onTap: () => setState(() => _dailyTarget = (_dailyTarget - 1).clamp(1, 100)),
            child: const Icon(Icons.keyboard_arrow_down, color: GraceWayColor.golden),
          ),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: TextEditingController(text: _targetUnit),
            onChanged: (v) => _targetUnit = v,
            style: const TextStyle(fontSize: 15, color: GraceWayColor.warmWhite),
            decoration: InputDecoration(
              hintText: 'Unit',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
              filled: true,
              fillColor: GraceWayColor.cardBackground,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _dayOfWeekSection(bool isAbstain) {
    const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final label = isAbstain ? 'Track days' : 'Active days';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: GraceWayColor.softGold.withValues(alpha: 0.6))),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final day = i + 1;
          final selected = _activeDays.contains(day);
          return GestureDetector(
            onTap: () => setState(() {
              if (selected) {
                _activeDays.remove(day);
              } else {
                _activeDays.add(day);
              }
            }),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? GraceWayColor.golden : GraceWayColor.cardBackground,
                border: Border.all(color: selected ? GraceWayColor.golden : GraceWayColor.cardBorder, width: 0.5),
              ),
              child: Center(
                child: Text(dayLabels[i],
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: selected ? GraceWayColor.charcoal : Colors.white.withValues(alpha: 0.4),
                    )),
              ),
            ),
          );
        }),
      ),
    ]);
  }

  Widget _triggerSection() {
    final chips = _triggerChips();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('When will you do this?',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: GraceWayColor.softGold.withValues(alpha: 0.6))),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((chip) {
            final selected = _triggerController.text == chip;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _triggerController.text = chip),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? GraceWayColor.golden : GraceWayColor.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(chip,
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: selected ? GraceWayColor.charcoal : GraceWayColor.softGold,
                      )),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _triggerController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 15, color: GraceWayColor.warmWhite),
        decoration: InputDecoration(
          hintText: 'Or type your own trigger\u2026',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          filled: true,
          fillColor: GraceWayColor.cardBackground,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    ]);
  }

  Widget _categoryChipsRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_categoryName != null)
          _editChip(
            label: _categoryName!,
            onTap: () => _openSubcategoryPicker(startOnCategories: true),
          ),
        if (_subcategoryName != null && _subcategoryName!.isNotEmpty)
          _editChip(
            label: _subcategoryName!,
            onTap: () => _openSubcategoryPicker(startOnCategories: false),
          ),
      ],
    );
  }

  Widget _editChip({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: GraceWayColor.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.5), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: GraceWayColor.golden.withValues(alpha: 0.9)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 11, color: GraceWayColor.golden.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubcategoryPicker({required bool startOnCategories}) async {
    final catProvider = context.read<HabitCategoryProvider>();
    final result = await showModalBottomSheet<
        ({String categoryId, String subcategoryId, String categoryName, String subcategoryName})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: GraceWayColor.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SubcategoryPickerSheet(
        initialCategoryId: startOnCategories ? null : _categoryId,
        catProvider: catProvider,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _categoryId = result.categoryId;
        _subcategoryId = result.subcategoryId;
        _categoryName = result.categoryName;
        _subcategoryName = result.subcategoryName;
      });
    }
  }

  Widget _copingSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('When I feel tempted, I will\u2026',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: GraceWayColor.softGold.withValues(alpha: 0.6))),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _copingSuggestions.map((s) {
            final selected = _copingController.text == s;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _copingController.text = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? GraceWayColor.warmCoral : GraceWayColor.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(s,
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: selected ? GraceWayColor.charcoal : GraceWayColor.softGold,
                      )),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _copingController,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 15, color: GraceWayColor.warmWhite),
        decoration: InputDecoration(
          hintText: 'Or write your own plan\u2026',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          filled: true,
          fillColor: GraceWayColor.cardBackground,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    ]);
  }
}

// ── SubcategoryPickerSheet ────────────────────────────────────────────────────

typedef _CategoryResult = ({
  String categoryId,
  String subcategoryId,
  String categoryName,
  String subcategoryName
});

class SubcategoryPickerSheet extends StatefulWidget {
  final String? initialCategoryId;
  final HabitCategoryProvider catProvider;

  const SubcategoryPickerSheet({
    super.key,
    required this.initialCategoryId,
    required this.catProvider,
  });

  @override
  State<SubcategoryPickerSheet> createState() => _SubcategoryPickerSheetState();
}

class _SubcategoryPickerSheetState extends State<SubcategoryPickerSheet> {
  HabitCategoryModel? _selectedCategory;
  // 1 = category grid, 2 = subcategory grid
  late int _step;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoryId != null) {
      final cat = widget.catProvider.categoryById(widget.initialCategoryId!);
      if (cat != null) {
        _selectedCategory = cat;
        _step = 2;
      } else {
        _step = 1;
      }
    } else {
      _step = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, sc) => Column(
        children: [
          _sheetHandle(),
          _sheetAppBar(),
          Expanded(
            child: SingleChildScrollView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: _step == 1 ? _categoryGrid() : _subcategoryGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _sheetAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          if (_step == 2)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18, color: GraceWayColor.warmWhite),
              onPressed: () => setState(() => _step = 1),
            )
          else
            IconButton(
              icon: const Icon(Icons.close, color: GraceWayColor.warmWhite),
              onPressed: () => Navigator.pop(context),
            ),
          Expanded(
            child: Text(
              _step == 1 ? 'Choose a Category' : (_selectedCategory?.name ?? ''),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: GraceWayColor.warmWhite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryGrid() {
    final categories = widget.catProvider.categories;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: categories.map((cat) => GestureDetector(
        onTap: () {
          if (cat.isCustom) {
            Navigator.pop<_CategoryResult>(context, (
              categoryId: cat.id,
              subcategoryId: 'custom',
              categoryName: cat.name,
              subcategoryName: '',
            ));
          } else {
            setState(() {
              _selectedCategory = cat;
              _step = 2;
            });
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: GraceWayColor.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GraceWayColor.cardBorder, width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconForKey(cat.iconKey), size: 24, color: GraceWayColor.golden),
              const SizedBox(height: 8),
              Text(
                cat.name,
                textAlign: TextAlign.center,
                maxLines: 3,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: GraceWayColor.warmWhite,
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _subcategoryGrid() {
    final cat = _selectedCategory!;
    final subcategories = widget.catProvider.subcategoriesFor(cat.id);

    return Column(
      children: subcategories.map((sub) {
        return GestureDetector(
          onTap: () => Navigator.pop<_CategoryResult>(context, (
            categoryId: cat.id,
            subcategoryId: sub.id,
            categoryName: cat.name,
            subcategoryName: sub.isCustom ? '' : sub.name,
          )),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GraceWayColor.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: GraceWayColor.cardBorder, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(iconForKey(sub.iconKey), size: 20, color: GraceWayColor.golden),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sub.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: GraceWayColor.warmWhite,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios,
                        size: 12, color: Colors.white.withValues(alpha: 0.3)),
                  ],
                ),
                if (sub.yourWhy.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    sub.yourWhy,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withValues(alpha: 0.5),
                      height: 1.4,
                    ),
                  ),
                ],
                if (sub.keyVerseRef != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.format_quote,
                          size: 12, color: GraceWayColor.golden.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        sub.keyVerseRef!,
                        style: TextStyle(
                          fontSize: 11,
                          color: GraceWayColor.golden.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
