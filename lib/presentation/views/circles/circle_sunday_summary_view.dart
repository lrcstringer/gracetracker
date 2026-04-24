import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/circle.dart';
import '../../../domain/repositories/circle_repository.dart';
import '../../theme/app_theme.dart';

class CircleSundaySummaryView extends StatefulWidget {
  final String circleId;
  final String circleName;

  const CircleSundaySummaryView({super.key, required this.circleId, required this.circleName});

  @override
  State<CircleSundaySummaryView> createState() => _CircleSundaySummaryViewState();
}

class _CircleSundaySummaryViewState extends State<CircleSundaySummaryView> {
  CircleWeeklySummary? _summary;
  bool _isLoading = true;
  String? _error;
  int _gratitudeWeekCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadGratitudeCount();
  }

  Future<void> _loadSummary() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final summary = await context.read<CircleRepository>().getSundaySummary(widget.circleId);
      if (mounted) setState(() { _summary = summary; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _loadGratitudeCount() async {
    try {
      final count = await context.read<CircleRepository>().getGratitudeWeekCount(widget.circleId);
      if (mounted) setState(() => _gratitudeWeekCount = count);
    } catch (_) {}
  }

  String _scoreMessage(double score) {
    if (score >= 0.9) return 'Outstanding! Your circle walked in near-perfect faithfulness this week.';
    if (score >= 0.7) return 'Strong week! Your circle showed up with consistency and dedication.';
    if (score >= 0.5) return 'Good effort! More than half the circle stayed faithful this week.';
    if (score >= 0.3) return 'A start! Every small step counts. Encourage each other.';
    return 'A quiet week. Rally together — you\'re stronger in community.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        title: const Text('Weekly Summary',
            style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 17, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Done', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: GraceWayColor.golden));
    }
    if (_summary == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.warning_amber_rounded, size: 32, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(_error ?? 'Failed to load',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _loadSummary,
            child: const Text('Retry', style: TextStyle(color: GraceWayColor.golden)),
          ),
        ]),
      );
    }
    return _summaryContent(_summary!);
  }

  Widget _summaryContent(CircleWeeklySummary s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(children: [
        const SizedBox(height: 8),
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              GraceWayColor.golden.withValues(alpha: 0.2),
              GraceWayColor.golden.withValues(alpha: 0.05),
            ]),
          ),
          child: const Icon(Icons.wb_sunny_rounded, size: 32, color: GraceWayColor.golden),
        ),
        const SizedBox(height: 12),
        Text(widget.circleName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite)),
        const SizedBox(height: 4),
        Text("This week's faithfulness",
            style: TextStyle(fontSize: 14, color: GraceWayColor.softGold.withValues(alpha: 0.7))),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: _statCard('${s.activeMembers}', 'Active', 'of ${s.totalMembers}', GraceWayColor.sage)),
          const SizedBox(width: 8),
          Expanded(child: _statCard('${(s.averageScore * 100).toInt()}%', 'Avg Score', 'this week', GraceWayColor.golden)),
          const SizedBox(width: 8),
          Expanded(child: _statCard('${s.totalMembers}', 'Members', 'total', GraceWayColor.softGold)),
        ]),
        if (s.averageScore > 0) ...[
          const SizedBox(height: 20),
          _faithfulnessBar(s.averageScore),
        ],
        if (s.topMembers.isNotEmpty) ...[
          const SizedBox(height: 20),
          _topMembersSection(s.topMembers),
        ],
        if (_gratitudeWeekCount > 0) ...[
          const SizedBox(height: 20),
          _gratitudeCountCard(),
        ],
        const SizedBox(height: 28),
        Text(
          '\u201CTherefore encourage one another and build one another up, just as you are doing.\u201D',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic,
              color: GraceWayColor.softGold.withValues(alpha: 0.6), height: 1.6),
        ),
        const SizedBox(height: 6),
        Text('1 Thessalonians 5:11',
            style: TextStyle(fontSize: 11, color: GraceWayColor.golden.withValues(alpha: 0.5))),
      ]),
    );
  }

  Widget _statCard(String value, String label, String sublabel, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: GraceWayColor.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GraceWayColor.cardBorder, width: 0.5),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
        Text(sublabel, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4))),
      ]),
    );
  }

  Widget _faithfulnessBar(double score) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GraceWayColor.golden.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.1), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.bar_chart_rounded, size: 14, color: GraceWayColor.golden),
          const SizedBox(width: 6),
          const Text('Circle Faithfulness',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GraceWayColor.golden)),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (_, constraints) {
          return Stack(children: [
            Container(
              height: 12,
              decoration: BoxDecoration(
                  color: GraceWayColor.cardBackground, borderRadius: BorderRadius.circular(6)),
            ),
            Container(
              height: 12,
              width: constraints.maxWidth * score.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [GraceWayColor.golden.withValues(alpha: 0.8), GraceWayColor.golden],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ]);
        }),
        const SizedBox(height: 8),
        Text(_scoreMessage(score),
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
      ]),
    );
  }

  Widget _topMembersSection(List<CircleWeeklyTopMember> streaks) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GraceWayColor.warmCoral.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GraceWayColor.warmCoral.withValues(alpha: 0.1), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.local_fire_department, size: 14, color: GraceWayColor.warmCoral),
          SizedBox(width: 6),
          Text('Top Streaks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GraceWayColor.warmCoral)),
        ]),
        const SizedBox(height: 12),
        ...streaks.take(5).toList().asMap().entries.map((e) {
          final i = e.key;
          final streak = e.value;
          final isFirst = i == 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(
                width: 20,
                child: Text('${i + 1}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: isFirst ? GraceWayColor.golden : Colors.white.withValues(alpha: 0.4))),
              ),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst
                        ? GraceWayColor.golden.withValues(alpha: 0.12)
                        : GraceWayColor.sage.withValues(alpha: 0.1)),
                child: Icon(Icons.person_rounded, size: 12,
                    color: isFirst ? GraceWayColor.golden : GraceWayColor.sage),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Member', style: TextStyle(fontSize: 14, color: GraceWayColor.warmWhite)),
              ),
              Row(children: [
                const Icon(Icons.local_fire_department, size: 11, color: GraceWayColor.warmCoral),
                const SizedBox(width: 4),
                Text('${streak.streak} days',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: GraceWayColor.warmCoral)),
              ]),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _gratitudeCountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GraceWayColor.golden.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.1), width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: GraceWayColor.golden.withValues(alpha: 0.12)),
          child: const Icon(Icons.favorite_rounded, size: 16, color: GraceWayColor.golden),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Shared Gratitudes',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
          Text(
            '$_gratitudeWeekCount gratitude${_gratitudeWeekCount == 1 ? '' : 's'} shared this week',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
          ),
        ])),
        Text('$_gratitudeWeekCount',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: GraceWayColor.golden)),
      ]),
    );
  }
}
