import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../../domain/entities/habit.dart';
import '../../../domain/utils/seeded_rng.dart';

class NotificationService {
  static final NotificationService shared = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool isAuthorized = false;

  static const _reminderMessages = [
    'Your walk is waiting. Just a moment with God today.',
    'A few minutes. A small gift. God sees it all.',
    "Today's offering is ready whenever you are.",
    'Even a single check-in changes the shape of your day.',
    'Your habits are waiting — each one a gift to God.',
    'A quiet moment with God today. That\'s all it takes.',
    'Start with gratitude. Everything else follows.',
    'God meets you in the effort and in the rest.',
    'One small step today. He\'s already walking with you.',
    'Your walk matters — even on the hard days.',
  ];

  static const _timeMilestones = [
    (7, 'One week down', "You showed up, and God met you in it. Let's keep going."),
    (14, 'Two weeks', "You're past the point where most people quit a new app. You're still here."),
    (21, '3 weeks in', "This is usually when the newness fades and it starts to feel like work. That's normal. You're doing the hard part."),
    (30, 'A full month', "30 days of giving this to God. That's not a small thing."),
    (45, 'Over 6 weeks', 'Most people never make it this far. The rhythm is starting to take hold. Keep showing up.'),
    (66, '66 days', "Research says this is roughly when a habit becomes automatic. This isn't something you do anymore — it's who you are."),
    (100, '100 days', "A hundred times you chose to show up. That's a life that's being changed."),
    (365, 'A full year', "365 days of giving this to God. Whatever this year looked like — the strong weeks and the quiet ones — He was in all of it."),
  ];

  // Android notification channels
  static const _channelCircles = AndroidNotificationChannel(
    'circles',
    'Circle Notifications',
    description: 'Announcements and prayer requests from your circles',
    importance: Importance.high,
  );
  static const _channelPartnerships = AndroidNotificationChannel(
    'partnerships',
    'Partner Messages',
    description: 'Messages from your support/prayer partner',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> init() async {
    tz_data.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(const InitializationSettings(android: androidSettings, iOS: iosSettings));
    // Create Android notification channels
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channelCircles);
    await androidPlugin?.createNotificationChannel(_channelPartnerships);
    await checkAuthorization();
  }

  /// Show a foreground notification for an incoming push notification (FCM
  /// messages that arrive while the app is in the foreground are silent by
  /// default — this makes them visible).
  ///
  /// [channelId] should be one of: 'circles', 'partnerships'.
  Future<void> showCircleNotification({
    required String id,
    required String title,
    required String body,
    String channelId = 'circles',
  }) async {
    final notifId = id.hashCode & 0x7fffffff;
    final channelName = channelId == 'partnerships' ? 'Partner Messages' : 'Circle Notifications';
    await _plugin.show(
      notifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  Future<void> checkAuthorization() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.areNotificationsEnabled() ?? false;
      isAuthorized = granted;
    } else {
      // iOS — assume authorized if we've been granted before
      final prefs = await SharedPreferences.getInstance();
      isAuthorized = prefs.getBool('tribute_notifications_authorized') ?? false;
    }
  }

  Future<bool> requestAuthorization() async {
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      isAuthorized = granted;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tribute_notifications_authorized', granted);
      return granted;
    }
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission() ?? false;
      isAuthorized = granted;
      return granted;
    }
    return false;
  }

  Future<void> clearBadge() async {
    await _plugin.cancel(0);
  }

  Future<void> scheduleDailyReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('tribute_reminders_enabled') ?? false;
    if (!enabled) { await cancelDailyReminders(); return; }

    final hour = prefs.getInt('tribute_reminder_hour') ?? 8;
    final minute = prefs.getInt('tribute_reminder_minute') ?? 0;

    await cancelDailyReminders();

    for (int i = 0; i < 7; i++) {
      final body = _reminderMessages[i % _reminderMessages.length];
      await _plugin.zonedSchedule(
        100 + i,
        'GraceWay',
        body,
        _nextWeekday(i + 1, hour, minute),
        NotificationDetails(
          android: const AndroidNotificationDetails('daily_reminder', 'Daily Reminders', importance: Importance.defaultImportance),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelDailyReminders() async {
    for (int i = 0; i < 7; i++) {
      await _plugin.cancel(100 + i);
    }
  }

  Future<void> refreshAllNotifications(List<Habit> habits) async {
    await checkAuthorization();
    if (!isAuthorized) return;
    await scheduleDailyReminders();

    final prefs = await SharedPreferences.getInstance();
    final onboardingMs = prefs.getInt('tribute_onboarding_date');
    final onboarding = onboardingMs != null ? DateTime.fromMillisecondsSinceEpoch(onboardingMs) : DateTime.now();
    final daysSince = DateTime.now().difference(onboarding).inDays;

    for (final habit in habits) {
      await _scheduleTimeMilestones(habit);
    }
    await _scheduleVariableReinforcement(daysSince);
  }

  Future<void> _scheduleTimeMilestones(Habit habit) async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('tribute_reminder_hour') ?? 9;
    final minute = prefs.getInt('tribute_reminder_minute') ?? 0;

    for (final m in _timeMilestones) {
      final target = habit.createdAt.add(Duration(days: m.$1));
      if (!target.isAfter(DateTime.now())) continue;
      final scheduled = DateTime(target.year, target.month, target.day, hour, minute);
      await _plugin.zonedSchedule(
        Object.hash(habit.id, m.$1) & 0x7fffffff,
        m.$2, m.$3,
        _toTZDateTime(scheduled),
        NotificationDetails(
          android: const AndroidNotificationDetails('milestones', 'Milestones', importance: Importance.high),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> _scheduleVariableReinforcement(int daysSinceOnboarding) async {
    if (daysSinceOnboarding < 30) return;
    await _plugin.cancel(99999);

    const messages = [
      'Remember when this felt hard? Look at you now.',
      "You're building something real. God sees every single day.",
      "Your consistency is its own kind of worship. Keep going.",
      "The rhythm you've built? That's not willpower — that's faithfulness.",
      "Some days it's easy, some days it's not. You show up either way. That matters.",
    ];

    // Use a deterministic seeded RNG keyed on daysSinceOnboarding so the
    // same run produces the same schedule, avoiding message/interval drift
    // across multiple calls within the same app session.
    final rng = SeededRng(daysSinceOnboarding * 13 + 7);
    final daysUntilNext = 14 + (rng.next() % 15);
    final messageIdx = rng.next() % messages.length;
    final target = DateTime.now().add(Duration(days: daysUntilNext));
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('tribute_reminder_hour') ?? 10;
    final minute = prefs.getInt('tribute_reminder_minute') ?? 0;
    final scheduled = DateTime(target.year, target.month, target.day, hour, minute);
    final body = messages[messageIdx];

    await _plugin.zonedSchedule(
      99999, 'GraceWay', body,
      _toTZDateTime(scheduled),
      NotificationDetails(
        android: const AndroidNotificationDetails('encouragement', 'Encouragement', importance: Importance.defaultImportance),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Helpers — using local timezone via DateTime
  // In production, integrate timezone package for precise scheduling

  tz.TZDateTime _toTZDateTime(DateTime dt) {
    return tz.TZDateTime.from(dt, tz.local);
  }

  tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    var now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
