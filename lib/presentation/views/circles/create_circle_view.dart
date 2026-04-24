import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/repositories/circle_repository.dart';
import '../../../domain/entities/circle.dart';
import '../../theme/app_theme.dart';

class CreateCircleView extends StatefulWidget {
  final void Function(Circle)? onCreated;

  const CreateCircleView({super.key, this.onCreated});

  @override
  State<CreateCircleView> createState() => _CreateCircleViewState();
}

class _CreateCircleViewState extends State<CreateCircleView> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createCircle() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await context.read<CircleRepository>().createCircle(
        name,
        description: _descController.text.trim(),
      );
      if (!mounted) return;
      widget.onCreated?.call(response);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameEmpty = _nameController.text.trim().isEmpty;
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        title: const Text('New Circle',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Circle Name',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
              const SizedBox(height: 6),
              _textField(_nameController, 'e.g. Family Prayer', maxLines: 1),
              const SizedBox(height: 16),
              const Text('Description',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GraceWayColor.softGold)),
              const SizedBox(height: 6),
              _textField(_descController, 'Optional — what is this circle about?', maxLines: 3),
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
                opacity: nameEmpty ? 0.5 : 1.0,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (nameEmpty || _isLoading) ? null : _createCircle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GraceWayColor.golden,
                      foregroundColor: GraceWayColor.charcoal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: GraceWayColor.charcoal))
                        : const Text('Create Circle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      maxLines: maxLines,
      style: const TextStyle(color: GraceWayColor.warmWhite),
      decoration: InputDecoration(
        hintText: hint,
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
    );
  }
}
