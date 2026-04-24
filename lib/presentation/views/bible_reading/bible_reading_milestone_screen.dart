import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class BibleReadingMilestoneScreen extends StatefulWidget {
  final int weekIndex; // 0-indexed

  const BibleReadingMilestoneScreen({super.key, required this.weekIndex});

  @override
  State<BibleReadingMilestoneScreen> createState() =>
      _BibleReadingMilestoneScreenState();
}

class _BibleReadingMilestoneScreenState
    extends State<BibleReadingMilestoneScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _raysAnim;
  late final Animation<double> _contentFade;
  late final Animation<double> _contentScale;
  bool _showMessage = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _raysAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _contentFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
    );
    _contentScale = Tween(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showMessage = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _milestoneInfo(widget.weekIndex);

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Light rays background
            AnimatedBuilder(
              animation: _raysAnim,
              builder: (context, _) => CustomPaint(
                painter: _LightRaysPainter(progress: _raysAnim.value),
                size: Size.infinite,
              ),
            ),
            // Content
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Transform.scale(
                  scale: _contentScale.value,
                  child: Opacity(
                    opacity: _contentFade.value,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: GraceWayColor.golden.withValues(alpha: 0.15),
                              border: Border.all(
                                color: GraceWayColor.golden.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.menu_book_rounded,
                                color: GraceWayColor.golden,
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            info.label.toUpperCase(),
                            style: TextStyle(
                              color: GraceWayColor.softGold.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            info.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: GraceWayColor.warmWhite,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          AnimatedOpacity(
                            opacity: _showMessage ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              info.scripture,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: GraceWayColor.softGold.withValues(alpha: 0.75),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          AnimatedOpacity(
                            opacity: _showMessage ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 500),
                            child: Text(
                              'Tap anywhere to continue',
                              style: TextStyle(
                                color: GraceWayColor.softGold.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _MilestoneInfo _milestoneInfo(int weekIndex) {
    switch (weekIndex) {
      case 0: // Week 1 complete
        return const _MilestoneInfo(
          label: 'Week 1 complete',
          message:
              'A fantastic start to your reading journey. Keep it up — there are fascinating stories and wonderful Scripture ahead.',
          scripture:
              '"Blessed is the one who reads aloud the words of this prophecy." — Revelation 1:3',
        );
      case 9: // Weeks 1–10 complete
        return const _MilestoneInfo(
          label: 'Ten weeks complete',
          message:
              'Ten weeks in. You have built something real. The Word is taking root.',
          scripture:
              '"Your word is a lamp to my feet and a light to my path." — Psalm 119:105',
        );
      case 19: // Weeks 1–20 complete
        return const _MilestoneInfo(
          label: 'Twenty weeks complete',
          message:
              'Nearly halfway. You are walking faithfully through Scripture week after week.',
          scripture:
              '"I have stored up your word in my heart, that I might not sin against you." — Psalm 119:11',
        );
      case 29: // Weeks 1–30 complete
        return const _MilestoneInfo(
          label: 'Thirty weeks complete',
          message:
              'Thirty weeks of faithful reading. The whole sweep of God\'s story is unfolding before you.',
          scripture:
              '"The unfolding of your words gives light; it imparts understanding to the simple." — Psalm 119:130',
        );
      case 39: // Weeks 1–40 complete
        return const _MilestoneInfo(
          label: 'Forty weeks complete',
          message:
              'Forty weeks. The finish line is in sight. Press on — the glory ahead is worth every page.',
          scripture:
              '"Heaven and earth will pass away, but my words will not pass away." — Matthew 24:35',
        );
      case 51: // Complete — all 52 weeks
        return const _MilestoneInfo(
          label: 'Bible in a Year — complete',
          message:
              'You have read through the entire Bible. This is a remarkable achievement. May these words dwell in you richly.',
          scripture:
              '"All Scripture is breathed out by God and profitable for teaching, for reproof, for correction, and for training in righteousness." — 2 Timothy 3:16',
        );
      default:
        return _MilestoneInfo(
          label: 'Week ${weekIndex + 1} complete',
          message: 'Another week of faithful reading. Well done.',
          scripture: '"His mercies are new every morning." — Lamentations 3:23',
        );
    }
  }
}

// ── Milestone info ────────────────────────────────────────────────────────────

class _MilestoneInfo {
  final String label;
  final String message;
  final String scripture;
  const _MilestoneInfo({
    required this.label,
    required this.message,
    required this.scripture,
  });
}

// ── Light rays painter ────────────────────────────────────────────────────────

class _LightRaysPainter extends CustomPainter {
  final double progress;
  static const int _rayCount = 16;

  const _LightRaysPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height * 0.42);
    final maxRadius = size.longestSide * 0.9;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < _rayCount; i++) {
      final angle = (2 * math.pi / _rayCount) * i;
      // Alternate wide/narrow rays.
      final halfAngle = i.isEven ? 0.055 : 0.025;
      final opacity = (i.isEven ? 0.07 : 0.04) * progress;

      paint.color = GraceWayColor.golden.withValues(alpha: opacity);

      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + maxRadius * math.cos(angle - halfAngle),
        center.dy + maxRadius * math.sin(angle - halfAngle),
      );
      path.lineTo(
        center.dx + maxRadius * math.cos(angle + halfAngle),
        center.dy + maxRadius * math.sin(angle + halfAngle),
      );
      path.close();
      canvas.drawPath(path, paint);
    }

    // Soft central glow.
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          GraceWayColor.golden.withValues(alpha: 0.18 * progress),
          GraceWayColor.golden.withValues(alpha: 0.06 * progress),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.5));
    canvas.drawCircle(center, maxRadius * 0.5, glowPaint);
  }

  @override
  bool shouldRepaint(_LightRaysPainter old) => old.progress != progress;
}

