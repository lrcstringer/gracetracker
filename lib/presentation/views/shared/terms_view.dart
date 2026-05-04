import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TermsView extends StatelessWidget {
  const TermsView({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TermsView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        title: const Text(
          'Terms & Privacy Policy',
          style: TextStyle(
            color: GraceWayColor.warmWhite,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: GraceWayColor.warmWhite),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 48),
        child: _TermsContent(),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _effectiveDate('April 3, 2026'),
        const SizedBox(height: 24),

        // ── TERMS OF SERVICE ───────────────────────────────────────────────
        _sectionTitle('Terms of Service'),
        const SizedBox(height: 12),

        _heading('1. Acceptance of Terms'),
        _body(
          'By downloading or using GraceWay ("the App"), you agree to be bound by '
          'these Terms of Service. If you do not agree, please do not use the App.',
        ),

        _heading('2. Description of Service'),
        _body(
          'GraceWay is a faith-based habit and spiritual practice tracking app. It '
          'allows you to log daily habits, track abstinence, time spiritual '
          'activities, record progress, join Prayer Circles, and reflect on your '
          'walk with God. Some features require an account and an active internet '
          'connection.',
        ),

        _heading('3. Account & Sign-In'),
        _body(
          'You may sign in using Apple Sign In (iOS) or Google Sign In (Android). '
          'By signing in, you authorize GraceWay to create and maintain a secure '
          'account associated with your identity. You are responsible for '
          'maintaining the confidentiality of your account and for all activity '
          'that occurs under it.',
        ),

        _heading('4. Acceptable Use'),
        _body(
          'You agree not to use the App to:\n'
          '• Post or share content that is abusive, threatening, or harmful.\n'
          '• Impersonate any person or entity.\n'
          '• Attempt to gain unauthorized access to any part of the App or its '
          'backend services.\n'
          '• Use the App for any unlawful purpose.',
        ),

        _heading('5. Prayer Circles & User Content'),
        _body(
          'Prayer Circles allow you to share prayer requests and encouragements '
          'with other members you invite. You retain ownership of any content you '
          'submit. By sharing content in a Prayer Circle, you grant other circle '
          'members the right to view it within the App. You are solely responsible '
          'for the content you share. We reserve the right to remove content that '
          'violates these Terms.',
        ),

        _heading('6. In-App Purchases'),
        _body(
          'GraceWay offers optional premium features through in-app purchases '
          'processed by Apple (App Store) or Google (Play Store). All purchases '
          'are final and non-refundable except as required by applicable law or '
          'the platform\'s own refund policies. Subscriptions automatically renew '
          'unless cancelled at least 24 hours before the renewal date through your '
          'platform account settings.',
        ),

        _heading('7. Intellectual Property'),
        _body(
          'All content, design, code, and branding within the App are the '
          'property of GraceWay and its developers. You may not reproduce, '
          'distribute, or create derivative works without explicit written '
          'permission.',
        ),

        _heading('8. Disclaimer of Warranties'),
        _body(
          'The App is provided "as is" without warranties of any kind. We do not '
          'guarantee that the App will be uninterrupted, error-free, or free of '
          'viruses. Your use of the App is at your own risk.',
        ),

        _heading('9. Limitation of Liability'),
        _body(
          'To the fullest extent permitted by law, GraceWay and its developers '
          'shall not be liable for any indirect, incidental, special, or '
          'consequential damages arising from your use of the App.',
        ),

        _heading('10. Termination'),
        _body(
          'We reserve the right to suspend or terminate your access to the App '
          'at any time for violation of these Terms. You may stop using the App '
          'at any time by deleting it from your device.',
        ),

        _heading('11. Changes to Terms'),
        _body(
          'We may update these Terms from time to time. Continued use of the App '
          'after changes constitutes acceptance of the revised Terms. We will '
          'make reasonable efforts to notify you of material changes.',
        ),

        const SizedBox(height: 32),
        _divider(),
        const SizedBox(height: 32),

        // ── PRIVACY POLICY ─────────────────────────────────────────────────
        _sectionTitle('Privacy Policy'),
        const SizedBox(height: 12),

        _heading('1. What We Collect'),
        _body(
          'We collect only what is necessary to provide the App\'s features:\n\n'
          '• Account information: Your name and email address provided by Apple '
          'or Google Sign In at the time of first sign-in.\n\n'
          '• Habit & practice data: The habits and spiritual practices you '
          'create, your daily check-in entries, timed sessions, counts, and '
          'streak progress.\n\n'
          '• Prayer Circle data: Prayer requests, encouragements, and '
          'participation activity within circles you join or create.\n\n'
          '• App preferences: Notification settings, reminder times, and '
          'onboarding completion status.\n\n'
          '• Device information: Basic device identifiers used by Firebase for '
          'authentication and analytics.',
        ),

        _heading('2. How We Use Your Data'),
        _body(
          '• To sync your habits and progress across your devices.\n'
          '• To enable Prayer Circle collaboration with members you invite.\n'
          '• To send optional daily reminder notifications (only if you enable them).\n'
          '• To restore your purchases and validate premium access.\n'
          '• To improve the App through aggregated, anonymized usage patterns.\n\n'
          'We do not use your data for advertising. We do not sell your data to '
          'third parties. Ever.',
        ),

        _heading('3. Third-Party Services'),
        _body(
          'GraceWay uses the following third-party services, each with its own '
          'privacy policy:\n\n'
          '• Firebase (Google): Authentication, cloud database (Firestore), '
          'and offline data storage.\n'
          '• Apple Sign In: Secure authentication on iOS devices.\n'
          '• Google Sign In: Secure authentication on Android devices.\n'
          '• Apple App Store / Google Play: In-app purchase processing.\n\n'
          'These services may collect certain data as described in their '
          'respective privacy policies.',
        ),

        _heading('4. Data Storage & Security'),
        _body(
          'Your data is stored securely in Google Firebase Firestore, protected '
          'by Firebase Security Rules that ensure only you (and members of your '
          'Prayer Circles) can access your data. Data is encrypted in transit '
          'using industry-standard TLS encryption.',
        ),

        _heading('5. Data Retention'),
        _body(
          'Your data is retained as long as your account exists. If you delete '
          'your account or reset all data within the App, your personal data '
          'will be removed from our servers within 30 days, except where '
          'retention is required by law.',
        ),

        _heading('6. Children\'s Privacy'),
        _body(
          'GraceWay is not directed at children under the age of 13. We do not '
          'knowingly collect personal information from children under 13. If you '
          'believe a child has provided us with personal information, please '
          'contact us and we will delete it promptly.',
        ),

        _heading('7. Your Rights'),
        _body(
          'Depending on your location, you may have the right to:\n'
          '• Access the personal data we hold about you.\n'
          '• Request correction of inaccurate data.\n'
          '• Request deletion of your data.\n'
          '• Withdraw consent at any time.\n\n'
          'To exercise any of these rights, please contact us using the '
          'information below.',
        ),

        _heading('8. Changes to This Policy'),
        _body(
          'We may update this Privacy Policy from time to time. We will notify '
          'you of significant changes through the App or by other reasonable '
          'means. Continued use of the App after changes take effect constitutes '
          'acceptance of the revised policy.',
        ),

        _heading('9. Contact Us'),
        _body(
          'If you have questions about these Terms or this Privacy Policy, '
          'please contact us at:\n\n'
          'Grace Tracker Support\nsupport@gracetracker.com',
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _effectiveDate(String date) {
    return Text(
      'Effective Date: $date',
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withValues(alpha: 0.35),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: GraceWayColor.golden,
      ),
    );
  }

  Widget _heading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: GraceWayColor.warmWhite,
        ),
      ),
    );
  }

  Widget _body(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: Colors.white.withValues(alpha: 0.55),
        height: 1.6,
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 0.5,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}
