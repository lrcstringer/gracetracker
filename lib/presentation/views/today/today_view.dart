import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/scripture.dart';
import '../../providers/habit_provider.dart';
import '../../providers/habit_category_provider.dart';
import '../../providers/store_provider.dart';
import '../../../domain/entities/circle.dart';
import '../../../domain/repositories/circle_repository.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../domain/services/engagement_service.dart';
import '../../../domain/services/week_cycle_manager.dart';
import '../../theme/app_theme.dart';
import '../circles/share_gratitude_sheet.dart';
import '../habits/add_habit_view.dart';
import '../habits/habit_check_in_card_view.dart';
import '../shared/engagement_banner_view.dart';
import '../shared/golden_pulse_view.dart';
import '../shared/graceway_paywall_view.dart';
import '../shared/appbar_actions.dart';
import '../help/today_help_view.dart';
import '../week/week_strip_view.dart';
import 'widgets/category_group_header.dart';

class TodayView extends StatefulWidget {
  final WeekCycleManager weekCycleManager;
  final bool showAutoCarryBanner;
  final VoidCallback? onDismissAutoCarry;

  const TodayView({
    super.key,
    required this.weekCycleManager,
    required this.showAutoCarryBanner,
    this.onDismissAutoCarry,
  });

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> with WidgetsBindingObserver {
  DateTime _selectedDate = DateTime.now();
  EngagementMessage? _engagementMessage;
  bool _showEngagementBanner = false;

  static const _freeHabitLimit = 2;

  bool get _isRetroactive {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final selStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return selStart.isBefore(todayStart);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDate = DateTime.now();
    _loadEngagementMessage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final selStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      // Advance _selectedDate to today if the day rolled over while backgrounded.
      // Handles any gap (1 day, multiple days) so the user is never stuck on a past date.
      if (selStart.isBefore(todayStart)) {
        setState(() => _selectedDate = now);
      }
    }
  }

