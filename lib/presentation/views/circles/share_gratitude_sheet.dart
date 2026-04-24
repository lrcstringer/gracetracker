import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/circle.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../theme/app_theme.dart';

class ShareGratitudeSheet extends StatefulWidget {
  final List<Circle> circles;
  final String? gratitudeText;
  final void Function(List<String> circleIds, bool isAnonymous) onShare;

  const ShareGratitudeSheet({
    super.key,
    required this.circles,
    required this.gratitudeText,
    required this.onShare,
  });

  @override
  State<ShareGratitudeSheet> createState() => _ShareGratitudeSheetState();
}

class _ShareGratitudeSheetState extends State<ShareGratitudeSheet> {
  final Set<String> _selectedIds = {};
  bool _isAnonymous = false;
  bool _isSharing = false;

  bool get _hasMultipleCircles => widget.circles.length > 1;

  @override
  void initState() {
    super.initState();
    if (widget.circles.length == 1) {
      _selectedIds.add(widget.circles.first.id);
    }
  }

  String _previewText(String firstName) {
    final text = widget.gratitudeText;
    if (text != null && text.isNotEmpty) {
      return _isAnonymous ? 'Someone in your circle: $text' : '$firstName: $text';
    }
    return _isAnonymous
        ? 'Someone in your circle gave thanks to God today'
        : '$firstName gave thanks to God today';
  }

  void _share() {
    final ids = _hasMultipleCircles ? _selectedIds.toList() : widget.circles.map((c) => c.id).toList();
    if (ids.isEmpty) return;
    setState(() => _isSharing = true);
    widget.onShare(ids, _isAnonymous);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firstName = auth.displayName?.split(' ').first ?? 'You';

    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Column(children: [
                const Icon(Icons.favorite_rounded, size: 28, color: GraceWayColor.golden),
                const SizedBox(height: 8),
                const Text('Share Your Gratitude',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: GraceWayColor.warmWhite)),
              ]),
            ),
            const SizedBox(height: 24),
            if (_hasMultipleCircles) ...[
              _circleSelector(),
              const SizedBox(height: 20),
            ],
            _anonymityToggle(),
            const SizedBox(height: 20),
            _previewCard(_previewText(firstName)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isSharing || (_hasMultipleCircles && _selectedIds.isEmpty)) ? null : _share,
                icon: _isSharing
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: GraceWayColor.charcoal))
                    : const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GraceWayColor.golden,
                  foregroundColor: GraceWayColor.charcoal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _circleSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SHARE TO',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.2)),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: widget.circles.map((circle) {
            final selected = _selectedIds.contains(circle.id);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _selectedIds.remove(circle.id);
                  } else {
                    _selectedIds.add(circle.id);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? GraceWayColor.golden : GraceWayColor.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: selected ? Colors.transparent : GraceWayColor.cardBorder, width: 0.5),
                  ),
                  child: Text(circle.name,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: selected ? GraceWayColor.charcoal : GraceWayColor.warmWhite)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _anonymityToggle() {
    return Column(children: [
      _toggleRow(
        label: 'Share with your name',
        selected: !_isAnonymous,
        onTap: () => setState(() => _isAnonymous = false),
      ),
      const SizedBox(height: 8),
      _toggleRow(
        label: 'Share anonymously',
        selected: _isAnonymous,
        onTap: () => setState(() => _isAnonymous = true),
      ),
    ]);
  }

  Widget _toggleRow({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? GraceWayColor.golden.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? GraceWayColor.golden.withValues(alpha: 0.2) : GraceWayColor.cardBorder,
              width: 0.5),
        ),
        child: Row(children: [
          Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20, color: selected ? GraceWayColor.golden : Colors.white.withValues(alpha: 0.4)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 14, color: GraceWayColor.warmWhite)),
        ]),
      ),
    );
  }

  Widget _previewCard(String text) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('PREVIEW',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.4), letterSpacing: 1.2)),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF353548), width: 1),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 14, height: 1.5,
                color: GraceWayColor.warmWhite.withValues(alpha: 0.8))),
      ),
    ]);
  }
}
