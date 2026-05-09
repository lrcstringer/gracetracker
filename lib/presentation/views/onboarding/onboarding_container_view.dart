import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../domain/repositories/user_preferences_repository.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/entities/habit.dart';
import '../../providers/habit_provider.dart';
import '../../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'sign_in_screen.dart';
import 'identity_screen.dart';
import 'reframe_screen.dart';
import 'first_gratitude_screen.dart';
import 'habit_selection_screen.dart';
import 'habit_setup_screen.dart';
import 'paywall_screen.dart';
import 'dedication_ceremony_screen.dart';

class OnboardingContainerView extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingContainerView({super.key, required this.onComplete});

  @override
  State<OnboardingContainerView> createState() => _OnboardingContainerViewState();
}

class _OnboardingContainerViewState extends State<OnboardingContainerView> {
  // Set to true when rolling out to production to show the paywall.
  static const bool _paywallEnabled = false;

  int _currentStep = 0;
  bool _isSavingHabit = false;
  String? _gratitudeNote;
  HabitCategory? _selectedCategory;
  String _customHabitName = '';
  HabitTrackingType _customTrackingType = HabitTrackingType.checkIn;
  double _customDailyTarget = 1;
  String _customTargetUnit = '';
  Set<int> _customActiveDays = const {1, 2, 3, 4, 5, 6, 7};

  // 0: Welcome  1: SignIn  2: Identity  3: Reframe  4: FirstGratitude
  // 5: HabitSelection  6: HabitSetup  7: Paywall  8: DedicationCeremony
  static const int _totalSteps = 9;

  void _advance() => setState(() => _currentStep++);

  void _back() {
    if (_currentStep > 2) setState(() => _currentStep--);
  }

