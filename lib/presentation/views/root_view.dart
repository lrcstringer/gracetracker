import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/habit_provider.dart';
import '../../data/datasources/remote/auth_service.dart';
import '../../data/datasources/local/notification_service.dart'; // used in _loadOnboardingState
import '../../data/services/pending_invite_service.dart';
import '../../data/services/pending_partner_token_service.dart';
import '../../domain/repositories/user_preferences_repository.dart';
import '../../domain/services/week_cycle_manager.dart';
import 'content_view.dart';
import 'onboarding/onboarding_container_view.dart';

class RootView extends StatefulWidget {
  const RootView({super.key});

  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView> {
  bool _onboardingComplete = false;
  bool _ready = false;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
    _initDeepLinks();
    // Re-check onboarding state when the user signs in on a new device.
    // On a fresh install, the local cache is empty until sign-in completes
    // and userPrefs.init() pulls the flag from Firestore.
    AuthService.shared.addListener(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    AuthService.shared.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  /// Initialises [AppLinks] deep-link handling.
  ///
  /// - `getInitialLink()` catches the URI that cold-started the app.
  /// - `uriLinkStream` catches links while the app is already running.
  ///
  /// Both paths extract the invite code and hand it to [PendingInviteService],
  /// which persists it for [ContentView] to pick up (even if onboarding hasn't
  /// finished yet).
  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    final inviteService = context.read<PendingInviteService>();
    final partnerTokenService = context.read<PendingPartnerTokenService>();

    // Cold-start / app-not-running link.
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) _handleLink(initial, inviteService, partnerTokenService);
    } catch (_) {}

    // Link received while app is foregrounded or in background.
    _linkSub = appLinks.uriLinkStream.listen(
      (uri) => _handleLink(uri, inviteService, partnerTokenService),
      onError: (_) {},
    );
  }

  void _handleLink(Uri uri, PendingInviteService inviteService,
      PendingPartnerTokenService partnerTokenService) {
    // Circle invite:  graceway://join?code=XXXX
    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      inviteService.save(code);
      return;
    }

    // Partner invite (custom scheme): graceway://accountability/accept?token=TOKEN
    if (uri.scheme == 'graceway' && uri.host == 'accountability') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) partnerTokenService.save(token);
      return;
    }

    // Partner invite (HTTPS App Link): https://gracetracker.com/accountability/accept/TOKEN
    final segments = uri.pathSegments;
    if (segments.length >= 3 &&
        segments[0] == 'accountability' &&
        segments[1] == 'accept') {
      final token = segments[2];
      if (token.isNotEmpty) partnerTokenService.save(token);
    }
  }

  /// Fires whenever FirebaseAuth state changes. If the user just authenticated
  /// and we haven't yet shown ContentView, re-hydrate the prefs cache from
  /// Firestore and re-evaluate the onboarding flag.
  void _onAuthStateChanged() {
    if (AuthService.shared.isAuthenticated) {
      if (_ready && !_onboardingComplete) _rehydrateAndCheck();
    } else {
      // User signed out — pop any pushed screens first (e.g. Settings) so
      // the navigation stack is clear, then swap to the sign-in screen.
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        setState(() => _onboardingComplete = false);
      }
    }
  }

  Future<void> _rehydrateAndCheck() async {
    final userPrefs = context.read<UserPreferencesRepository>();
    await userPrefs.init();
    if (mounted) await _loadOnboardingState();
  }

  Future<void> _loadOnboardingState() async {
    final userPrefs = context.read<UserPreferencesRepository>();
    final onboardingComplete = await userPrefs.getBool('tribute_onboarding_complete');
    setState(() {
      _onboardingComplete = onboardingComplete ?? false;
      _ready = true;
    });

    if (_onboardingComplete && mounted) {
      _scheduleNotificationsWhenReady();
    }
  }

  /// Defers notification scheduling until HabitProvider has finished loading.
  /// Calling refreshAllNotifications with an empty list would skip all
  /// habit-specific milestone notifications.
  void _scheduleNotificationsWhenReady() {
    final habitProvider = context.read<HabitProvider>();
    if (!habitProvider.isLoading) {
      NotificationService.shared.refreshAllNotifications(habitProvider.habits);
      return;
    }
    void listener() {
      if (!habitProvider.isLoading && mounted) {
        habitProvider.removeListener(listener);
        NotificationService.shared.refreshAllNotifications(habitProvider.habits);
      }
    }
    habitProvider.addListener(listener);
  }

  Future<void> _completeOnboarding() async {
    // Notification permission and scheduling are handled by NotificationPreferencesScreen
    // (step 8 of onboarding). Do not repeat them here — a second requestAuthorization()
    // call can throw and would prevent the app from ever transitioning out of onboarding.
    try {
      final wcm = context.read<WeekCycleManager>();
      final userPrefs = context.read<UserPreferencesRepository>();
      await userPrefs.setBool('tribute_onboarding_complete', true);
      // Only set the onboarding date and dedicate the week for new users.
      // Returning users (reinstall / new device) already have these set in Firestore.
      final existingDate = await userPrefs.getInt('tribute_onboarding_date');
      if (existingDate == null) {
        await userPrefs.setInt('tribute_onboarding_date', DateTime.now().millisecondsSinceEpoch);
        await wcm.dedicateCurrentWeek();
      }
    } catch (_) {
      // Always complete onboarding — errors here must not leave the user stuck.
    }
    if (mounted) setState(() => _onboardingComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E1E2E),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD4A843))),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _onboardingComplete
          ? ContentView(key: const ValueKey('content'))
          : OnboardingContainerView(
              key: const ValueKey('onboarding'),
              onComplete: _completeOnboarding,
            ),
    );
  }
}