  Future<void> _loadEngagementMessage() async {
    final habits = context.read<HabitProvider>().habits;
    final isPremium = context.read<StoreProvider>().isPremium;
    final engagement = context.read<EngagementService>();
    engagement.isPremium = isPremium;
    await engagement.evaluateMessage(habits.toList());
    final msg = engagement.currentMessage;
    if (msg != null && mounted) {
      setState(() {
        _engagementMessage = msg;
        _showEngagementBanner = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitProvider = context.watch<HabitProvider>();
    final store = context.watch<StoreProvider>();
    final catProvider = context.watch<HabitCategoryProvider>();
    final habits = habitProvider.sortedHabits;
    final isPremium = store.isPremium;

    // habits may be empty during initial load — guard before any .first access.
    if (habits.isEmpty) {
      return const Scaffold(
        backgroundColor: GraceWayColor.charcoal,
        body: Center(child: CircularProgressIndicator(color: GraceWayColor.golden)),
      );
    }
    final gratitudeHabit = habits.firstWhere(
      (h) => h.isBuiltIn && h.category == HabitCategory.gratitude,
      orElse: () => habits.first,
    );
    final userHabits = habits.where((h) => !h.isBuiltIn).toList();

    final atLimit = !isPremium && userHabits.length >= _freeHabitLimit;

    final imageHeight = MediaQuery.of(context).size.width * 0.65;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: GraceWayColor.charcoal,
          body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: GraceWayColor.charcoal,
                  foregroundColor: GraceWayColor.warmWhite,
                  expandedHeight: imageHeight,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  title: const Text(
                    'Grace Habits',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  actions: [
                    ...standardAppBarActions(context, helpView: const TodayHelpView()),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/icon1.png',
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                GraceWayColor.charcoal.withValues(alpha: 0.5),
                                GraceWayColor.charcoal,
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Grace Habits',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: GraceWayColor.warmWhite,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                '\u2018This is the day that the Lord has made; let us rejoice and be glad in it.\u2019',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: GraceWayColor.softGold,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Psalm 118:24',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: GraceWayColor.golden,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                        child: _titleSection(),
                      ),

                      // Engagement banner
                      if (_showEngagementBanner && _engagementMessage != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: EngagementBannerView(
                            message: _engagementMessage!,
                            onDismiss: () {
                              setState(() => _showEngagementBanner = false);
                              context.read<EngagementService>().dismissCurrentMessage();
                            },
                          ),
                        ),

                      // Auto carry banner
                      if (widget.showAutoCarryBanner)
                        _autoCarryBanner(),

                      // Week strip
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: WeekStripView(
                          habits: habits.toList(),
                          selectedDate: _selectedDate,
                          onDateSelected: (date) => setState(() => _selectedDate = date),
                        ),
                      ),

                      if (_isRetroactive)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                          child: _retroactiveBanner(),
                        ),

                      const SizedBox(height: 16),

                      // Gratitude card
                      if (habits.any((h) => h.isBuiltIn && h.category == HabitCategory.gratitude))
                        _gratitudeCard(gratitudeHabit),

                      // User habits (grouped by category)
                      ..._buildGroupedHabitList(
                        userHabits,
                        catProvider,
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
          ),
        ),

        // Add a habit — always visible unless in retroactive mode.
        if (!_isRetroactive)
          Positioned(
            bottom: 24,
            right: 20,
            child: _addHabitButton(atLimit: atLimit),
          ),

      ],
    );
  }

  Widget _titleSection() {
    final now = DateTime.now();
    final hour = now.hour;
    final name = context.read<AuthService>().givenName;
    final base = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final greeting = name != null ? '$base, $name' : base;
    return Text(
      greeting,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: GraceWayColor.warmWhite,
      ),
    );
  }

  Widget _autoCarryBanner() {
    return GestureDetector(
      onTap: widget.onDismissAutoCarry,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: GraceWayColor.golden.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: GraceWayColor.golden, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'New week, same habits. You\'re already on Day ${DateTime.now().weekday % 7 + 1}. Let\'s keep going.',
                style: TextStyle(
                  color: GraceWayColor.softGold.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ),
            GestureDetector(
              onTap: widget.onDismissAutoCarry,
              child: Icon(Icons.close, size: 14, color: GraceWayColor.softGold.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _retroactiveBanner() {
    final formatter = _dayName(_selectedDate);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GraceWayColor.softGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GraceWayColor.softGold.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 14, color: GraceWayColor.softGold.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(
            'Logging for $formatter',
            style: TextStyle(
              fontSize: 12,
              color: GraceWayColor.softGold.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gratitudeCard(Habit habit) {
    return _GratitudeCheckInCard(
      habit: habit,
      targetDate: _selectedDate,
      isRetroactive: _isRetroactive,
    );
  }

  Widget _addHabitButton({required bool atLimit}) {
    return FloatingActionButton.extended(
      onPressed: () => atLimit ? _showPaywall(context) : _showAddHabit(context),
      backgroundColor: GraceWayColor.softGold.withValues(alpha: 0.12),
      foregroundColor: GraceWayColor.softGold,
      elevation: 0,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Add a habit', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  String _dayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  List<Widget> _buildGroupedHabitList(
    List<Habit> habits,
    HabitCategoryProvider catProvider,
  ) {
    final sorted = List<Habit>.from(habits)
      ..sort((a, b) {
        final oA = catProvider.categoryById(a.categoryId ?? '')?.sortOrder ?? 99;
        final oB = catProvider.categoryById(b.categoryId ?? '')?.sortOrder ?? 99;
        if (oA != oB) return oA.compareTo(oB);
        return a.createdAt.compareTo(b.createdAt);
      });

    final widgets = <Widget>[];
    String? lastCategoryId;

    for (final habit in sorted) {
      if (habit.categoryId != null && habit.categoryId != lastCategoryId) {
        final name = catProvider.categoryById(habit.categoryId!)?.name ?? '';
        if (name.isNotEmpty) widgets.add(CategoryGroupHeader(categoryName: name));
        lastCategoryId = habit.categoryId;
      }
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: HabitCheckInCardView(
          habit: habit,
          targetDate: _selectedDate,
          isRetroactive: _isRetroactive,
        ),
      ));
    }
    return widgets;
  }

  void _showAddHabit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: GraceWayColor.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        expand: false,
        builder: (ctx, sc) => AddHabitView(scrollController: sc),
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

}

// Inline gratitude check-in card
class _GratitudeCheckInCard extends StatefulWidget {
  final Habit habit;
  final DateTime targetDate;
  final bool isRetroactive;

  const _GratitudeCheckInCard({
    required this.habit,
    required this.targetDate,
    required this.isRetroactive,
  });

  @override
  State<_GratitudeCheckInCard> createState() => _GratitudeCheckInCardState();
}

class _GratitudeCheckInCardState extends State<_GratitudeCheckInCard> {
  final _controller = TextEditingController();
  bool _isCompleted = false;
  bool _showPulse = false;
  Scripture? _verse;
  bool _expanded = true;
  bool _showSharePrompt = false;
  List<Circle>? _userCircles;

  @override
  void initState() {
    super.initState();
    _refresh();
    _preloadCircles();
  }

  @override
  void didUpdateWidget(_GratitudeCheckInCard old) {
    super.didUpdateWidget(old);
    if (old.targetDate != widget.targetDate) {
      _controller.clear();
      _refresh();
    }
  }

  Future<void> _preloadCircles() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) return;
    try {
      final circles = await context.read<CircleRepository>().listCircles();
      if (mounted && circles.isNotEmpty) {
        setState(() => _userCircles = circles);
      }
    } catch (e) {
      debugPrint('[GratitudeCard] preloadCircles failed: $e');
    }
  }

  void _refresh() {
    final entry = widget.habit.entryFor(widget.targetDate);
    _isCompleted = entry?.isCompleted ?? false;
    if (_isCompleted) {
      final isPremium = context.read<StoreProvider>().isPremium;
      _verse = ScriptureLibrary.completionVerse(
          widget.habit.category, widget.targetDate,
          isPremium: isPremium);
    } else {
      _verse = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-evaluate verse when StoreProvider.isPremium changes (e.g. user buys premium).
    if (_isCompleted) {
      final isPremium = context.read<StoreProvider>().isPremium;
      _verse = ScriptureLibrary.completionVerse(
          widget.habit.category, widget.targetDate,
          isPremium: isPremium);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_isCompleted) return; // Guard: ignore taps while already completed or in-flight.
    final provider = context.read<HabitProvider>();
    final isPremium = context.read<StoreProvider>().isPremium;
    final isAuthenticated = context.read<AuthService>().isAuthenticated;
    final note = _controller.text.trim().isEmpty ? null : _controller.text.trim();
    setState(() { _showPulse = true; _isCompleted = true; _expanded = false; });
    await provider.checkInGratitude(widget.habit, note: note, date: widget.targetDate);
    if (!mounted) return;
    setState(() {
      _verse = ScriptureLibrary.completionVerse(widget.habit.category, widget.targetDate, isPremium: isPremium);
    });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _showPulse = false);
    if (!widget.isRetroactive && isAuthenticated) {
      if (_userCircles != null && _userCircles!.isNotEmpty) {
        setState(() => _showSharePrompt = true);
      } else {
        _loadCirclesForShare();
      }
    }
  }

  Future<void> _loadCirclesForShare() async {
    try {
      final circles = await context.read<CircleRepository>().listCircles();
      if (mounted && circles.isNotEmpty) {
        setState(() { _userCircles = circles; _showSharePrompt = true; });
      }
    } catch (e) {
      debugPrint('[GratitudeCard] loadCirclesForShare failed: $e');
    }
  }

  void _doShare(List<String> circleIds, bool isAnonymous) {
    final auth = context.read<AuthService>();
    final entry = widget.habit.entryFor(widget.targetDate);
    final text = (entry?.gratitudeNote?.isNotEmpty ?? false)
        ? entry!.gratitudeNote!
        : (isAnonymous ? 'gave thanks to God today' : '${auth.displayName?.split(' ').first ?? 'Someone'} gave thanks to God today');
    context.read<CircleRepository>().shareGratitude(
      circleIds: circleIds,
      gratitudeText: text,
      isAnonymous: isAnonymous,
      displayName: auth.displayName,
    ).catchError((Object e) {
      debugPrint('ShareGratitude failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't share. Check your connection."),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: GraceWayDecorations.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              GraceWayColor.golden.withValues(alpha: _isCompleted ? 0.35 : 0.12),
                              GraceWayColor.golden.withValues(alpha: _isCompleted ? 0.15 : 0.04),
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: _isCompleted ? GraceWayColor.golden : GraceWayColor.softGold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Daily Gratitude',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: GraceWayColor.warmWhite)),
                            if (_isCompleted)
                              Text('${widget.habit.totalCompletedDays()} days of gratitude',
                                  style: const TextStyle(fontSize: 11, color: GraceWayColor.sage))
                            else
                              Text(
                                widget.isRetroactive
                                    ? 'Were you grateful that day?'
                                    : 'What\u2019s one thing you\u2019re grateful for?',
                                style: TextStyle(fontSize: 11, color: GraceWayColor.softGold.withValues(alpha: 0.7)),
                              ),
                          ],
                        ),
                      ),
                      if (_isCompleted)
                        const Icon(Icons.check_circle_rounded, color: GraceWayColor.golden, size: 24)
                      else
                        Icon(Icons.expand_more, color: Colors.white.withValues(alpha: 0.3), size: 18),
                    ],
                  ),
                ),
                if (!_isCompleted && _expanded) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    maxLines: 3,
                    minLines: 2,
                    style: const TextStyle(color: GraceWayColor.warmWhite, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: widget.isRetroactive ? 'What were you grateful for?' : 'Thank God for something today...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
                      filled: true,
                      fillColor: GraceWayColor.surfaceOverlay,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _complete,
                      icon: const Icon(Icons.favorite, size: 14),
                      label: Text(_controller.text.isEmpty ? 'Thank you, Lord' : 'Give thanks'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GraceWayColor.golden,
                        foregroundColor: GraceWayColor.charcoal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                if (!_isCompleted && !_expanded) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _complete,
                      icon: const Icon(Icons.favorite, size: 14),
                      label: const Text('Thank you, Lord'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GraceWayColor.golden,
                        foregroundColor: GraceWayColor.charcoal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                if (_isCompleted && _verse != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '\u201C${_verse!.text}\u201D',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: GraceWayColor.softGold.withValues(alpha: 0.55),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Center(
                    child: Text(
                      _verse!.reference,
                      style: TextStyle(fontSize: 10, color: GraceWayColor.golden.withValues(alpha: 0.4)),
                    ),
                  ),
                  if (_showSharePrompt && _userCircles != null) ...[
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () {
                        setState(() => _showSharePrompt = false);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: GraceWayColor.charcoal,
                          builder: (_) => ShareGratitudeSheet(
                            circles: _userCircles!,
                            gratitudeText: widget.habit.entryFor(widget.targetDate)?.gratitudeNote,
                            onShare: _doShare,
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share_outlined, size: 13, color: GraceWayColor.golden.withValues(alpha: 0.55)),
                          const SizedBox(width: 5),
                          Text('Share with your circle?',
                              style: TextStyle(fontSize: 11, color: GraceWayColor.golden.withValues(alpha: 0.55))),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (_showPulse)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: GoldenPulseView(onComplete: () {
                  if (mounted) setState(() => _showPulse = false);
                }),
              ),
            ),
          ),
      ],
    );
  }
}

