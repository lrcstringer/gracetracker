import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/entities/circle.dart';
import '../../../domain/repositories/circle_repository.dart';
import '../../../domain/repositories/user_preferences_repository.dart';
import '../../providers/habit_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/bible_reading_provider.dart';
import '../../providers/store_provider.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../domain/services/milestone_service.dart';
import '../../../data/datasources/local/notification_service.dart';
import '../../../domain/entities/accountability_partnership.dart';
import '../../providers/accountability_provider.dart';
import '../../theme/app_theme.dart';
import '../shared/graceway_paywall_view.dart';
import 'profile_edit_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  static const _milestoneService = MilestoneService.instance;

  bool _remindersEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  bool _notifDenied = false;
  List<Habit> _archivedHabits = [];

  // Circle notification preferences
  bool _circleNotifPrayer = true;
  bool _circleNotifAnnouncement = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkNotifStatus();
    _loadArchivedHabits();
    _loadCircleNotifPrefs();
  }

  Future<void> _loadArchivedHabits() async {
    final habits = await context.read<HabitProvider>().loadArchivedHabits();
    if (mounted) setState(() => _archivedHabits = habits);
  }

  Future<void> _loadPrefs() async {
    final prefs = context.read<UserPreferencesRepository>();
    final enabled = await prefs.getBool('tribute_reminders_enabled') ?? false;
    final hour = await prefs.getInt('tribute_reminder_hour') ?? 8;
    final minute = await prefs.getInt('tribute_reminder_minute') ?? 0;
    if (mounted) {
      setState(() {
        _remindersEnabled = enabled;
        _reminderTime = TimeOfDay(hour: hour, minute: minute);
      });
    }
  }

  Future<void> _checkNotifStatus() async {
    await NotificationService.shared.checkAuthorization();
    final authorized = NotificationService.shared.isAuthorized;
    if (mounted) setState(() => _notifDenied = !authorized);
  }

  Future<void> _loadCircleNotifPrefs() async {
    final prefs = context.read<UserPreferencesRepository>();
    final prayer = await prefs.getBool('circle_notif_prayer') ?? true;
    final announcement = await prefs.getBool('circle_notif_announcement') ?? true;
    if (mounted) {
      setState(() {
        _circleNotifPrayer = prayer;
        _circleNotifAnnouncement = announcement;
      });
    }
  }

  Future<void> _saveCircleNotifPref(String key, bool value) async {
    final prefs = context.read<UserPreferencesRepository>();
    await prefs.setBool(key, value);
  }

  Future<void> _savePrefs() async {
    final prefs = context.read<UserPreferencesRepository>();
    await prefs.setBool('tribute_reminders_enabled', _remindersEnabled);
    await prefs.setInt('tribute_reminder_hour', _reminderTime.hour);
    await prefs.setInt('tribute_reminder_minute', _reminderTime.minute);
    if (_remindersEnabled) {
      await NotificationService.shared.scheduleDailyReminders();
    } else {
      await NotificationService.shared.cancelDailyReminders();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked != null) {
      setState(() => _reminderTime = picked);
      _savePrefs();
    }
  }

  // Identity/auth keys that survive a data reset (set by AuthService, not
  // user-generated data).
  static const _identityPrefsKeys = {
    'tribute_display_name',
    'tribute_given_name',
    'tribute_surname',
    'tribute_email',
    'tribute_phone',
    'tribute_photo_url',
  };

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GraceWayColor.cardBackground,
        title: const Text('Reset All Data', style: TextStyle(color: GraceWayColor.warmWhite)),
        content: Text(
          'This will permanently delete all your habits, journal entries, and circle memberships. This cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetAllData();
            },
            child: const Text('Reset Everything', style: TextStyle(color: GraceWayColor.warmCoral)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetAllData() async {
    final habitProvider = context.read<HabitProvider>();
    final prefs = context.read<UserPreferencesRepository>();
    final accountability = context.read<AccountabilityProvider>();
    final journal = context.read<JournalProvider>();
    final circles = context.read<CircleRepository>();

    // 1. End all active/pending accountability partnerships.
    final partnerHabitIds = accountability.partnerships
        .where((p) =>
            p.status == PartnershipStatus.active ||
            p.status == PartnershipStatus.pending)
        .map((p) => p.habitId)
        .toSet();
    await Future.wait([
      for (final hId in partnerHabitIds)
        accountability
            .endPartnershipsForHabit(hId, reason: 'deleted')
            .catchError((_) {}),
    ]);

    // 2. Leave all circles the user belongs to.
    List<Circle> userCircles = const [];
    try {
      userCircles = await circles.listCircles();
    } catch (_) {}
    await Future.wait([
      for (final c in userCircles)
        circles.leaveCircle(c.id).catchError((_) {}),
    ]);

    // 3. Delete all user-generated content in parallel.
    await Future.wait([
      habitProvider.resetAllData(),
      journal.deleteAllEntries(),
    ]);

    // 4. Wipe all preferences, preserving identity/auth keys.
    await prefs.clearAll(preserve: _identityPrefsKeys);

    if (mounted) setState(() => _remindersEnabled = false);
    await NotificationService.shared.cancelDailyReminders();
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: GraceWayColor.cardBackground,
          title: const Text('Data Reset', style: TextStyle(color: GraceWayColor.warmWhite)),
          content: Text(
            'All your data has been cleared — habits, journal entries, and circles. Your account and subscription are unchanged.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: GraceWayColor.golden)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final habits = context.watch<HabitProvider>().sortedHabits;
    final store = context.watch<StoreProvider>();
    final auth = context.watch<AuthService>();

    final totalCheckIns = habits.fold<int>(0, (s, h) => s + h.totalCompletedDays());
    final totalMinutes = habits
        .where((h) => h.trackingType == HabitTrackingType.timed)
        .fold<double>(0, (s, h) => s + h.totalValue());
    final totalCleanDays = habits
        .where((h) => h.trackingType == HabitTrackingType.abstain)
        .fold<int>(0, (s, h) => s + h.totalCompletedDays());
    final totalCount = habits
        .where((h) => h.trackingType == HabitTrackingType.count)
        .fold<double>(0, (s, h) => s + h.totalValue());
    final milestoneCount = habits
        .expand((h) => _milestoneService.milestones(h).where((m) => m.isReached))
        .length;

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: GraceWayColor.charcoal,
            title: const Text('Settings',
                style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 22, fontWeight: FontWeight.w700)),
            floating: true, snap: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Brand header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: GraceWayDecorations.card,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('GraceWay',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: GraceWayColor.golden)),
                    Text('Track your habits. Give them to God.',
                        style: TextStyle(fontSize: 14, color: GraceWayColor.softGold.withValues(alpha: 0.7))),
                  ]),
                ),
                const SizedBox(height: 20),
                _sectionHeader('Account'),
                const SizedBox(height: 8),
                _accountSection(auth),
                const SizedBox(height: 20),
                _sectionHeader('Subscription'),
                const SizedBox(height: 8),
                _subscriptionSection(store),
                const SizedBox(height: 20),
                _sectionHeader('Reminders'),
                const SizedBox(height: 8),
                _remindersSection(),
                if (_archivedHabits.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionHeader('Archived Habits'),
                  const SizedBox(height: 8),
                  _archivedHabitsSection(),
                ],
                const SizedBox(height: 20),
                _sectionHeader('Lifetime Stats'),
                const SizedBox(height: 8),
                _statsSection(totalCheckIns, totalMinutes, totalCleanDays, totalCount, milestoneCount, habits.length),
                const SizedBox(height: 20),
                _sectionHeader('Circle Notifications'),
                const SizedBox(height: 8),
                _circleNotificationsSection(),
                const SizedBox(height: 20),
                _sectionHeader('About'),
                const SizedBox(height: 8),
                _infoRow('Version', '1.0.0'),
                const SizedBox(height: 20),
                _resetBibleReadingButton(),
                const SizedBox(height: 8),
                _resetButton(),
                const SizedBox(height: 8),
                _deleteAccountButton(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.2));
  }

  Widget _accountSection(AuthService auth) {
    if (auth.isAuthenticated) {
      return Column(children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileEditView())),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: GraceWayDecorations.card,
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: GraceWayColor.sage.withValues(alpha: 0.15)),
                child: const Icon(Icons.person_rounded, size: 18, color: GraceWayColor.sage),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(auth.displayName ?? 'Signed In',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
                Text(AuthService.isApplePlatform ? 'Apple Account' : 'Google Account',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
              ])),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 18),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => auth.signOut(),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: GraceWayDecorations.card,
            child: Row(children: [
              const Icon(Icons.logout_rounded, size: 16, color: GraceWayColor.warmCoral),
              const SizedBox(width: 10),
              const Text('Sign Out', style: TextStyle(fontSize: 14, color: GraceWayColor.warmCoral)),
            ]),
          ),
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.warning_amber, size: 14, color: GraceWayColor.warmCoral),
            const SizedBox(width: 6),
            Text(auth.error!, style: const TextStyle(fontSize: 12, color: GraceWayColor.warmCoral)),
          ]),
        ],
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GraceWayDecorations.card,
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
          child: const Icon(Icons.apple_rounded, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sign in with Apple',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
          Text('Required for Prayer Circles & backup',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
        ])),
        auth.isLoading
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: GraceWayColor.golden))
            : Icon(Icons.chevron_right, size: 16, color: Colors.white.withValues(alpha: 0.3)),
      ]),
    );
  }

  Widget _subscriptionSection(StoreProvider store) {
    return Column(children: [
      if (store.isPremium)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: GraceWayColor.golden.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.2), width: 0.5),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: GraceWayColor.golden.withValues(alpha: 0.15)),
              child: const Icon(Icons.workspace_premium_rounded, size: 18, color: GraceWayColor.golden),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GraceWay Pro', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GraceWayColor.golden)),
              Text('All premium features unlocked',
                  style: TextStyle(fontSize: 12, color: GraceWayColor.softGold)),
            ])),
            const Icon(Icons.verified_rounded, color: GraceWayColor.golden, size: 18),
          ]),
        )
      else
        GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: GraceWayColor.charcoal,
            builder: (_) => const GraceWayPaywallView(),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: GraceWayDecorations.card,
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: GraceWayColor.golden.withValues(alpha: 0.1)),
                child: Icon(Icons.workspace_premium_outlined, size: 18, color: GraceWayColor.golden.withValues(alpha: 0.6)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Upgrade to Pro',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
                Text('Unlimited habits, analytics & more',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4))),
              ])),
              Icon(Icons.chevron_right, size: 16, color: Colors.white.withValues(alpha: 0.3)),
            ]),
          ),
        ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: store.isLoading ? null : () => store.restore(),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: GraceWayDecorations.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.refresh_rounded, size: 16, color: GraceWayColor.softGold),
              const SizedBox(width: 10),
              Text('Restore Purchases', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
              const Spacer(),
              if (store.isLoading)
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: GraceWayColor.golden)),
            ]),
            if (store.error != null) ...[
              const SizedBox(height: 6),
              Text(store.error!,
                  style: const TextStyle(fontSize: 11, color: GraceWayColor.warmCoral)),
            ],
          ]),
        ),
      ),
    ]);
  }

  Widget _remindersSection() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: GraceWayDecorations.card,
        child: Row(children: [
          const Icon(Icons.notifications_rounded, size: 16, color: GraceWayColor.golden),
          const SizedBox(width: 10),
          const Expanded(child: Text('Daily Reminders',
              style: TextStyle(fontSize: 14, color: GraceWayColor.warmWhite))),
          Switch(
            value: _remindersEnabled,
            onChanged: (v) { setState(() => _remindersEnabled = v); _savePrefs(); },
            activeThumbColor: GraceWayColor.golden,
          ),
        ]),
      ),
      if (_remindersEnabled) ...[
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickTime,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: GraceWayDecorations.card,
            child: Row(children: [
              const Icon(Icons.access_time_rounded, size: 16, color: GraceWayColor.softGold),
              const SizedBox(width: 10),
              const Expanded(child: Text('Reminder Time',
                  style: TextStyle(fontSize: 14, color: GraceWayColor.warmWhite))),
              Text(_reminderTime.format(context),
                  style: const TextStyle(fontSize: 14, color: GraceWayColor.golden)),
            ]),
          ),
        ),
      ],
      if (_notifDenied && _remindersEnabled) ...[
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => AppSettings.openAppSettings(type: AppSettingsType.notification),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: GraceWayColor.warmCoral.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GraceWayColor.warmCoral.withValues(alpha: 0.2), width: 0.5),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber, size: 14, color: GraceWayColor.warmCoral),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Notifications disabled — tap to enable',
                    style: TextStyle(fontSize: 12, color: GraceWayColor.warmCoral)),
              ),
              const Icon(Icons.chevron_right, size: 14, color: GraceWayColor.warmCoral),
            ]),
          ),
        ),
      ],
    ]);
  }

  Widget _archivedHabitsSection() {
    return Column(
      children: _archivedHabits.map((habit) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: GraceWayDecorations.card,
          child: Row(children: [
            Icon(_habitIcon(habit), size: 16,
                color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(habit.name,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.45))),
            ),
            GestureDetector(
              onTap: () async {
                await context.read<HabitProvider>().unarchiveHabit(habit);
                await _loadArchivedHabits();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: GraceWayColor.golden.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: GraceWayColor.golden.withValues(alpha: 0.25), width: 0.5),
                ),
                child: const Text('Restore',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: GraceWayColor.golden)),
              ),
            ),
          ]),
        ),
      )).toList(),
    );
  }


  Widget _statsSection(int checkIns, double minutes, int cleanDays, double count, int milestones, int habitCount) {
    final hours = minutes ~/ 60;
    final mins = minutes.toInt() % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GraceWayDecorations.card,
      child: Column(children: [
        _statRow(Icons.check_circle_rounded, 'Total check-ins', '$checkIns', GraceWayColor.golden),
        if (minutes > 0) ...[
          const SizedBox(height: 12),
          _statRow(Icons.access_time_rounded, 'Time given', timeStr, GraceWayColor.golden),
        ],
        if (cleanDays > 0) ...[
          const SizedBox(height: 12),
          _statRow(Icons.shield_rounded, 'Clean days', '$cleanDays', GraceWayColor.sage),
        ],
        if (count > 0) ...[
          const SizedBox(height: 12),
          _statRow(Icons.tag_rounded, 'Total counted', '${count.toInt()}', GraceWayColor.golden),
        ],
        const SizedBox(height: 12),
        _statRow(Icons.list_rounded, 'Active habits', '$habitCount', GraceWayColor.golden),
        if (milestones > 0) ...[
          const SizedBox(height: 12),
          _statRow(Icons.star_rounded, 'Milestones reached', '$milestones', GraceWayColor.golden),
        ],
      ]),
    );
  }

  Widget _statRow(IconData icon, String label, String value, Color color) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.5)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)))),
      Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Widget _circleNotificationsSection() {
    return Container(
      decoration: GraceWayDecorations.card,
      child: Column(
        children: [
          _circleNotifToggle(
            label: 'Prayer Requests',
            subtitle: 'Help and prayer requests from members',
            value: _circleNotifPrayer,
            onChanged: (val) {
              setState(() => _circleNotifPrayer = val);
              _saveCircleNotifPref('circle_notif_prayer', val);
            },
          ),
          Divider(height: 1, color: GraceWayColor.warmWhite.withValues(alpha: 0.06)),
          _circleNotifToggle(
            label: 'Announcements',
            subtitle: 'Admin announcements for your circles',
            value: _circleNotifAnnouncement,
            onChanged: (val) {
              setState(() => _circleNotifAnnouncement = val);
              _saveCircleNotifPref('circle_notif_announcement', val);
            },
          ),
        ],
      ),
    );
  }

  Widget _circleNotifToggle({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: GraceWayColor.warmWhite)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: GraceWayColor.warmWhite.withValues(alpha: 0.45))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: GraceWayColor.softGold,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GraceWayDecorations.card,
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)))),
        Text(value, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.4))),
      ]),
    );
  }

  Widget _deleteAccountButton() {
    return GestureDetector(
      onTap: _confirmDeleteAccount,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GraceWayColor.warmCoral.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Row(children: [
          Icon(Icons.no_accounts_rounded, size: 16, color: GraceWayColor.warmCoral.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(child: Text('Delete My Account',
              style: TextStyle(fontSize: 14, color: GraceWayColor.warmCoral.withValues(alpha: 0.7)))),
        ]),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GraceWayColor.cardBackground,
        title: const Text('Delete Account', style: TextStyle(color: GraceWayColor.warmWhite)),
        content: Text(
          'This permanently deletes your account and all your data — habits, journal entries, circles, and all media. '
          'This cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount();
            },
            child: const Text('Delete Forever', style: TextStyle(color: GraceWayColor.warmCoral)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final auth = context.read<AuthService>();
    await auth.deleteAccount();
    // On success, AuthService notifyListeners() triggers root_view.dart to pop
    // all routes and show the onboarding screen automatically. On failure,
    // auth.error is non-null and displayed in the account section.
  }

  Widget _resetBibleReadingButton() {
    return GestureDetector(
      onTap: _confirmResetBibleReading,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GraceWayColor.golden.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: GraceWayColor.golden.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.menu_book_rounded,
              size: 16, color: GraceWayColor.golden),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Reset Bible Reading Plan',
                  style: TextStyle(fontSize: 14, color: GraceWayColor.golden))),
        ]),
      ),
    );
  }

  void _confirmResetBibleReading() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GraceWayColor.cardBackground,
        title: const Text('Reset Bible Reading Plan',
            style: TextStyle(color: GraceWayColor.warmWhite)),
        content: const Text(
          'This will delete all your reading progress and streaks. This cannot be undone.',
          style: TextStyle(color: GraceWayColor.softGold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: GraceWayColor.softGold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<BibleReadingProvider>().resetPlan();
            },
            child: const Text('Reset',
                style: TextStyle(color: GraceWayColor.warmCoral)),
          ),
        ],
      ),
    );
  }

  Widget _resetButton() {
    return GestureDetector(
      onTap: _confirmReset,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GraceWayColor.warmCoral.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GraceWayColor.warmCoral.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Row(children: [
          const Icon(Icons.delete_rounded, size: 16, color: GraceWayColor.warmCoral),
          const SizedBox(width: 10),
          const Expanded(child: Text('Reset All Data',
              style: TextStyle(fontSize: 14, color: GraceWayColor.warmCoral))),
        ]),
      ),
    );
  }

  IconData _habitIcon(Habit habit) {
    if (habit.trackingType == HabitTrackingType.abstain) return Icons.shield_rounded;
    switch (habit.category) {
      case HabitCategory.gratitude: return Icons.auto_awesome;
      case HabitCategory.scripture: return Icons.menu_book;
      case HabitCategory.exercise: return Icons.fitness_center;
      case HabitCategory.rest: return Icons.bedtime;
      case HabitCategory.fasting: return Icons.no_food;
      case HabitCategory.study: return Icons.school;
      case HabitCategory.service: return Icons.volunteer_activism;
      case HabitCategory.connection: return Icons.people;
      case HabitCategory.health: return Icons.favorite;
      case HabitCategory.abstain: return Icons.shield_rounded;
      case HabitCategory.prayer: return Icons.self_improvement_rounded;
      case HabitCategory.custom: return Icons.star;
    }
  }
}
