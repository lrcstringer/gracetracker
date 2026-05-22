import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../providers/store_provider.dart';
import '../../providers/weekly_pulse_provider.dart';
import '../../../domain/repositories/circle_repository.dart';
import '../../../domain/entities/circle.dart';
import '../../theme/app_theme.dart';
import 'circle_sunday_summary_view.dart';
import 'gratitude_wall_view.dart' show GratitudeWallWidget;
import 'circle_settings_view.dart';
import 'package:share_plus/share_plus.dart';
import 'announcement_compose_view.dart';
import 'prayer_request_compose_view.dart';
import 'prayer_list_view.dart';

class CircleDetailView extends StatefulWidget {
  final String circleId;
  const CircleDetailView({super.key, required this.circleId});

  @override
  State<CircleDetailView> createState() => _CircleDetailViewState();
}

class _CircleDetailViewState extends State<CircleDetailView> {
  CircleDetails? _detail;
  bool _isLoading = true;
  String? _error;
  bool _wasOffline = false;
  CircleHeatmap? _heatmap;
  bool _heatmapFailed = false;
  CollectiveMilestones? _milestones;
  bool _milestonesFailed = false;
  List<PrayerRequest>? _prayerRequests;
  bool _prayerRequestsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadHeatmap();
    _loadMilestones();
    _loadPrayerRequests();
    _loadProviders();
  }

  void _loadProviders() {
    final uid = AuthService.shared.userId ?? '';
    context.read<WeeklyPulseProvider>().load(widget.circleId, uid);
  }

  Future<bool> _isOffline() async {
    final r = await Connectivity().checkConnectivity();
    return r.every((c) => c == ConnectivityResult.none);
  }

  Future<void> _loadDetail() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final detail = await context.read<CircleRepository>().getCircleDetail(widget.circleId);
      if (mounted) setState(() { _detail = detail; _isLoading = false; });
    } catch (e) {
      final offline = await _isOffline();
      if (mounted) {
        setState(() {
          _wasOffline = offline;
          _error = offline
              ? 'No internet connection. Connect to load circle data.'
              : e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadHeatmap() async {
    final isPremium = context.read<StoreProvider>().isPremium;
    try {
      final heatmap = await context.read<CircleRepository>().getCircleHeatmap(
        widget.circleId, weekCount: isPremium ? 52 : 1);
      if (mounted) setState(() => _heatmap = heatmap);
    } catch (_) {
      if (mounted) setState(() => _heatmapFailed = true);
    }
  }

  Future<void> _loadMilestones() async {
    try {
      final milestones = await context.read<CircleRepository>().getCircleMilestones(widget.circleId);
      if (mounted) setState(() => _milestones = milestones);
    } catch (_) {
      if (mounted) setState(() => _milestonesFailed = true);
    }
  }

  Future<void> _loadPrayerRequests() async {
    try {
      final requests = await context.read<CircleRepository>().getPrayerRequests(widget.circleId);
      if (mounted) setState(() => _prayerRequests = requests);
    } catch (_) {
      if (mounted) setState(() => _prayerRequestsFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      bottomNavigationBar: _detail != null ? _inviteBar(_detail!) : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: GraceWayColor.golden));
    }
    if (_detail == null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            _wasOffline ? Icons.wifi_off_rounded : Icons.warning_amber_rounded,
            size: 32, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_error ?? 'Failed to load',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: _loadDetail,
              child: const Text('Retry', style: TextStyle(color: GraceWayColor.golden))),
        ]),
      );
    }
    return _buildContent(_detail!);
  }

  Widget _buildContent(CircleDetails detail) {
    return SafeArea(
      top: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: GraceWayColor.charcoal,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(detail.name,
                  style: const TextStyle(color: GraceWayColor.warmWhite, fontSize: 18, fontWeight: FontWeight.w700)),
              Text('${detail.memberCount} members',
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
            ]),
            actions: [
              if (detail.members.any((m) => m.userId == AuthService.shared.userId && m.isAdmin))
                IconButton(
                  icon: const Icon(Icons.campaign_rounded, size: 20, color: GraceWayColor.softGold),
                  tooltip: 'Announce',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AnnouncementComposeView(
                        circleId: widget.circleId,
                        circleName: detail.name,
                      ),
                    ),
                  ),
                ),
              if (detail.members.any((m) => m.userId == AuthService.shared.userId && m.isAdmin))
                IconButton(
                  icon: const Icon(Icons.settings_rounded, size: 20, color: GraceWayColor.softGold),
                  onPressed: () => _openSettings(detail),
                ),
            ],
            pinned: true,
          ),
        ],
        body: _OverviewTab(
          circleId: widget.circleId,
          detail: detail,
          heatmap: _heatmap,
          heatmapFailed: _heatmapFailed,
          milestones: _milestones,
          milestonesFailed: _milestonesFailed,
          prayerRequests: _prayerRequests,
          prayerRequestsFailed: _prayerRequestsFailed,
          onSummaryTap: () => _showSundaySummary(detail),
          onPrayerRequestTap: () => _openPrayerRequest(detail),
          onSeeAllPrayerRequests: () => _openPrayerList(detail),
        ),
      ),
    );
  }

  void _showSundaySummary(CircleDetails detail) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: GraceWayColor.charcoal,
      builder: (_) => CircleSundaySummaryView(circleId: widget.circleId, circleName: detail.name),
    );
  }

  void _openSettings(CircleDetails detail) async {
    final result = await Navigator.push<Object?>(context, MaterialPageRoute(
      builder: (_) => CircleSettingsView(
        circleId: widget.circleId,
        circleName: detail.name,
        circleDescription: detail.description,
        inviteCode: detail.inviteCode,
        members: detail.members,
        currentUserId: AuthService.shared.userId ?? '',
      ),
    ));
    if (!mounted) return;
    if (result == 'deleted' || result == 'left') {
      Navigator.pop(context);
    } else {
      _loadDetail();
    }
  }

  void _openPrayerRequest(CircleDetails detail) {
    final currentUid = AuthService.shared.userId ?? '';
    final otherMembers =
        detail.members.where((m) => m.userId != currentUid).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrayerRequestComposeView(
          circleId: widget.circleId,
          circleName: detail.name,
          otherMembers: otherMembers,
        ),
      ),
    ).then((_) => _loadPrayerRequests());
  }

  void _openPrayerList(CircleDetails detail) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrayerListView(
          circleId: widget.circleId,
          circleName: detail.name,
        ),
      ),
    ).then((_) => _loadPrayerRequests());
  }

  Widget _inviteBar(CircleDetails detail) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: GraceWayColor.charcoal,
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 0.5)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _shareInvite(detail),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text('Invite Friends to Join',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: GraceWayColor.golden,
              foregroundColor: GraceWayColor.charcoal,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }

  void _shareInvite(CircleDetails detail) {
    final text = 'Join my Prayer Circle "${detail.name}" on Grace Tracker!\n\n'
        'Your invite code: ${detail.inviteCode}\n\n'
        'Already have the app? Go to Circles → Join with Invite Code → enter ${detail.inviteCode}\n\n'
        "Don't have the app yet?\n"
        'Android: https://play.google.com/store/apps/details?id=com.gracetracker.com\n'
        'iPhone: https://apps.apple.com/app/grace-tracker/id[APP_STORE_ID]';
    Share.share(text);
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final String circleId;
  final CircleDetails detail;
  final CircleHeatmap? heatmap;
  final bool heatmapFailed;
  final CollectiveMilestones? milestones;
  final bool milestonesFailed;
  final List<PrayerRequest>? prayerRequests;
  final bool prayerRequestsFailed;
  final VoidCallback onSummaryTap;
  final VoidCallback onPrayerRequestTap;
  final VoidCallback onSeeAllPrayerRequests;
  const _OverviewTab({
    required this.circleId,
    required this.detail,
    required this.heatmap,
    required this.heatmapFailed,
    required this.milestones,
    required this.milestonesFailed,
    required this.prayerRequests,
    required this.prayerRequestsFailed,
    required this.onSummaryTap,
    required this.onPrayerRequestTap,
    required this.onSeeAllPrayerRequests,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<StoreProvider>().isPremium;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        _collaborativeHeatmapSection(isPremium),
        const SizedBox(height: 16),
        _collectiveMilestonesSection(context),
        const SizedBox(height: 16),
        GratitudeWallWidget(circleId: circleId),
        const SizedBox(height: 16),
        _sectionHeader('Actions'),
        const SizedBox(height: 8),
        _actionRow(
          icon: Icons.wb_sunny_rounded, iconColor: GraceWayColor.golden,
          iconBg: GraceWayColor.golden.withValues(alpha: 0.12),
          title: 'Weekly Summary', subtitle: "See your circle's faithfulness this week",
          onTap: onSummaryTap,
        ),
        const SizedBox(height: 8),
        _actionRow(
          icon: Icons.volunteer_activism_rounded, iconColor: GraceWayColor.sage,
          iconBg: GraceWayColor.sage.withValues(alpha: 0.12),
          title: 'Prayer Request', subtitle: 'Ask circle members to pray for you',
          onTap: onPrayerRequestTap,
        ),
        const SizedBox(height: 16),
        _prayerRequestsSection(),
        const SizedBox(height: 16),
        _sectionHeader('Members (${detail.members.length})'),
        const SizedBox(height: 8),
        ...detail.members.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _memberRow(context, m),
        )),
      ],
    );
  }

  Widget _collaborativeHeatmapSection(bool isPremium) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GraceWayDecorations.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.grid_view_rounded, size: 13, color: GraceWayColor.golden),
          const SizedBox(width: 6),
          Text('Circle Activity',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
          const Spacer(),
          Text('${detail.memberCount} members',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
        ]),
        const SizedBox(height: 6),
        Text(
          'When members have a strong day, this glows. The more the circle gives, the brighter it gets.',
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45), height: 1.4),
        ),
        const SizedBox(height: 12),
        if (heatmapFailed)
          Text('Could not load activity data.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35)))
        else if (heatmap == null)
          const SizedBox(height: 32,
            child: Center(child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: GraceWayColor.golden))))
        else
          _CircleHeatmapGrid(heatmap: heatmap!, isPremium: isPremium),
        if (!isPremium) ...[
          const SizedBox(height: 8),
          Text('Upgrade to see your full 52-week circle history.',
              style: TextStyle(fontSize: 11, color: GraceWayColor.golden.withValues(alpha: 0.5))),
        ],
      ]),
    );
  }

  Widget _collectiveMilestonesSection(BuildContext context) {
    final ms = milestones;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GraceWayDecorations.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.star_rounded, size: 13, color: GraceWayColor.golden),
          const SizedBox(width: 6),
          Text('Circle Milestones',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
        ]),
        const SizedBox(height: 10),
        if (milestonesFailed)
          Text('Could not load milestones.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35)))
        else if (ms == null)
          const SizedBox(height: 32,
            child: Center(child: SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: GraceWayColor.golden))))
        else ...[
          if (ms.totalGivingDays > 0 || ms.totalHours > 0 || ms.totalGratitudeDays > 0)
            _milestoneTotalsRow(ms),
          const SizedBox(height: 10),
          if (ms.milestones.isEmpty)
            Text('Keep going — your first circle milestone is on its way.',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), height: 1.4))
          else
            ...ms.milestones.take(3).map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _milestoneTile(m),
            )),
        ],
      ]),
    );
  }

  Widget _milestoneTotalsRow(CollectiveMilestones ms) {
    final items = <_TotalItem>[];
    if (ms.totalGivingDays > 0) items.add(_TotalItem('${ms.totalGivingDays}', 'giving days'));
    if (ms.totalHours >= 1) {
      final h = ms.totalHours.floor();
      items.add(_TotalItem('$h', h == 1 ? 'hour' : 'hours'));
    }
    if (ms.totalGratitudeDays > 0) items.add(_TotalItem('${ms.totalGratitudeDays}', 'gratitude days'));
    return Row(
      children: items.map((item) => Expanded(
        child: Column(children: [
          Text(item.value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: GraceWayColor.golden)),
          Text(item.label,
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.45))),
        ]),
      )).toList(),
    );
  }

  Widget _milestoneTile(CollectiveMilestone m) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: GraceWayColor.golden.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.18), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.star_rounded, size: 16, color: GraceWayColor.golden),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
          const SizedBox(height: 2),
          Text(m.message,
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5), height: 1.4)),
        ])),
      ]),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.2));
  }

  Widget _actionRow({
    required IconData icon, required Color iconColor, required Color iconBg,
    required String title, required String subtitle, required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withValues(alpha: 0.12), width: 0.5),
        ),
        child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
            child: Icon(icon, size: 18, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
          ])),
          Icon(Icons.chevron_right, size: 14, color: Colors.white.withValues(alpha: 0.3)),
        ]),
      ),
    );
  }

  Widget _prayerRequestsSection() {
    final requests = prayerRequests;
    final active = requests
            ?.where((r) => r.status == PrayerRequestStatus.active)
            .take(3)
            .toList() ??
        [];
    final total = requests
            ?.where((r) => r.status == PrayerRequestStatus.active)
            .length ??
        0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GraceWayDecorations.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.volunteer_activism_rounded,
              size: 13, color: GraceWayColor.sage),
          const SizedBox(width: 6),
          Text('Prayer Requests',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: GraceWayColor.sage)),
          const Spacer(),
          if (total > 0)
            GestureDetector(
              onTap: onSeeAllPrayerRequests,
              child: Text(
                'See all ($total)',
                style: TextStyle(
                    fontSize: 12,
                    color: GraceWayColor.sage.withValues(alpha: 0.7)),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        if (prayerRequestsFailed)
          Text('Could not load prayer requests.',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withValues(alpha: 0.35)))
        else if (requests == null)
          const SizedBox(
            height: 24,
            child: Center(
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: GraceWayColor.sage)),
            ),
          )
        else if (active.isEmpty)
          Text(
            'No active prayer requests. Tap "Prayer Request" above to share one.',
            style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.4),
                height: 1.4),
          )
        else
          ...active.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _prayerRequestTile(r),
              )),
      ]),
    );
  }

  Widget _prayerRequestTile(PrayerRequest r) {
    return GestureDetector(
      onTap: onSeeAllPrayerRequests,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.07), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.volunteer_activism_rounded,
                  size: 13, color: GraceWayColor.sage.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.authorDisplayName,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: GraceWayColor.warmWhite),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.requestText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.4),
                    ),
                  ]),
            ),
            const SizedBox(width: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline_rounded,
                  size: 11, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 3),
              Text('${r.prayerCount}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.3))),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _memberRow(BuildContext context, CircleMember m) {
    final currentUid = AuthService.shared.userId ?? '';
    final isSelf = m.userId == currentUid;
    final isAdmin = m.isAdmin;
    final color = isAdmin ? GraceWayColor.golden : GraceWayColor.sage;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: GraceWayDecorations.card,
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.12)),
          child: Icon(Icons.person_rounded, size: 14, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isSelf ? 'You' : m.displayName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: GraceWayColor.warmWhite)),
          Text(isAdmin ? 'Admin' : 'Member',
              style: TextStyle(fontSize: 11,
                  color: isAdmin ? GraceWayColor.golden : Colors.white.withValues(alpha: 0.4))),
        ])),
      ]),
    );
  }

}

