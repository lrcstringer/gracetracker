import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onNext;
  const WelcomeScreen({super.key, required this.onNext});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _showGlow = false;
  bool _showTitle = false;
  bool _showTagline = false;
  bool _showVerse = false;
  bool _showButton = false;
  late final AnimationController _breatheController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showGlow = true);
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showTitle = true);
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showTagline = true);
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showVerse = true);
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showButton = true);
    });
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breatheController,
      builder: (context, _) {
        final b = _breatheController.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedOpacity(
              opacity: _showGlow ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 2000),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      GraceWayColor.golden.withValues(alpha: 0.18),
                      GraceWayColor.golden.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    center: const Alignment(0, 0.3),
                    radius: 1.2,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(children: [
                    AnimatedOpacity(
                      opacity: _showTitle ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 600),
                      child: AnimatedScale(
                        scale: _showTitle ? 1.0 : 0.8,
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOut,
                        child: SizedBox(
                          width: 280,
                          height: 280,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(colors: [
                                    Colors.white.withValues(alpha: 0.04 + b * 0.08),
                                    GraceWayColor.golden.withValues(alpha: 0.08 + b * 0.17),
                                    Colors.transparent,
                                  ]),
                                ),
                              ),
                              Text(
                                'Grace Tracker',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  color: GraceWayColor.warmWhite.withValues(alpha: 0.92),
                                  letterSpacing: 1.5,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _showTagline ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 700),
                      child: AnimatedSlide(
                        offset: _showTagline ? Offset.zero : const Offset(0, 0.3),
                        duration: const Duration(milliseconds: 700),
                        child: Text(
                          'A daily walk with God. Track your habits.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: GraceWayColor.softGold.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedOpacity(
                      opacity: _showVerse ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 700),
                      child: AnimatedSlide(
                        offset: _showVerse ? Offset.zero : const Offset(0, 0.4),
                        duration: const Duration(milliseconds: 700),
                        child: Column(children: [
                          Text(
                            '\u201COffer your bodies as a living sacrifice, holy and pleasing to God \u2014 this is your true and proper worship.\u201D',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: GraceWayColor.softGold.withValues(alpha: 0.55),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Romans 12:1',
                            style: TextStyle(fontSize: 12, color: GraceWayColor.golden.withValues(alpha: 0.45)),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
                const Spacer(),
                AnimatedOpacity(
                  opacity: _showButton ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: AnimatedSlide(
                    offset: _showButton ? Offset.zero : const Offset(0, 0.5),
                    duration: const Duration(milliseconds: 600),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: widget.onNext,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text("Let\u2019s begin",
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
                  ),
                ),
                const SizedBox(height: 56),
              ]),
            ),
          ],
        );
      },
    );
  }
}
