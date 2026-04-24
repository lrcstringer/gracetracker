import 'dart:async';
import 'package:app_settings/app_settings.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../theme/app_theme.dart';
import '../shared/terms_view.dart';

/// Step 1 of onboarding — sign in with Apple (iOS) or Google (Android).
/// Mandatory: the user cannot proceed without signing in so that all data
/// is tied to a Firebase UID from the very first habit created.
class SignInScreen extends StatefulWidget {
  final VoidCallback onNext;
  const SignInScreen({super.key, required this.onNext});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _showContent = false;
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  late final TapGestureRecognizer _termsTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => TermsView.show(context);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showContent = true);
    });
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateOfflineState(results);
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_updateOfflineState);
  }

  void _updateOfflineState(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (mounted && offline != _isOffline) setState(() => _isOffline = offline);
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _handleSignIn(AuthService auth) async {
    await auth.signIn();
    if (!mounted) return;
    if (auth.isAuthenticated) {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isApple = AuthService.isApplePlatform;

    return Column(children: [
      Expanded(
        child: AnimatedOpacity(
          opacity: _showContent ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: AnimatedSlide(
            offset: _showContent ? Offset.zero : const Offset(0, 0.08),
            duration: const Duration(milliseconds: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        GraceWayColor.golden.withValues(alpha: 0.2),
                        GraceWayColor.golden.withValues(alpha: 0.04),
                      ]),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      size: 32,
                      color: GraceWayColor.golden,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Heading
                  const Text(
                    'Your walk,\nalways with you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: GraceWayColor.warmWhite,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Sub-heading
                  Text(
                    'Sign in so your habits & activities and progress'
                    ' are safely backed up and available on any device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.55),
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Privacy note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GraceWayColor.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: GraceWayColor.cardBorder, width: 0.5),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.security_rounded,
                          size: 16, color: GraceWayColor.golden.withValues(alpha: 0.7)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your walk is saved securely to your account. We never share your data with third-parties.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.45),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ]),
                  ),

                  // Error
                  if (auth.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      auth.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: GraceWayColor.warmCoral),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),

      // Offline banner
      if (_isOffline)
        ColoredBox(
          color: Colors.orange.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.orange, height: 1.4),
                    children: [
                      const TextSpan(text: 'No internet connection. '),
                      TextSpan(
                        text: 'Open Settings',
                        style: const TextStyle(decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => AppSettings.openAppSettings(type: AppSettingsType.wifi),
                      ),
                      const TextSpan(text: ' to connect.'),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),

      // Bottom CTA
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: auth.isLoading || _isOffline ? null : () => _handleSignIn(auth),
              icon: auth.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: GraceWayColor.charcoal),
                    )
                  : Icon(
                      isApple ? Icons.apple : Icons.g_mobiledata_rounded,
                      size: 20,
                    ),
              label: Text(
                auth.isLoading
                    ? 'Signing in\u2026'
                    : isApple
                        ? 'Continue with Apple'
                        : 'Continue with Google',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: GraceWayColor.golden,
                foregroundColor: GraceWayColor.charcoal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.3)),
              children: [
                const TextSpan(text: 'By continuing you agree to our '),
                TextSpan(
                  text: 'Terms of Service and Privacy Policy',
                  style: const TextStyle(
                    color: GraceWayColor.softGold,
                    decoration: TextDecoration.underline,
                    decorationColor: GraceWayColor.softGold,
                  ),
                  recognizer: _termsTap,
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ]),
      ),
    ]);
  }
}
