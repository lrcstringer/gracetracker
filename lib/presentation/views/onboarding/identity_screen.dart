import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class IdentityScreen extends StatefulWidget {
  final void Function(String name, List<String> selections) onContinue;
  final VoidCallback onSkip;
  final String? prefilledName;

  const IdentityScreen({
    super.key,
    required this.onContinue,
    required this.onSkip,
    this.prefilledName,
  });

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  late final TextEditingController _ctrl;

  bool get _canContinue => _ctrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.prefilledName ?? '');
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_canContinue) return;
    widget.onContinue(_ctrl.text.trim(), const []);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What should we\ncall you?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: GraceWayColor.warmWhite,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "We\u2019ll use your first name to personalise your experience.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _continue(),
                style: const TextStyle(
                  color: GraceWayColor.warmWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Your first name',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontWeight: FontWeight.w400,
                  ),
                  filled: true,
                  fillColor: GraceWayColor.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: GraceWayColor.cardBorder, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: GraceWayColor.cardBorder, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: GraceWayColor.golden.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _canContinue ? _continue : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: GraceWayColor.golden,
              foregroundColor: GraceWayColor.charcoal,
              disabledBackgroundColor: GraceWayColor.golden.withValues(alpha: 0.25),
              disabledForegroundColor: GraceWayColor.charcoal.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    ]);
  }
}
