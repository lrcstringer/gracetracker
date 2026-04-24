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
import '../shared/day_of_week_picker.dart';
import '../shared/graceway_paywall_view.dart';

class AddHabitView extends StatefulWidget {
  final ScrollController? scrollController;
  final String? prefilledCategoryId;
  final String? prefilledCategoryName;
  final String? prefilledSubcategoryName;

  const AddHabitView({
    super.key,
    this.scrollController,
    this.prefilledCategoryId,
    this.prefilledCategoryName,
    this.prefilledSubcategoryName,
  });

  @override
  State<AddHabitView> createState() => _AddHabitViewState();
}

class _AddHabitViewState extends State<AddHabitView> {
  // Step: 1=category grid, 2=subcategory picker, 3=set it up
  int _step = 1;

  // New two-level category selection
  HabitCategoryModel? _selectedCategoryModel;
  HabitSubcategoryModel? _selectedSubcategoryModel;
  String? _categoryId;
  String? _subcategoryId;
  String? _categoryName;
  String? _subcategoryName;

  // Legacy enum kept for backward-compat with trigger chips / purpose defaults
  HabitCategory _selectedCategory = HabitCategory.custom;

  bool get _isPreFilled => widget.prefilledCategoryId != null;

  @override
  void initState() {
    super.initState();
    _notesController = QuillController.basic();
    if (widget.prefilledCategoryId != null) {
      _categoryId = widget.prefilledCategoryId;
      _categoryName = widget.prefilledCategoryName;
      _subcategoryId = 'custom';
      _subcategoryName = widget.prefilledSubcategoryName ?? '';
      _purposeStatement = HabitCategory.custom.defaultPurpose;
      _step = 3;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocusNode.dispose();
    _notesScrollController.dispose();
    _referenceUrlController.dispose();
    super.dispose();
  }

  // Habit form fields
  String _habitName = '';
  String _purposeStatement = '';
  HabitTrackingType _trackingType = HabitTrackingType.checkIn;
  double _dailyTarget = 1;
  String _targetUnit = '';
  Set<int> _activeDays = {1, 2, 3, 4, 5, 6, 7};
  String _trigger = '';
  String _copingPlan = '';
  late QuillController _notesController;
  final FocusNode _notesFocusNode = FocusNode();
  final ScrollController _notesScrollController = ScrollController();
  final TextEditingController _referenceUrlController = TextEditingController();

  // ── App bar ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<StoreProvider>().isPremium;

    String title;
    Widget leading;

    if (_step == 1) {
      title = 'Choose a Habit';
      leading = IconButton(
        icon: const Icon(Icons.close, color: GraceWayColor.warmWhite),
        onPressed: () => Navigator.pop(context),
      );
    } else if (_step == 2) {
      title = _selectedCategoryModel?.name ?? '';
      leading = IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: GraceWayColor.warmWhite, size: 18),
        onPressed: () => setState(() => _step = 1),
      );
    } else {
      title = 'Set It Up';
      leading = IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: GraceWayColor.warmWhite, size: 18),
        onPressed: () {
          if (_isPreFilled) {
            Navigator.pop(context);
          } else {
            setState(() {
              _step = (_selectedCategoryModel?.isCustom ?? true) ? 1 : 2;
            });
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        leading: leading,
        title: Text(
          title,
          style: const TextStyle(
              color: GraceWayColor.warmWhite, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_step == 1)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: GraceWayColor.softGold.withValues(alpha: 0.8))),
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
        child: _step == 1
            ? _categoryGrid()
            : _step == 2
                ? _subcategoryPicker()
                : _habitDetails(isPremium),
      ),
    );
  }

  // ── Step 1: Category grid ────────────────────────────────────────────────

  Widget _categoryGrid() {
    const hiddenCategoryIds = {'fruit_of_the_spirit'};
    final categories = context
        .watch<HabitCategoryProvider>()
        .categories
        .where((c) => !hiddenCategoryIds.contains(c.id))
        .toList();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: categories.map((cat) => GestureDetector(
        onTap: () => _selectCategoryModel(cat),
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

  // ── Step 2: Subcategory picker ───────────────────────────────────────────

  Widget _subcategoryPicker() {
    final subcategories = context
        .read<HabitCategoryProvider>()
        .subcategoriesFor(_selectedCategoryModel!.id);

    return Column(
      children: [
        ...subcategories.map((sub) => _subcategoryCard(sub)),
        _customSubcategoryCard(),
      ],
    );
  }

  Widget _subcategoryCard(HabitSubcategoryModel sub) {
    return GestureDetector(
      onTap: () => _selectSubcategory(sub),
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
            // Title row
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
                  Icon(Icons.format_quote, size: 12,
                      color: GraceWayColor.golden.withValues(alpha: 0.6)),
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
  }

  Widget _customSubcategoryCard() {
    return GestureDetector(
      onTap: _selectCustomSubcategory,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GraceWayColor.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: GraceWayColor.golden.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 20, color: GraceWayColor.golden),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create My Own Practice',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: GraceWayColor.warmWhite,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Name it, set a goal, and make it yours.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  // ── Step 3: Set It Up ────────────────────────────────────────────────────

  Widget _habitDetails(bool isPremium) {
    final isAbstain = _subcategoryId == 'breaking_habits' ||
        _selectedCategory == HabitCategory.abstain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category/subcategory chips
        _categoryChipsRow(),
        const SizedBox(height: 20),

        // Subcategory content card (Key Verse, Your Why, Examples, Supporting Verses)
        if (_selectedSubcategoryModel != null && !(_selectedCategoryModel?.isCustom ?? true))
          _subcategoryContentCard(_selectedSubcategoryModel!),

        // Name
        _label('Habit Name'),
        const SizedBox(height: 8),
        _textField(
          hint: 'e.g. Morning run',
          value: _habitName,
          onChanged: (v) => setState(() => _habitName = v),
        ),
        const SizedBox(height: 20),

        // Purpose
        Row(
          children: [
            _label('Your Why', inline: true),
            if (!isPremium) ...[
              const Spacer(),
              GestureDetector(
                onTap: () => _showPaywall(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: GraceWayColor.golden.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium, size: 10, color: GraceWayColor.golden),
                      const SizedBox(width: 3),
                      Text('Customise',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: GraceWayColor.golden)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (isPremium)
          _textField(
            hint: 'Why does this matter to you and to God?',
            value: _purposeStatement,
            onChanged: (v) => setState(() => _purposeStatement = v),
            maxLines: 3,
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GraceWayColor.surfaceOverlay,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _purposeStatement,
              style:
                  TextStyle(fontSize: 14, color: GraceWayColor.softGold.withValues(alpha: 0.7)),
            ),
          ),
        const SizedBox(height: 20),

        // Tracking type (not for abstain)
        if (!isAbstain) ...[
          _label('Tracking Type'),
          const SizedBox(height: 8),
          Row(
            children: [
              HabitTrackingType.checkIn,
              HabitTrackingType.timed,
              HabitTrackingType.count,
            ].map((type) {
              final selected = _trackingType == type;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _setTrackingType(type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? GraceWayColor.golden : GraceWayColor.surfaceOverlay,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          _trackingTypeLabel(type),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected ? GraceWayColor.charcoal : GraceWayColor.softGold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Timed goal
        if (_trackingType == HabitTrackingType.timed) ...[
          _label('Daily Goal (minutes)'),
          const SizedBox(height: 8),
          Row(
            children: [15.0, 30.0, 45.0, 60.0].map((mins) {
              final selected = _dailyTarget == mins;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _dailyTarget = mins),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? GraceWayColor.golden : GraceWayColor.surfaceOverlay,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${mins.toInt()}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: selected ? GraceWayColor.charcoal : GraceWayColor.softGold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Count goal
        if (_trackingType == HabitTrackingType.count) ...[
          _label('Daily Goal'),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: GraceWayColor.surfaceOverlay,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed:
                          _dailyTarget > 1 ? () => setState(() => _dailyTarget--) : null,
                      icon: const Icon(Icons.remove, size: 18, color: GraceWayColor.softGold),
                    ),
                    Text(
                      '${_dailyTarget.toInt()}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: GraceWayColor.golden),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _dailyTarget++),
                      icon: const Icon(Icons.add, size: 18, color: GraceWayColor.softGold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _textField(
                  hint: 'Unit (e.g. glasses)',
                  value: _targetUnit,
                  onChanged: (v) => setState(() => _targetUnit = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],


        // Day of week picker
        DayOfWeekPicker(
          selected: _activeDays,
          onChanged: (days) => setState(() => _activeDays = days),
          isAbstain: isAbstain,
        ),
        const SizedBox(height: 20),

        // Anchoring section
        _anchoringSection(isAbstain),
        const SizedBox(height: 28),

        // Support/Prayer Partner (abstain only)
        if (isAbstain) ...[
          _partnerSection(),
          const SizedBox(height: 28),
        ],

        // Notes
        _notesSection(),
        const SizedBox(height: 20),

        // Reference URL
        _referenceUrlSection(),
        const SizedBox(height: 28),

        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _habitName.trim().isEmpty ? null : _saveHabit,
            style: ElevatedButton.styleFrom(
              backgroundColor: GraceWayColor.golden,
              foregroundColor: GraceWayColor.charcoal,
              disabledBackgroundColor: GraceWayColor.golden.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Set this habit',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  // ── Subcategory content card (Step 3) ────────────────────────────────────

  Widget _subcategoryContentCard(HabitSubcategoryModel sub) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: GraceWayColor.surfaceOverlay,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: GraceWayColor.golden.withValues(alpha: 0.15), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Key Verse
              if (sub.keyVerse != null && sub.keyVerseRef != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.format_quote,
                        size: 16, color: GraceWayColor.golden.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.keyVerse!,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: GraceWayColor.warmWhite.withValues(alpha: 0.85),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '— ${sub.keyVerseRef!}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: GraceWayColor.golden.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                    color: GraceWayColor.golden.withValues(alpha: 0.12), thickness: 0.5),
                const SizedBox(height: 12),
              ],

              // Your Why
              if (sub.yourWhy.isNotEmpty) ...[
                Text(
                  'YOUR WHY',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                    color: GraceWayColor.softGold.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  sub.yourWhy,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Examples
              if (sub.examples.isNotEmpty) ...[
                Divider(
                    color: GraceWayColor.golden.withValues(alpha: 0.12), thickness: 0.5),
                const SizedBox(height: 12),
                Text(
                  'EXAMPLES',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                    color: GraceWayColor.softGold.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sub.examples.map((ex) => GestureDetector(
                    onTap: () => setState(() => _habitName = ex),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _habitName == ex
                            ? GraceWayColor.golden.withValues(alpha: 0.2)
                            : GraceWayColor.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _habitName == ex
                              ? GraceWayColor.golden.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        ex,
                        style: TextStyle(
                          fontSize: 12,
                          color: _habitName == ex
                              ? GraceWayColor.golden
                              : Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Supporting Verses link
              if (sub.supportingVerses.isNotEmpty) ...[
                Divider(
                    color: GraceWayColor.golden.withValues(alpha: 0.12), thickness: 0.5),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showSupportingVerses(sub),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 14, color: GraceWayColor.golden.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        'Supporting Verses (${sub.supportingVerses.length})',
                        style: TextStyle(
                          fontSize: 12,
                          color: GraceWayColor.golden.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                          decorationColor: GraceWayColor.golden.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showSupportingVerses(HabitSubcategoryModel sub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GraceWayColor.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 18, color: GraceWayColor.golden.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${sub.name} — Supporting Verses',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: GraceWayColor.warmWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: GraceWayColor.golden.withValues(alpha: 0.15), height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                itemCount: sub.supportingVerses.length + 1,
                separatorBuilder: (_, i) => i == 0
                    ? const SizedBox(height: 16)
                    : Divider(color: Colors.white.withValues(alpha: 0.07), height: 24),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Text(
                      'These verses are to spur your thinking, but it\'s good practice to always read a verse within its context and not isolated from its surrounding Scripture.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.55,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    );
                  }
                  final v = sub.supportingVerses[i - 1];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.text,
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '— ${v.ref}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: GraceWayColor.golden.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChipsRow() {
    if (_categoryId == null || _isPreFilled) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_categoryName != null)
          _categoryChip(
            label: _categoryName!,
            onTap: () => setState(() => _step = 1),
          ),
        if (_subcategoryName != null && _subcategoryName!.isNotEmpty)
          _categoryChip(
            label: _subcategoryName!,
            onTap: () => setState(() => _step = 2),
          ),
      ],
    );
  }

  Widget _categoryChip({required String label, required VoidCallback onTap}) {
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
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: GraceWayColor.golden.withValues(alpha: 0.9))),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined,
                size: 11, color: GraceWayColor.golden.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  // ── Selection handlers ───────────────────────────────────────────────────

  void _selectCategoryModel(HabitCategoryModel cat) {
    final legacyEnum = _toOldEnum(cat.id, null);
    if (cat.isCustom) {
      // Skip subcategory step for "Create My Own"
      setState(() {
        _selectedCategoryModel = cat;
        _selectedSubcategoryModel = null;
        _selectedCategory = legacyEnum;
        _categoryId = cat.id;
        _subcategoryId = 'custom';
        _categoryName = cat.name;
        _subcategoryName = '';
        _trackingType = HabitTrackingType.checkIn;
        _habitName = '';
        _purposeStatement = legacyEnum.defaultPurpose;
        _dailyTarget = 1;
        _targetUnit = '';
        _step = 3;
      });
    } else {
      setState(() {
        _selectedCategoryModel = cat;
        _selectedCategory = legacyEnum;
        _step = 2;
      });
    }
  }

  void _selectCustomSubcategory() {
    final legacyEnum = _toOldEnum(_selectedCategoryModel!.id, null);
    setState(() {
      _selectedSubcategoryModel = null;
      _selectedCategory = legacyEnum;
      _categoryId = _selectedCategoryModel!.id;
      _subcategoryId = 'custom';
      _categoryName = _selectedCategoryModel!.name;
      _subcategoryName = '';
      _trackingType = HabitTrackingType.checkIn;
      _dailyTarget = 1;
      _targetUnit = '';
      _habitName = '';
      _purposeStatement = legacyEnum.defaultPurpose;
      _step = 3;
    });
  }

  void _selectSubcategory(HabitSubcategoryModel sub) {
    final legacyEnum = _toOldEnum(_selectedCategoryModel!.id, sub.id);
    final trackingType = _trackingTypeFromSuggestion(sub.trackingTypeSuggestion);
    final isCustomSub = sub.isCustom;

    setState(() {
      _selectedSubcategoryModel = sub;
      _categoryId = _selectedCategoryModel!.id;
      _subcategoryId = sub.id;
      _categoryName = _selectedCategoryModel!.name;
      _subcategoryName = isCustomSub ? '' : sub.name;

      _trackingType = trackingType;
      _dailyTarget = sub.defaultTargetMinutes?.toDouble() ?? _defaultTarget(legacyEnum);
      _targetUnit = trackingType == HabitTrackingType.timed ? 'minutes' : '';
      _habitName = isCustomSub ? '' : sub.name;
      _purposeStatement = sub.yourWhy.isNotEmpty ? sub.yourWhy : legacyEnum.defaultPurpose;
      _step = 3;
    });
  }

  // ── Notes section ────────────────────────────────────────────────────────

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
    final nudgeKeywords = RegExp(
        r'\b(call|reach out|text|someone|friend|partner|prayer)\b',
        caseSensitive: false);
    final showNudge =
        nudgeKeywords.hasMatch(_copingPlan) && _copingPlan.isNotEmpty;

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
          'Invite someone to walk with you. They\'ll be notified when you need support.',
          style:
              TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
        ),
        if (showNudge) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: GraceWayColor.sage.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: GraceWayColor.sage.withValues(alpha: 0.18), width: 0.5),
            ),
            child: Row(children: [
              const Icon(Icons.lightbulb_outline_rounded,
                  size: 13, color: GraceWayColor.sage),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Your coping plan mentions reaching out — adding a partner makes that easier.',
                  style: TextStyle(
                      fontSize: 12,
                      color: GraceWayColor.sage.withValues(alpha: 0.85),
                      height: 1.4),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: GraceWayColor.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: GraceWayColor.warmWhite.withValues(alpha: 0.07), width: 0.5),
          ),
          child: Row(children: [
            Icon(Icons.handshake_rounded,
                size: 16, color: GraceWayColor.warmWhite.withValues(alpha: 0.3)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You can invite a partner after saving this habit.',
                style: TextStyle(
                    fontSize: 13,
                    color: GraceWayColor.warmWhite.withValues(alpha: 0.45),
                    height: 1.4),
              ),
            ),
          ]),
        ),
      ],
    );
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

  void _saveHabit() {
    final trimmed = _habitName.trim();
    if (trimmed.isEmpty) return;
    final isPremium = context.read<StoreProvider>().isPremium;
    final purpose = isPremium ? _purposeStatement : _selectedCategory.defaultPurpose;
    final plainNotes = _notesController.document.toPlainText().trim();
    final notesJson = plainNotes.isEmpty
        ? ''
        : jsonEncode(_notesController.document.toDelta().toJson());
    final refUrl = _referenceUrlController.text.trim();
    context.read<HabitProvider>().addHabit(
      name: trimmed,
      category: _selectedCategory,
      trackingType: _trackingType,
      purpose: purpose,
      dailyTarget: _dailyTarget,
      targetUnit: _targetUnit,
      activeDays: _activeDays,
      trigger: _trigger,
      copingPlan: _copingPlan,
      categoryId: _categoryId,
      subcategoryId: _subcategoryId,
      categoryName: _categoryName,
      subcategoryName: _subcategoryName?.trim().isEmpty ?? true
          ? null
          : _subcategoryName,
      notes: notesJson,
      referenceUrl: refUrl,
    );
    Navigator.pop(context);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  HabitCategory _toOldEnum(String categoryId, String? subcategoryId) {
    // Subcategory-level precision first
    if (subcategoryId != null) {
      return switch (subcategoryId) {
        'gods_word'     => HabitCategory.scripture,
        'prayer'        => HabitCategory.scripture,
        'church_life'   => HabitCategory.scripture,
        'evangelism'    => HabitCategory.scripture,
        'worship'       => HabitCategory.gratitude,
        'fasting'       => HabitCategory.fasting,
        'exercise'      => HabitCategory.exercise,
        'health_and_nutrition' => HabitCategory.health,
        'rest_and_renewal'     => HabitCategory.rest,
        'reading_and_learning' => HabitCategory.study,
        'creativity'    => HabitCategory.custom,
        'stewardship'   => HabitCategory.custom,
        'breaking_habits'      => HabitCategory.abstain,
        'service_and_generosity'   => HabitCategory.service,
        'connection_and_community' => HabitCategory.connection,
        _               => HabitCategory.custom,
      };
    }
    // Category-level fallback
    return switch (categoryId) {
      'loving_the_lord'   => HabitCategory.scripture,
      'caring_for_myself' => HabitCategory.health,
      'caring_for_others' => HabitCategory.service,
      _                   => HabitCategory.custom,
    };
  }

  HabitTrackingType _trackingTypeFromSuggestion(String suggestion) {
    return switch (suggestion) {
      'timed'   => HabitTrackingType.timed,
      'count'   => HabitTrackingType.count,
      'abstain' => HabitTrackingType.abstain,
      _         => HabitTrackingType.checkIn,
    };
  }

  void _setTrackingType(HabitTrackingType type) {
    setState(() {
      _trackingType = type;
      if (type == HabitTrackingType.timed) {
        _dailyTarget = 30;
        _targetUnit = 'minutes';
      } else if (type == HabitTrackingType.count) {
        _dailyTarget = 8;
        _targetUnit = '';
      } else {
        _dailyTarget = 1;
        _targetUnit = '';
      }
    });
  }

  double _defaultTarget(HabitCategory category) {
    switch (category) {
      case HabitCategory.exercise:
        return 30;
      case HabitCategory.scripture:
        return 15;
      case HabitCategory.study:
        return 30;
      case HabitCategory.health:
        return 8;
      default:
        return 1;
    }
  }

  // ── Anchoring section ────────────────────────────────────────────────────

  Widget _anchoringSection(bool isAbstain) {
    if (isAbstain) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('When I feel tempted, I will\u2026'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Pray first', 'Call a friend', 'Go for a walk', 'Read my verse',
                      'Journal it out']
                  .map((s) => _chipButton(s, _copingPlan == s, GraceWayColor.warmCoral,
                      () => setState(() => _copingPlan = s)))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          _textField(
            hint: 'Or write your own plan\u2026',
            value: _copingPlan,
            onChanged: (v) => setState(() => _copingPlan = v),
          ),
        ],
      );
    }

    final chips = _triggerChips(_selectedCategory);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('When will you do this?'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: chips
                .map((s) => _chipButton(
                    s, _trigger == s, GraceWayColor.golden, () => setState(() => _trigger = s)))
                .toList(),
          ),
        ),
        const SizedBox(height: 10),
        _textField(
          hint: 'Or type your own trigger\u2026',
          value: _trigger,
          onChanged: (v) => setState(() => _trigger = v),
        ),
      ],
    );
  }

  // ── Small widgets ────────────────────────────────────────────────────────

  Widget _label(String text, {bool inline = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: GraceWayColor.softGold.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _textField({
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) {
    return TextField(
      controller: TextEditingController(text: value)
        ..selection = TextSelection.collapsed(offset: value.length),
      onChanged: onChanged,
      maxLines: maxLines,
      style: const TextStyle(color: GraceWayColor.warmWhite, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
        filled: true,
        fillColor: GraceWayColor.surfaceOverlay,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _chipButton(
      String label, bool selected, Color activeColor, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? activeColor : GraceWayColor.surfaceOverlay,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? GraceWayColor.charcoal : GraceWayColor.softGold,
            ),
          ),
        ),
      ),
    );
  }

  void _showPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: GraceWayColor.charcoal,
      builder: (_) => const GraceWayPaywallView(),
    );
  }

  String _trackingTypeLabel(HabitTrackingType type) {
    switch (type) {
      case HabitTrackingType.checkIn:
        return 'Yes/No';
      case HabitTrackingType.timed:
        return 'Timed';
      case HabitTrackingType.count:
        return 'Count';
      case HabitTrackingType.abstain:
        return 'Abstain';
    }
  }

  List<String> _triggerChips(HabitCategory category) {
    switch (category) {
      case HabitCategory.exercise:
        return ['After my morning coffee', 'Before work', 'During lunch break', 'After dinner'];
      case HabitCategory.scripture:
        return ['First thing in the morning', 'Before bed', 'During lunch', 'After prayer'];
      case HabitCategory.rest:
        return ['At 10pm', 'After dinner', 'When I feel tired'];
      case HabitCategory.fasting:
        return ['After morning prayer', 'On Wednesdays', 'Weekly'];
      case HabitCategory.study:
        return ['After dinner', 'Morning routine', 'Lunch break'];
      case HabitCategory.service:
        return ['After church', 'On weekends', 'When I see a need'];
      case HabitCategory.connection:
        return ['Sunday afternoon', 'After dinner', 'During commute'];
      case HabitCategory.health:
        return ['With every meal', 'First thing in the morning', 'After exercise', 'Before bed'];
      default:
        return ['In the morning', 'After lunch', 'Before bed'];
    }
  }
}
