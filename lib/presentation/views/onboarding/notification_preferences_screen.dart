import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/local/notification_service.dart';
import '../../../domain/repositories/user_preferences_repository.dart';
import '../../theme/app_theme.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  final VoidCallback onNext;
  const NotificationPreferencesScreen({super.key, required this.onNext});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  bool _remindersEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  Future<void> _savePreferences() async {
    final userPrefs = context.read<UserPreferencesRepository>();
    await userPrefs.setBool('tribute_reminders_enabled', _remindersEnabled);
    await userPrefs.setInt('tribute_reminder_hour', _reminderTime.hour);
    await userPrefs.setInt('tribute_reminder_minute', _reminderTime.minute);
  }

  Future<void> _handleContinue() async {
    try {
      if (_remindersEnabled) {
        await NotificationService.shared.requestAuthorization();
        await _savePreferences();
        if (NotificationService.shared.isAuthorized) {
          await NotificationService.shared.scheduleDailyReminders();
        }
      } else {
        await _savePreferences();
      }
    } catch (_) {
      // Always advance — notification permission errors must not block onboarding.
    }
    widget.onNext();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: GraceWayColor.golden),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _reminderTime = picked);
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: AnimatedOpacity(
          opacity: _showContent ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: AnimatedSlide(
            offset: _showContent ? Offset.zero : const Offset(0, 0.1),
            duration: const Duration(milliseconds: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(
                  'Stay on track,\ngently.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite, height: 1.3),
                ),
                const SizedBox(height: 10),
                Text(
                  'We\u2019ll send a gentle nudge \u2014 never guilt. Just a quiet reminder that your walk is waiting.',
                  style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5), height: 1.5),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: GraceWayColor.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: GraceWayColor.cardBorder, width: 0.5),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Daily Reminders',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
                        const SizedBox(height: 4),
                        Text('A small prompt at the time you choose',
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                      ]),
                    ),
                    Switch(
                      value: _remindersEnabled,
                      onChanged: (v) => setState(() => _remindersEnabled = v),
                      activeThumbColor: GraceWayColor.golden,
                      activeTrackColor: GraceWayColor.golden.withValues(alpha: 0.3),
                    ),
                  ]),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: _remindersEnabled
                      ? Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: GraceWayColor.cardBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: GraceWayColor.cardBorder, width: 0.5),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Remind me at',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                                      color: GraceWayColor.softGold.withValues(alpha: 0.6))),
                              const SizedBox(height: 12),
                              GestureDetector(
                                onTap: _pickTime,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: GraceWayColor.golden.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.2), width: 0.5),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.access_time_rounded, size: 18, color: GraceWayColor.golden),
                                    const SizedBox(width: 10),
                                    Text(_formatTime(_reminderTime),
                                        style: const TextStyle(
                                          fontSize: 20, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite,
                                        )),
                                    const Spacer(),
                                    Text('tap to change',
                                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.3))),
                                  ]),
                                ),
                              ),
                            ]),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Icon(Icons.notifications_rounded, size: 14,
                      color: GraceWayColor.golden.withValues(alpha: 0.5)),
                  const SizedBox(width: 10),
                  Text('You can change this anytime in Settings.',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                ]),
                const SizedBox(height: 24),
                Column(children: [
                  Text(
                    '\u201CCommit to the Lord whatever you do, and he will establish your plans.\u201D',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14, fontStyle: FontStyle.italic, height: 1.6,
                      color: GraceWayColor.softGold.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Proverbs 16:3',
                      style: TextStyle(fontSize: 12, color: GraceWayColor.golden.withValues(alpha: 0.5))),
                ]),
              ]),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleContinue,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: Text(
                _remindersEnabled ? 'Enable Reminders' : 'Continue',
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
          if (_remindersEnabled) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                setState(() => _remindersEnabled = false);
                await _savePreferences();
                widget.onNext();
              },
              child: Text('Skip for now',
                  style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5))),
            ),
          ],
        ]),
      ),
    ]);
  }
}
