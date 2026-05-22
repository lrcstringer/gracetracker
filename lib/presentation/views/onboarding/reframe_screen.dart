import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../shared/golden_pulse_view.dart';

class ReframeScreen extends StatefulWidget {
  final VoidCallback onNext;
  const ReframeScreen({super.key, required this.onNext});

  @override
  State<ReframeScreen> createState() => _ReframeScreenState();
}

class _ReframeScreenState extends State<ReframeScreen> {
  bool _showLeft = false;
  bool _showRight = false;
  bool _showPoints = false;
  bool _showPulse = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showLeft = true);
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showRight = true);
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showPoints = true);
    });
  }

  void _onContinue() {
    setState(() => _showPulse = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) widget.onNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Grace Tracker works\na bit differently.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite, height: 1.3),
            ),
            const SizedBox(height: 28),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: AnimatedOpacity(
                  opacity: _showLeft ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: AnimatedSlide(
                    offset: _showLeft ? Offset.zero : const Offset(-0.3, 0),
                    duration: const Duration(milliseconds: 500),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Other apps',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.5))),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: GraceWayColor.warmCoral.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GraceWayColor.warmCoral.withValues(alpha: 0.15), width: 0.5),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('Day 47',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: GraceWayColor.warmCoral,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: GraceWayColor.warmCoral,
                                )),
                            const SizedBox(height: 6),
                            Text('Streak broken.',
                                style: TextStyle(fontSize: 12, color: GraceWayColor.warmCoral.withValues(alpha: 0.8))),
                            const SizedBox(height: 8),
                            Icon(Icons.cancel_rounded, size: 28, color: GraceWayColor.warmCoral.withValues(alpha: 0.6)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedOpacity(
                  opacity: _showRight ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 500),
                  child: AnimatedSlide(
                    offset: _showRight ? Offset.zero : const Offset(0.3, 0),
                    duration: const Duration(milliseconds: 500),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Grace Tracker',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GraceWayColor.golden)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: GraceWayColor.golden.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.2), width: 0.5),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(7, (i) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Container(
                                  width: 14, height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i < 5
                                        ? GraceWayColor.golden
                                        : Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                              )),
                            ),
                            const SizedBox(height: 6),
                            const Text('5 out of 7',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: GraceWayColor.golden)),
                            const SizedBox(height: 4),
                            const Text('Great week.', style: TextStyle(fontSize: 12, color: GraceWayColor.sage)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ])),
            const SizedBox(height: 28),
            AnimatedOpacity(
              opacity: _showPoints ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: AnimatedSlide(
                offset: _showPoints ? Offset.zero : const Offset(0, 0.2),
                duration: const Duration(milliseconds: 500),
                child: Column(children: [
                  _reframePoint(Icons.favorite_rounded, 'Most apps track your performance. Grace Tracker tracks what you\u2019re giving to God.'),
                  _reframePoint(Icons.refresh_rounded, 'No streaks. Every week is a fresh start. 5 out of 7 is still a gift.'),
                  _reframePoint(Icons.back_hand_rounded, 'We\u2019ll never tell you that you failed. We\u2019ll meet you wherever you are.'),

                ]),
              ),
            ),
            const SizedBox(height: 28),
            Column(children: [
              Text(
                '\u201CThe steadfast love of the Lord never ceases; his mercies never come to an end; they are new every morning.\u201D',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, fontStyle: FontStyle.italic, height: 1.6,
                  color: GraceWayColor.softGold.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text('Lamentations 3:22-23',
                  style: TextStyle(fontSize: 12, color: GraceWayColor.golden.withValues(alpha: 0.5))),
            ]),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showPulse ? null : _onContinue,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text("Got it, let\u2019s get started",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: GraceWayColor.golden,
              foregroundColor: GraceWayColor.charcoal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    ]),
    if (_showPulse)
      const Positioned.fill(
        child: IgnorePointer(
          child: Center(child: GoldenPulseView()),
        ),
      ),
    ]);
  }

  Widget _reframePoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 20,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: GraceWayColor.golden),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5), height: 1.5)),
        ),
      ]),
    );
  }
}
