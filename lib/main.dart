import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'presentation/providers/habit_provider.dart';
import 'presentation/providers/store_provider.dart';
import 'data/datasources/remote/api_service.dart';
import 'data/datasources/remote/auth_service.dart';
import 'data/datasources/local/notification_service.dart';
import 'data/repositories/firestore_user_preferences_repository.dart';
import 'data/repositories/firestore_habit_repository.dart';
import 'data/repositories/firestore_user_repository.dart';
import 'data/repositories/firestore_circle_repository.dart';
import 'data/repositories/firestore_iap_repository.dart';
import 'data/services/pending_invite_service.dart';
import 'data/services/pending_partner_token_service.dart';
import 'data/repositories/firestore_accountability_repository.dart';
import 'domain/repositories/accountability_repository.dart';
import 'presentation/providers/accountability_provider.dart';
import 'domain/repositories/iap_repository.dart';
import 'domain/repositories/user_preferences_repository.dart';
import 'domain/repositories/circle_repository.dart';
import 'domain/repositories/user_repository.dart';
import 'domain/services/week_cycle_manager.dart';
import 'domain/services/engagement_service.dart';
import 'presentation/providers/weekly_pulse_provider.dart';
import 'presentation/providers/habit_category_provider.dart';
import 'presentation/providers/journal_provider.dart';
import 'data/repositories/local_habit_category_repository.dart';
import 'data/repositories/firestore_journal_repository.dart';
import 'data/services/pending_action_queue_service.dart';
import 'data/services/pending_notification_send_queue.dart';
import 'data/repositories/firestore_notification_repository.dart';
import 'domain/repositories/notification_repository.dart';
import 'presentation/providers/circle_notification_provider.dart';
import 'app.dart';

/// Top-level handler for background/terminated FCM messages.
/// The FCM payload includes a `notification` field so the OS displays the
/// notification automatically — no manual display needed here.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore offline persistence so the app works without a connection.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await APIService.shared.init();
  await AuthService.shared.init();
  await NotificationService.shared.init();

  // Request FCM permission and register token.
  final fcm = FirebaseMessaging.instance;
  await fcm.requestPermission(alert: true, badge: true, sound: true);

  // Keep the latest token so it can be re-registered after sign-in
  // (new users aren't authenticated when getToken() first fires).
  String? latestFcmToken;
  void registerToken(String token) {
    latestFcmToken = token;
    APIService.shared.registerPushToken(token).catchError((_) {});
  }

  // getToken() requires network and will hang indefinitely when offline.
  // Fire-and-forget: onTokenRefresh below handles registration once online.
  fcm.getToken().then((token) {
    if (token != null) registerToken(token);
  }).catchError((_) {});
  fcm.onTokenRefresh.listen(registerToken);

  // Show foreground notifications for incoming FCM messages.
  FirebaseMessaging.onMessage.listen((message) {
    NotificationService.shared.showCircleNotification(
      id: message.data['notifId'] ?? message.messageId ?? 'fg',
      title: message.notification?.title ?? 'Circle Notification',
      body: message.notification?.body ?? '',
      channelId: 'circles',
    );
  });

  final habitRepository = FirestoreHabitRepository();
  final userRepository = FirestoreUserRepository();
  final sharedPrefs = await SharedPreferences.getInstance();
  final userPrefs = FirestoreUserPreferencesRepository(
    db: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
    cache: sharedPrefs,
  );
  await userPrefs.init();
  // Re-sync on every sign-in (handles reinstall and new-device flows).
  // Also re-register the FCM token — new users aren't authenticated when
  // getToken() first fires, so the first registration attempt is a no-op.
  AuthService.shared.addListener(() {
    if (AuthService.shared.isAuthenticated) {
      userPrefs.init();
      if (latestFcmToken != null) {
        APIService.shared.registerPushToken(latestFcmToken!).catchError((_) {});
      }
    }
  });

  final iapRepository = FirestoreIAPRepository();
  final storeProvider = StoreProvider(iapRepository: iapRepository, prefs: sharedPrefs);
  final pendingInviteService = PendingInviteService(sharedPrefs);
  final pendingPartnerTokenService = PendingPartnerTokenService(sharedPrefs);
  final accountabilityRepository = FirestoreAccountabilityRepository();

  final journalRepository = FirestoreJournalRepository();
final pendingActionQueue = PendingActionQueueService(sharedPrefs);
  final pendingSendQueue = PendingNotificationSendQueue(sharedPrefs);
  final notificationRepository = FirestoreNotificationRepository(pendingActionQueue, pendingSendQueue);

  runApp(
    MultiProvider(
      providers: [
        Provider<PendingInviteService>.value(value: pendingInviteService),
        Provider<PendingPartnerTokenService>.value(value: pendingPartnerTokenService),
        Provider<AccountabilityRepository>.value(value: accountabilityRepository),
        ChangeNotifierProvider<AccountabilityProvider>(
          create: (_) => AccountabilityProvider(accountabilityRepository),
        ),
        Provider<IAPRepository>.value(value: iapRepository),
        Provider<UserPreferencesRepository>.value(value: userPrefs),
        Provider<UserRepository>.value(value: userRepository),
        Provider<WeekCycleManager>(create: (_) => WeekCycleManager(userPrefs)),
        ChangeNotifierProvider<EngagementService>(create: (_) => EngagementService(userPrefs)),
        Provider<CircleRepository>(
            create: (_) => FirestoreCircleRepository(pendingSendQueue)),
        ChangeNotifierProvider<HabitCategoryProvider>(
          create: (_) => HabitCategoryProvider(LocalHabitCategoryRepository())
            ..loadCategories(),
        ),
        ChangeNotifierProvider(
          create: (context) => HabitProvider(
            habitRepository,
            () => AuthService.shared.isAuthenticated,
            context.read<CircleRepository>(),
          )..loadHabits(),
        ),
        ChangeNotifierProvider<StoreProvider>.value(value: storeProvider),
        ChangeNotifierProvider.value(value: AuthService.shared),
        ChangeNotifierProvider<WeeklyPulseProvider>(
          create: (context) => WeeklyPulseProvider(context.read<CircleRepository>()),
        ),
        ChangeNotifierProvider<JournalProvider>(
          create: (_) => JournalProvider(journalRepository),
        ),
        Provider<PendingActionQueueService>.value(value: pendingActionQueue),
        Provider<NotificationRepository>.value(value: notificationRepository),
        ChangeNotifierProvider<CircleNotificationProvider>(
          create: (_) => CircleNotificationProvider(notificationRepository),
        ),
      ],
      child: const GraceWayApp(),
    ),
  );

  // Initialise IAP after the widget tree is up so StoreProvider can
  // call notifyListeners() safely.
  await storeProvider.init();
}
