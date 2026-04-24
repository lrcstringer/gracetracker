import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class FirstGratitudeScreen extends StatefulWidget {
  final void Function(String?) onComplete;
  const FirstGratitudeScreen({super.key, required this.onComplete});

  @override
  State<FirstGratitudeScreen> createState() => _FirstGratitudeScreenState();
}

class _FirstGratitudeScreenState extends State<FirstGratitudeScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  bool _hasCompleted = false;
  bool _showPulse = false;
  bool _showResult = false;
  late final AnimationController _lightController;
  late final Animation<double> _lightOpacity;
  late final Animation<double> _lightRise;

  @override
  void initState() {
    super.initState();
    _lightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _lightOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _lightController, curve: Curves.easeIn),
    );
    _lightRise = Tween<double>(begin: 0.0, end: -180.0).animate(
      CurvedAnimation(parent: _lightController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _lightController.dispose();
    super.dispose();
  }

  void _complete() {
    setState(() {
      _hasCompleted = true;
      _showPulse = true;
    });
    _lightController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showResult = true);
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showPulse = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Every journey starts\nwith gratitude.',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite, height: 1.3),
            ),
            const SizedBox(height: 10),
            Text(
              'Your first habit is already set \u2014 a daily moment to thank God for something. It takes a few seconds. It changes everything.',
              style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5), height: 1.5),
            ),
            const SizedBox(height: 24),
            if (!_hasCompleted) _inputSection(),
            if (_hasCompleted) _completedSection(),
          ]),
        ),
      ),
      if (_hasCompleted)
        AnimatedOpacity(
          opacity: _showResult ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 500),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final note = _controller.text.trim().isEmpty ? null : _controller.text.trim();
                  widget.onComplete(note);
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Continue',
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
    ]);
  }

  Widget _inputSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        'Let\u2019s do your first one right now.',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: GraceWayColor.softGold),
      ),
      const SizedBox(height: 12),
      Text(
        'What\u2019s one thing you\u2019re grateful to God for today?',
        style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.5)),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _controller,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 15, color: GraceWayColor.warmWhite),
        decoration: InputDecoration(
          hintText: 'Something you\u2019re thankful for...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 15),
          filled: true,
          fillColor: GraceWayColor.cardBackground,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _complete,
          icon: const Icon(Icons.favorite_rounded, size: 14),
          label: Text(
            _controller.text.trim().isEmpty ? 'Thank you, Lord' : 'Give thanks',
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
    ]);
  }

  Widget _completedSection() {
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        if (_showPulse)
          AnimatedBuilder(
            animation: _lightController,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _lightRise.value),
              child: Opacity(
                opacity: _lightOpacity.value,
                child: Container(
                  width: 160, height: 160,
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
          ),
        AnimatedOpacity(
          opacity: _showResult ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 600),
          child: AnimatedScale(
            scale: _showResult ? 1.0 : 0.9,
            duration: const Duration(milliseconds: 600),
            child: Column(children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    GraceWayColor.golden.withValues(alpha: 0.3),
                    GraceWayColor.golden.withValues(alpha: 0.08),
                  ]),
                ),
                child: const Icon(Icons.volunteer_activism, size: 32, color: GraceWayColor.golden),
              ),
              const SizedBox(height: 12),
              const Text('1',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: GraceWayColor.golden)),
              const Text('day of gratitude',
                  style: TextStyle(fontSize: 15, color: GraceWayColor.softGold)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 24),
      AnimatedOpacity(
        opacity: _showResult ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        child: const Text(
          'That\u2019s your first check-in. It\u2019s received.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite),
        ),
      ),
      const SizedBox(height: 20),
      AnimatedOpacity(
        opacity: _showResult ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        child: Column(children: [
          Text(
            '\u201CGive thanks in all circumstances; for this is God\u2019s will for you in Christ Jesus.\u201D',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14, fontStyle: FontStyle.italic, height: 1.6,
              color: GraceWayColor.softGold.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text('1 Thessalonians 5:18',
              style: TextStyle(fontSize: 12, color: GraceWayColor.golden.withValues(alpha: 0.5))),
        ]),
      ),
    ]);
  }
}
