import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/remote/auth_service.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../theme/app_theme.dart';

class ProfileEditView extends StatefulWidget {
  const ProfileEditView({super.key});

  @override
  State<ProfileEditView> createState() => _ProfileEditViewState();
}

class _ProfileEditViewState extends State<ProfileEditView> {
  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _prefill() async {
    final auth = AuthService.shared;
    _firstNameController.text = auth.givenName ?? '';
    _displayNameController.text = auth.displayName ?? '';
    _emailController.text = auth.email ?? '';

    try {
      final profile = await context.read<UserRepository>().getProfile();
      if (profile != null) {
        _surnameController.text = profile.surname ?? '';
        _phoneController.text = profile.phone ?? '';
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) {
      setState(() => _error = 'Display name cannot be empty.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await AuthService.shared.updateProfile(
      firstName: _firstNameController.text.trim(),
      surname: _surnameController.text.trim(),
      displayName: displayName,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: GraceWayColor.warmWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GraceWayColor.golden))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField(
                    label: 'First Name',
                    controller: _firstNameController,
                    hint: 'e.g. John',
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    label: 'Surname',
                    controller: _surnameController,
                    hint: 'e.g. Smith',
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    label: 'Display Name',
                    controller: _displayNameController,
                    hint: 'How your name appears to others',
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    label: 'Email',
                    controller: _emailController,
                    hint: 'your@email.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    label: 'Phone',
                    controller: _phoneController,
                    hint: '+27 82 123 4567',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Phone and email are stored privately and not shared with other users.',
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  const SizedBox(height: 28),
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: const TextStyle(fontSize: 13, color: GraceWayColor.warmCoral),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GraceWayColor.golden,
                        disabledBackgroundColor: GraceWayColor.golden.withValues(alpha: 0.4),
                        foregroundColor: GraceWayColor.charcoal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: GraceWayColor.charcoal,
                              ),
                            )
                          : const Text(
                              'Save',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: GraceWayColor.warmWhite),
          decoration: InputDecoration(
            filled: true,
            fillColor: GraceWayColor.cardBackground,
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: GraceWayColor.sage, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}
