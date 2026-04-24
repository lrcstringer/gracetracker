import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/repositories/circle_repository.dart';
import '../../theme/app_theme.dart';

class JoinCircleView extends StatefulWidget {
  final String? initialCode;
  final Future<void> Function()? onJoined;

  const JoinCircleView({super.key, this.initialCode, this.onJoined});

  @override
  State<JoinCircleView> createState() => _JoinCircleViewState();
}

class _JoinCircleViewState extends State<JoinCircleView> {
  late final TextEditingController _codeController;
  bool _isLoading = false;
  String? _error;
  String? _joinedName;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinCircle() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await context.read<CircleRepository>().joinCircle(code);
      if (!mounted) return;
      if (response.alreadyMember) {
        setState(() { _error = "You're already a member of this circle"; _isLoading = false; });
      } else {
        setState(() { _joinedName = response.name; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        title: const Text('Join Circle',
            style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 17, fontWeight: FontWeight.w600)),
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
        ),
        leadingWidth: 80,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _joinedName != null ? _successState() : _formState(),
        ),
      ),
    );
  }

  Widget _successState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: GraceWayColor.sage.withValues(alpha: 0.12),
          ),
          child: const Icon(Icons.check_circle_rounded, size: 36, color: GraceWayColor.sage),
        ),
        const SizedBox(height: 16),
        Text('Joined $_joinedName!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: GraceWayColor.warmWhite)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await widget.onJoined?.call();
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GraceWayColor.golden,
              foregroundColor: GraceWayColor.charcoal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _formState() {
    final isEmpty = _codeController.text.trim().isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Invite Code',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
        const SizedBox(height: 6),
        TextField(
          controller: _codeController,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          style: const TextStyle(color: GraceWayColor.warmWhite),
          decoration: InputDecoration(
            hintText: 'Enter invite code',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: GraceWayColor.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: GraceWayColor.cardBorder, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: GraceWayColor.cardBorder, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: GraceWayColor.golden.withValues(alpha: 0.5), width: 1),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ask the circle creator for their invite code, or tap a shared invite link.',
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.warning_amber, size: 14, color: GraceWayColor.warmCoral),
            const SizedBox(width: 6),
            Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: GraceWayColor.warmCoral))),
          ]),
        ],
        const SizedBox(height: 24),
        Opacity(
          opacity: isEmpty ? 0.5 : 1.0,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (isEmpty || _isLoading) ? null : _joinCircle,
              style: ElevatedButton.styleFrom(
                backgroundColor: GraceWayColor.golden,
                foregroundColor: GraceWayColor.charcoal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: GraceWayColor.charcoal))
                  : const Text('Join Circle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }
}
