import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../domain/entities/habit.dart';
import '../../theme/app_theme.dart';

class DedicationCeremonyScreen extends StatefulWidget {
  final String? gratitudeNote;
  final String habitName;
  final HabitCategory habitCategory;
  final String purposeStatement;
  final HabitTrackingType trackingType;
  final double dailyTarget;
  final String targetUnit;
  final VoidCallback onComplete;
  final String? givenName;

  const DedicationCeremonyScreen({
    super.key,
    required this.gratitudeNote,
    required this.habitName,
    required this.habitCategory,
    this.purposeStatement = '',
    this.trackingType = HabitTrackingType.checkIn,
    this.dailyTarget = 1,
    this.targetUnit = '',
    required this.onComplete,
    this.givenName,
  });

  @override
  State<DedicationCeremonyScreen> createState() => _DedicationCeremonyScreenState();
}

class _DedicationCeremonyScreenState extends State<DedicationCeremonyScreen>
    with SingleTickerProviderStateMixin {
  bool _showVerse = false;
  bool _showGratitudeTile = false;
  bool _showHabitTile = false;
  bool _showButton = false;
  bool _isDedicated = false;
  bool _showPulse = false;
  bool _showFinalMessage = false;
  bool _tilesGlow = false;
  double _glowOpacity = 0.08;
  late final AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showVerse = true);
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showGratitudeTile = true);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showHabitTile = true);
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showButton = true);
    });
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  void _performDedication() {
    HapticFeedback.mediumImpact();
    setState(() {
      _tilesGlow = true;
      _glowOpacity = 0.25;
      _showPulse = true;
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isDedicated = true;
        _showButton = false;
        _glowOpacity = 0.12;
      });
    });

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _showFinalMessage = true);
    });

    Future.delayed(const Duration(milliseconds: 3100), () {
      if (!mounted) return;
      setState(() => _showPulse = false);
    });
  }

  Color get _accentColor =>
      widget.habitCategory == HabitCategory.abstain ? GraceWayColor.warmCoral : GraceWayColor.golden;

  IconData _categoryIcon() {
    switch (widget.habitCategory) {
      case HabitCategory.exercise: return Icons.fitness_center;
      case HabitCategory.scripture: return Icons.menu_book;
      case HabitCategory.rest: return Icons.bedtime;
      case HabitCategory.fasting: return Icons.no_food;
      case HabitCategory.study: return Icons.school;
      case HabitCategory.service: return Icons.volunteer_activism;
      case HabitCategory.connection: return Icons.people;
      case HabitCategory.health: return Icons.favorite;
      case HabitCategory.abstain: return Icons.shield_rounded;
      case HabitCategory.prayer: return Icons.self_improvement_rounded;
      default: return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breatheController,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 1500),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    GraceWayColor.golden.withValues(alpha: _glowOpacity),
                    GraceWayColor.softGold.withValues(alpha: _glowOpacity * 0.4),
                    Colors.transparent,
                  ],
                  radius: 1.5,
                ),
              ),
            ),
            Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(children: [
                    if (!_isDedicated) _preOfferingContent() else _postOfferingContent(),
                  ]),
                ),
              ),
              if (!_isDedicated && _showButton)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _performDedication,
                      icon: const Icon(Icons.volunteer_activism, size: 16),
                      label: const Text('Begin My Walk',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GraceWayColor.golden,
                        foregroundColor: GraceWayColor.charcoal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              if (_isDedicated && _showFinalMessage)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onComplete,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Enter GraceWay',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GraceWayColor.golden,
                        foregroundColor: GraceWayColor.charcoal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
            ]),
          ],
        );
      },
    );
  }

  Widget _preOfferingContent() {
    return Column(children: [
      AnimatedOpacity(
        opacity: _showVerse ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        child: Column(children: [
          const Text('Your Walk',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite)),
          const SizedBox(height: 8),
          Text('Everything you\u2019ve chosen \u2014 offered to God.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5))),
        ]),
      ),
      const SizedBox(height: 24),
      _habitTile(
        icon: Icons.volunteer_activism,
        name: 'Daily Gratitude',
        detail: HabitCategory.gratitude.defaultPurpose,
        accent: GraceWayColor.golden,
        isShowing: _showGratitudeTile,
        isGlowing: _tilesGlow,
      ),
      const SizedBox(height: 14),
      _habitTile(
        icon: _categoryIcon(),
        name: widget.habitName,
        detail: widget.purposeStatement.isNotEmpty
            ? widget.purposeStatement
            : widget.habitCategory.defaultPurpose,
        accent: _accentColor,
        isShowing: _showHabitTile,
        isGlowing: _tilesGlow,
      ),
      const SizedBox(height: 16),
      AnimatedOpacity(
        opacity: _showHabitTile ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: _microMilestoneSection(),
      ),
      const SizedBox(height: 16),
      AnimatedOpacity(
        opacity: _showVerse ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        child: Column(children: [
          Text(
            '\u201CTherefore, I urge you, brothers and sisters, in view of God\u2019s mercy, to offer your bodies as a living sacrifice, holy and pleasing to God \u2014 this is your true and proper worship.\u201D',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14, fontStyle: FontStyle.italic, height: 1.6,
              color: GraceWayColor.softGold.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text('Romans 12:1',
              style: TextStyle(fontSize: 12, color: GraceWayColor.golden.withValues(alpha: 0.5))),
          if (DateTime.now().weekday != 7) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GraceWayColor.golden.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.15), width: 0.5),
              ),
              child: Text(
                'Starting mid-week? No problem. Your first full Sunday cycle begins this coming Sunday.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.5),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }

  Widget _postOfferingContent() {
    final b = _breatheController.value;
    return Column(children: [
      const SizedBox(height: 40),
      Stack(alignment: Alignment.center, children: [
        if (_showPulse) _pulseView(),
        AnimatedOpacity(
          opacity: _showFinalMessage ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 600),
          child: AnimatedScale(
            scale: _showFinalMessage ? 1.0 : 0.92,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            child: Column(children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    GraceWayColor.golden.withValues(alpha: 0.4),
                    GraceWayColor.golden.withValues(alpha: 0.1),
                  ]),
                ),
                child: Transform.scale(
                  scale: 1.0 + b * 0.08,
                  child: const Icon(Icons.volunteer_activism, size: 38, color: GraceWayColor.golden),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Your walk is set.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite)),
              const SizedBox(height: 8),
              Text(
                  widget.givenName != null
                      ? 'Remain steadfast in all you do, ${widget.givenName}.'
                      : 'Remain steadfast in all you do.',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 32),
      AnimatedOpacity(
        opacity: _showFinalMessage ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        child: Column(children: [
          Text(
            '\u201CThe steadfast love of the Lord never ceases; his mercies never come to an end; they are new every morning.\u201D',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14, fontStyle: FontStyle.italic, height: 1.6,
              color: GraceWayColor.softGold.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text('Lamentations 3:22\u201323',
              style: TextStyle(fontSize: 12, color: GraceWayColor.golden.withValues(alpha: 0.4))),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GraceWayColor.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GraceWayColor.cardBorder, width: 0.5),
            ),
            child: Column(children: [
              const Icon(Icons.groups_rounded, size: 28, color: GraceWayColor.golden),
              const SizedBox(height: 10),
              const Text('Want to walk with others?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
              const SizedBox(height: 4),
              Text('Circles let you share your walk, pray together, and study scripture as a community.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _microMilestoneSection() {
    final weekday = DateTime.now().weekday;
    final daysLeft = weekday == 7 ? 6 : (6 - weekday + 1);
    if (daysLeft <= 0) return const SizedBox.shrink();

    final gratitudeLine = '$daysLeft day${daysLeft == 1 ? '' : 's'} of gratitude';

    final String customLine;
    switch (widget.trackingType) {
      case HabitTrackingType.timed:
        final mins = (widget.dailyTarget * daysLeft).toInt();
        final unit = widget.targetUnit.isNotEmpty ? widget.targetUnit : 'minutes';
        customLine = '$mins $unit of ${widget.habitName.toLowerCase()}';
      case HabitTrackingType.count:
        final count = (widget.dailyTarget * daysLeft).toInt();
        final unit = widget.targetUnit.isNotEmpty ? widget.targetUnit : 'completed';
        customLine = '$count $unit of ${widget.habitName.toLowerCase()}';
      case HabitTrackingType.checkIn:
        customLine = '$daysLeft day${daysLeft == 1 ? '' : 's'} of ${widget.habitName.toLowerCase()}';
      case HabitTrackingType.abstain:
        customLine = '$daysLeft clean day${daysLeft == 1 ? '' : 's'}';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GraceWayColor.golden.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.12), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('If you hit your targets this week:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
          const SizedBox(height: 10),
          _milestoneLine(gratitudeLine),
          if (widget.habitName.isNotEmpty) _milestoneLine(customLine),
        ],
      ),
    );
  }

  Widget _milestoneLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.auto_awesome, size: 11, color: GraceWayColor.golden),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6), height: 1.4)),
        ),
      ]),
    );
  }

  Widget _habitTile({
    required IconData icon,
    required String name,
    required String detail,
    required Color accent,
    required bool isShowing,
    required bool isGlowing,
  }) {
    return AnimatedOpacity(
      opacity: isShowing ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: AnimatedSlide(
        offset: isShowing ? Offset.zero : const Offset(0, 0.2),
        duration: const Duration(milliseconds: 400),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isGlowing ? accent.withValues(alpha: 0.08) : GraceWayColor.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isGlowing ? accent.withValues(alpha: 0.3) : GraceWayColor.cardBorder,
              width: 0.5,
            ),
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  accent.withValues(alpha: isGlowing ? 0.5 : 0.2),
                  accent.withValues(alpha: isGlowing ? 0.2 : 0.06),
                ]),
              ),
              child: Icon(icon, size: 22, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
                const SizedBox(height: 4),
                Text(detail,
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
              ]),
            ),
            Icon(
              isGlowing ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 22,
              color: isGlowing ? GraceWayColor.golden : Colors.white.withValues(alpha: 0.15),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _pulseView() {
    return SizedBox(
      width: 200, height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(4, (i) => _PulseRing(delay: i * 200)),
      ),
    );
  }
}

class _PulseRing extends StatefulWidget {
  final int delay;
  const _PulseRing({required this.delay});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _scale = Tween<double>(begin: 0.2, end: 3.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Transform.scale(
        scale: _scale.value,
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                GraceWayColor.golden.withValues(alpha: 0.4),
                GraceWayColor.softGold.withValues(alpha: 0.15),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