// ─── Supporting types ─────────────────────────────────────────────────────────

class _TotalItem {
  final String value;
  final String label;
  const _TotalItem(this.value, this.label);
}

// ─── Collaborative heatmap grid ───────────────────────────────────────────────

class _CircleHeatmapGrid extends StatelessWidget {
  final CircleHeatmap heatmap;
  final bool isPremium;

  const _CircleHeatmapGrid({required this.heatmap, required this.isPremium});

  static const _tileSize = 10.0;
  static const _gap = 2.0;
  static const _stride = _tileSize + _gap;
  static const _dayLabelWidth = 14.0;
  static const _monthRowHeight = 13.0;
  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const _monthAbbrs = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  Map<String, double> _intensityMap() => {for (final d in heatmap.days) d.date: d.intensity};

  List<List<DateTime>> _buildWeeks() {
    final weekCount = isPremium ? 52 : 1;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final daysSinceSunday = today.weekday % 7;
    final currentWeekStart = todayStart.subtract(Duration(days: daysSinceSunday));
    return List.generate(weekCount, (i) {
      final weekStart = currentWeekStart.add(Duration(days: (i - (weekCount - 1)) * 7));
      return List.generate(7, (d) => weekStart.add(Duration(days: d)));
    });
  }

  Color _cellColor(double intensity) {
    if (intensity <= 0.0) return GraceWayColor.surfaceOverlay;
    if (intensity <= 0.25) return GraceWayColor.golden.withValues(alpha: 0.15);
    if (intensity <= 0.65) return GraceWayColor.golden.withValues(alpha: 0.50);
    return GraceWayColor.golden.withValues(alpha: 0.85);
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _buildWeeks();
    final map = _intensityMap();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    if (weeks.length == 1) {
      return Row(
        children: weeks.first.map((date) {
          final isFuture = date.isAfter(todayStart);
          final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          final intensity = isFuture ? 0.0 : (map[key] ?? 0.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: isFuture ? Colors.white.withValues(alpha: 0.02) : _cellColor(intensity),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _monthRowHeight + 1),
          child: Column(
            children: List.generate(7, (i) => SizedBox(
              width: _dayLabelWidth, height: _stride,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_dayLabels[i],
                    style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.35))),
              ),
            )),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: _monthRowHeight,
                  child: Row(
                    children: List.generate(weeks.length, (i) {
                      final sunday = weeks[i].first;
                      final showMonth = i == 0 || sunday.month != weeks[i - 1].first.month;
                      return SizedBox(
                        width: _stride,
                        child: showMonth
                            ? Text(_monthAbbrs[sunday.month - 1],
                                style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.4)))
                            : null,
                      );
                    }),
                  ),
                ),
                ...List.generate(7, (dayIndex) => Row(
                  children: weeks.map((week) {
                    final date = week[dayIndex];
                    final isFuture = date.isAfter(todayStart);
                    final key = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    final intensity = isFuture ? 0.0 : (map[key] ?? 0.0);
                    return Padding(
                      padding: const EdgeInsets.only(right: _gap, bottom: _gap),
                      child: Container(
                        width: _tileSize, height: _tileSize,
                        decoration: BoxDecoration(
                          color: isFuture ? Colors.white.withValues(alpha: 0.02) : _cellColor(intensity),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: !isFuture && intensity > 0.65
                              ? [BoxShadow(color: GraceWayColor.golden.withValues(alpha: 0.35), blurRadius: 3)]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
