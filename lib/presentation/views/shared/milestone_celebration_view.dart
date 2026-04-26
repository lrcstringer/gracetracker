import 'package:flutter/material.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/services/milestone_service.dart';
import '../../theme/app_theme.dart';

class MilestoneCelebrationView extends StatefulWidget {
  final Milestone milestone;
  final VoidCallback onDismiss;
  final HabitTrackingType? trackingType;

  const MilestoneCelebrationView({
    super.key,
    required this.milestone,
    required this.onDismiss,
    this.trackingType,
  });

  @override
  State<MilestoneCelebrationView> createState() => _MilestoneCelebrationViewState();
}

class _MilestoneCelebrationViewState extends State<MilestoneCelebrationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _burstScale;
  late final Animation<double> _burstOpacity;
  late final Animation<double> _contentScale;
  late final Animation<double> _contentOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

    _burstScale = Tween(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _burstOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.3), weight: 75),
    ]).animate(CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0)));

    _contentScale = Tween(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.45, curve: Curves.easeOut)),
    );
    _contentOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.45)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() async {
    await _controller.reverse(from: 0.3);
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _dismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: _burstScale.value,
                    child: Opacity(
                      opacity: _burstOpacity.value,
                      child: Container(
                        width: 360,
                        height: 360,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: GraceWayColor.golden.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: _burstScale.value * 0.8,
                    child: Opacity(
                      opacity: _burstOpacity.value * 0.5,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: GraceWayColor.golden.withValues(alpha: 0.15),
                        ),
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: _contentScale.value,
                    child: Opacity(
                      opacity: _contentOpacity.value,
                      child: _content(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _milestoneIcon() {
    switch (widget.trackingType) {
      case HabitTrackingType.abstain:
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (_, t, _) => ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [GraceWayColor.golden, GraceWayColor.golden, GraceWayColor.softGold.withValues(alpha: 0.3)],
              stops: [0.0, t.clamp(0.0, 1.0), t.clamp(0.0, 1.0)],
            ).createShader(bounds),
            child: const Icon(Icons.shield_rounded, size: 48, color: Colors.white),
          ),
        );
      case HabitTrackingType.count:
        final target = widget.milestone.threshold.toInt();
        final start = (target * 0.88).toInt();
        return TweenAnimationBuilder<int>(
          tween: IntTween(begin: start, end: target),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (_, v, _) => Text(
            '$v',
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: GraceWayColor.golden,
            ),
          ),
        );
      case HabitTrackingType.timed:
        return const Icon(Icons.timer_rounded, color: GraceWayColor.golden, size: 44);
      default:
        return const Icon(Icons.star_rounded, color: GraceWayColor.golden, size: 44);
    }
  }

  Widget _content() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _milestoneIcon(),
          const SizedBox(height: 12),
          Text(
            'MILESTONE REACHED',
            style: TextStyle(
              color: GraceWayColor.softGold.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.milestone.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: GraceWayColor.warmWhite,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _dismiss,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              decoration: BoxDecoration(
                color: GraceWayColor.golden,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: GraceWayColor.charcoal,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