  @override
  Widget build(BuildContext context) {
    // Show nav bar for steps 2–7 (between sign-in and dedication).
    final showNav = _currentStep >= 2 && _currentStep < _totalSteps - 1;

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      body: SafeArea(
        child: Column(children: [
          if (showNav) _navBar(),
          Expanded(child: _screenContent()),
        ]),
      ),
    );
  }

  Widget _navBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        if (_currentStep > 2)
          GestureDetector(
            onTap: _back,
            child: SizedBox(
              width: 44, height: 44,
              child: Icon(Icons.chevron_left, color: GraceWayColor.softGold.withValues(alpha: 0.6)),
            ),
          )
        else
          const SizedBox(width: 44),
        const Spacer(),
        _progressDots(),
        const Spacer(),
        const SizedBox(width: 44),
      ]),
    );
  }

  Widget _progressDots() {
    // Dots for steps 2–7 (6 dots total).
    const dotSteps = _totalSteps - 3; // steps 2..6 = 6
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(dotSteps, (i) {
        final step = i + 2;
        final active = step == _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 8 : 6,
          height: active ? 8 : 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: step <= _currentStep
                ? GraceWayColor.golden
                : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }

  Widget _screenContent() {
    switch (_currentStep) {
      case 0:
        return WelcomeScreen(onNext: _advance);

      case 1:
        return SignInScreen(onNext: _onSignInComplete);

      case 2:
        final auth = context.read<AuthService>();
        return IdentityScreen(
          prefilledName: auth.givenName,
          onContinue: (name, selections) => _onIdentityContinue(name, selections),
          onSkip: _advance,
        );

      case 3:
        return ReframeScreen(onNext: _advance);

      case 4:
        return FirstGratitudeScreen(
          onComplete: (note) {
            _gratitudeNote = note;
            _createGratitudeHabit(note);
            _advance();
          },
        );

      case 5:
        return HabitSelectionScreen(
          onSelect: (category) {
            setState(() => _selectedCategory = category);
            _advance();
          },
        );

      case 6:
        if (_selectedCategory == null) {
          _advance();
          return const SizedBox.shrink();
        }
        return HabitSetupScreen(
          category: _selectedCategory!,
          onComplete: (name, tracking, target, unit, days) {
            setState(() {
              _customHabitName = name;
              _customTrackingType = tracking;
              _customDailyTarget = target;
              _customTargetUnit = unit;
              _customActiveDays = days;
            });
            _createCustomHabitAndAdvance();
          },
        );

      case 7:
        if (!_paywallEnabled) {
          // Skip paywall during testing — flip _paywallEnabled for production.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _advance();
          });
          return const SizedBox.shrink();
        }
        return PaywallScreen(onNext: _advance);

      case 8:
        return DedicationCeremonyScreen(
          gratitudeNote: _gratitudeNote,
          habitName: _customHabitName,
          habitCategory: _selectedCategory ?? HabitCategory.gratitude,
          trackingType: _customTrackingType,
          dailyTarget: _customDailyTarget,
          targetUnit: _customTargetUnit,
          onComplete: widget.onComplete,
          givenName: context.read<AuthService>().givenName,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ── Callbacks ─────────────────────────────────────────────────────────────

  /// Called when sign-in completes. Returning users skip onboarding entirely;
  /// new users are routed through the full flow.
  ///
  /// "Returning" is determined by either signal:
  ///   • `AuthService.lastSignInWasNewUser == false` — Firebase's
  ///     `additionalUserInfo.isNewUser`, the authoritative server-side
  ///     answer to "did this sign-in match an existing UID?"
  ///   • `tribute_onboarding_complete == true` in the Firestore prefs doc —
  ///     a fallback for cases where isNewUser is unreliable (e.g. test
  ///     scenarios where someone deleted only the prefs doc).
  ///
  /// `userPrefs.init()` always runs so the rest of the user's preferences
  /// (onboarding date, week-cycle state) hydrate into the local cache before
  /// `_completeOnboarding` reads them.
  Future<void> _onSignInComplete() async {
    final auth = context.read<AuthService>();
    final userPrefs = context.read<UserPreferencesRepository>();
    await userPrefs.init();
    if (!mounted) return;
    final alreadyOnboarded =
        await userPrefs.getBool('tribute_onboarding_complete') ?? false;
    if (!mounted) return;
    if (!auth.lastSignInWasNewUser || alreadyOnboarded) {
      widget.onComplete();
    } else {
      _advance();
    }
  }

  Future<void> _onIdentityContinue(String name, List<String> selections) async {
    final auth = context.read<AuthService>();
    if (auth.userId != null) {
      final repo = context.read<UserRepository>();
      await repo.updateFields({
        'name': name.isNotEmpty ? name : null,
        'identitySelections': selections,
      });
    }
    _advance();
  }

  void _createGratitudeHabit(String? note) {
    final provider = context.read<HabitProvider>();
    final hasGratitude = provider.habits.any(
        (h) => h.category == HabitCategory.gratitude);
    if (hasGratitude) return;
    provider.addHabit(
      name: 'Daily Gratitude',
      category: HabitCategory.gratitude,
      trackingType: HabitTrackingType.checkIn,
      purpose: 'Give thanks in all circumstances; for this is God\u2019s will for you in Christ Jesus.',
      dailyTarget: 1,
      targetUnit: '',
    ).then((_) {
      if (note != null && provider.habits.isNotEmpty) {
        final gratitude = provider.habits.firstWhere(
            (h) => h.isBuiltIn && h.category == HabitCategory.gratitude,
            orElse: () => provider.habits.first);
        provider.checkInGratitude(gratitude, note: note, date: DateTime.now());
      }
    });
  }

  Future<void> _createCustomHabitAndAdvance() async {
    if (_isSavingHabit) return;
    if (_selectedCategory == null || _customHabitName.isEmpty) {
      _advance();
      return;
    }
    setState(() => _isSavingHabit = true);
    try {
      await context.read<HabitProvider>().addHabit(
        name: _customHabitName,
        category: _selectedCategory!,
        trackingType: _customTrackingType,
        purpose: _selectedCategory!.defaultPurpose,
        dailyTarget: _customDailyTarget,
        targetUnit: _customTargetUnit,
        activeDays: _customActiveDays,
      );
      if (mounted) _advance();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't save your activity. Check your connection and try again."),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingHabit = false);
    }
  }
}
