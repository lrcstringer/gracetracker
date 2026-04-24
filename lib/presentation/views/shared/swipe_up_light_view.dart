import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Full-screen warm golden light that rises from bottom to top, ending in a
/// golden burst at the top. The core visual motif described in §2.3 of the spec.
/// Auto-plays on mount; optionally calls [onComplete] when finished.
class SwipeUpLightView extends StatefulWidget {
  final VoidCallback? onComplete;
  final Duration duration;

  const SwipeUpLightView({
    super.key,
    this.onComplete,
    this.duration = const Duration(milliseconds: 1300),
  });

  @override
  State<SwipeUpLightView> createState() => _SwipeUpLightViewState();
}

class _SwipeUpLightViewState extends State<SwipeUpLightView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Light column rises from y=0 (bottom) to y=-1 (top of screen)
  late final Animation<double> _rise;

  // Opacity: fade in → hold → fade out
  late final Animation<double> _opacity;

  // Burst expands at the top in the final third
  late final Animation<double> _burstScale;
  late final Animation<double> _burstOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    _rise = Tween<double>(begin: 0.0, end: -1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.85), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.85), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 0.0), weight: 30),
    ]).animate(_ctrl);

    _burstScale = Tween<double>(begin: 0.0, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.65, 1.0, curve: Curves.easeOut)),
    );

    _burstOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.7), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 0.0), weight: 20),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Stack(
              children: [
                // Rising light column
                Transform.translate(
                  offset: Offset(0, _rise.value * h),
                  child: Opacity(
                    opacity: _opacity.value,
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.transparent,
                              GraceWayColor.golden.withValues(alpha: 0.08),
                              GraceWayColor.golden.withValues(alpha: 0.25),
                              GraceWayColor.softGold.withValues(alpha: 0.55),
                            ],
                            stops: const [0.0, 0.4, 0.75, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Golden burst at top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Opacity(
                    opacity: _burstOpacity.value,
                    child: Transform.scale(
                      scale: _burstScale.value,
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.topCenter,
                            radius: 1.0,
                            colors: [
                              GraceWayColor.softGold.withValues(alpha: 0.8),
                              GraceWayColor.golden.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Mini variant of [SwipeUpLightView] — a small rising circle of light.
/// Used in Screen 4 (first gratitude) and other compact contexts.
class MiniSwipeUpLightView extends StatefulWidget {
  final Duration duration;

  const MiniSwipeUpLightView({
    super.key,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<MiniSwipeUpLightView> createState() => _MiniSwipeUpLightViewState();
}

class _MiniSwipeUpLightViewState extends State<MiniSwipeUpLightView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rise;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _rise = Tween<double>(begin: 0.0, end: -180.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Transform.translate(
        offset: Offset(0, _rise.value),
        child: Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                GraceWayColor.golden.withValues(alpha: 0.35),
                GraceWayColor.golden.withValues(alpha: 0.08),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
