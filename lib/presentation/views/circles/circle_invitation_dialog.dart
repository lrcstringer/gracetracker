import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/repositories/circle_repository.dart';
import '../../../presentation/theme/app_theme.dart';

/// Bottom-sheet dialog shown when the user opens a `graceway://join?code=XXXX`
/// deep link. Lets them accept or decline the Prayer Circle invitation without
/// having to navigate anywhere manually.
class CircleInvitationDialog extends StatefulWidget {
  final String inviteCode;

  const CircleInvitationDialog({super.key, required this.inviteCode});

  /// Shows the dialog as a modal bottom sheet. Returns `true` if the user
  /// successfully joined (or was already a member), `false`/`null` otherwise.
  static Future<bool?> show(BuildContext context, String inviteCode) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: GraceWayColor.charcoal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CircleInvitationDialog(inviteCode: inviteCode),
    );
  }

  @override
  State<CircleInvitationDialog> createState() => _CircleInvitationDialogState();
}

enum _JoinState { idle, loading, success, error }

class _CircleInvitationDialogState extends State<CircleInvitationDialog> {
  _JoinState _state = _JoinState.idle;
  String? _circleName;
  String? _errorMessage;

  Future<void> _accept() async {
    setState(() => _state = _JoinState.loading);
    try {
      final result = await context
          .read<CircleRepository>()
          .joinCircle(widget.inviteCode);
      if (mounted) {
        setState(() {
          _state = _JoinState.success;
          _circleName = result.name;
        });
        // Auto-dismiss after 2 seconds so the user sees the confirmation.
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _JoinState.error;
          _errorMessage = 'Could not join the circle. Please check the invite link and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _JoinState.loading:
        return _loadingState();
      case _JoinState.success:
        return _successState();
      case _JoinState.error:
        return _errorState();
      case _JoinState.idle:
        return _idleState();
    }
  }

  Widget _idleState() {
    return Column(
      key: const ValueKey('idle'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Icon
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: GraceWayColor.golden.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_add_rounded,
                color: GraceWayColor.golden, size: 28),
          ),
        ),
        const SizedBox(height: 20),
        // Title
        Text(
          'You\'ve been invited to a Prayer Circle',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: GraceWayColor.warmWhite,
                height: 1.3,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Join to walk together, share gratitude, and support each other.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: GraceWayColor.softGold,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 32),
        // Accept button
        FilledButton(
          onPressed: _accept,
          style: FilledButton.styleFrom(
            backgroundColor: GraceWayColor.golden,
            foregroundColor: GraceWayColor.charcoal,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Join the Circle',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        const SizedBox(height: 12),
        // Decline button
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: GraceWayColor.softGold,
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('Not right now'),
        ),
      ],
    );
  }

  Widget _loadingState() {
    return const SizedBox(
      key: ValueKey('loading'),
      height: 160,
      child: Center(
        child: CircularProgressIndicator(color: GraceWayColor.golden),
      ),
    );
  }

  Widget _successState() {
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.check_circle_rounded,
            color: GraceWayColor.sage, size: 56),
        const SizedBox(height: 16),
        Text(
          _circleName != null
              ? 'You\'ve joined "$_circleName"'
              : 'You\'ve joined the circle!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: GraceWayColor.warmWhite,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Walk together in faith.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: GraceWayColor.softGold,
              ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _errorState() {
    return Column(
      key: const ValueKey('error'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Center(
          child: Icon(Icons.error_outline_rounded,
              color: GraceWayColor.warmCoral, size: 48),
        ),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: GraceWayColor.softGold,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: GraceWayColor.softGold),
          child: const Text('Close'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
