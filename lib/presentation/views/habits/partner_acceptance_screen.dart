import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/accountability_partnership.dart';
import '../../providers/accountability_provider.dart';
import '../../theme/app_theme.dart';

/// Shown when the user taps a partner invite deep link.
/// Handles all token edge cases: not found, already used, caller is owner.
class PartnerAcceptanceScreen extends StatefulWidget {
  final String token;

  const PartnerAcceptanceScreen({super.key, required this.token});

  @override
  State<PartnerAcceptanceScreen> createState() =>
      _PartnerAcceptanceScreenState();
}

class _PartnerAcceptanceScreenState extends State<PartnerAcceptanceScreen> {
  AccountabilityPartnership? _partnership;
  bool _loading = true;
  bool _acting = false;
  String? _errorMessage;
  bool _done = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _loadPartnership();
  }

  Future<void> _loadPartnership() async {
    try {
      final provider = context.read<AccountabilityProvider>();
      final p = await provider.findByToken(widget.token);
      if (!mounted) return;
      // Detect own invite before showing Accept button.
      if (p != null && p.ownerId == provider.currentUserId) {
        setState(() {
          _loading = false;
          _errorMessage = 'This is your own invite link. Share it with a friend to invite them as your prayer partner.';
        });
        return;
      }
      setState(() {
        _partnership = p;
        _loading = false;
        if (p == null) _errorMessage = 'This invite link is no longer valid.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _accept() async {
    setState(() => _acting = true);
    try {
      await context.read<AccountabilityProvider>().acceptViaToken(widget.token);
      if (!mounted) return;
      setState(() { _done = true; _accepted = true; _acting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _acting = false;
        _errorMessage = 'Could not accept invite. It may have already been used.';
      });
    }
  }

  Future<void> _decline() async {
    setState(() => _acting = true);
    try {
      await context.read<AccountabilityProvider>().declineViaToken(widget.token);
      if (!mounted) return;
      setState(() { _done = true; _accepted = false; _acting = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _acting = false; });
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        foregroundColor: GraceWayColor.warmWhite,
        title: const Text('Support Partner Invite',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        leading: _done
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: GraceWayColor.golden))
            : _done
                ? _doneState()
                : _errorMessage != null && _partnership == null
                    ? _errorState()
                    : _inviteState(),
      ),
    );
  }

  Widget _inviteState() {
    final p = _partnership!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        // Header
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                GraceWayColor.sage.withValues(alpha: 0.25),
                GraceWayColor.sage.withValues(alpha: 0.06),
              ]),
            ),
            child: const Icon(Icons.handshake_rounded, size: 32,
                color: GraceWayColor.sage),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '${p.ownerDisplayName} wants you to walk with them',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600,
                color: GraceWayColor.warmWhite, height: 1.3),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Habit: ${p.habitName}',
            style: TextStyle(
                fontSize: 14, color: GraceWayColor.softGold.withValues(alpha: 0.8)),
          ),
        ),
        const SizedBox(height: 28),

        // Legal disclaimer (verbatim from spec §4.2)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: GraceWayColor.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: GraceWayColor.warmWhite.withValues(alpha: 0.08), width: 0.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.info_outline_rounded, size: 13,
                  color: GraceWayColor.softGold),
              const SizedBox(width: 6),
              Text('Before you accept',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GraceWayColor.softGold.withValues(alpha: 0.8))),
            ]),
            const SizedBox(height: 10),
            Text(
              'By accepting, you agree to:\n\n'
              '• Receive messages from ${p.ownerDisplayName} through GraceWay when they need support.\n\n'
              '• Keep the contents of your conversations private and confidential.\n\n'
              '• Understand that this is a voluntary support relationship, not a professional '
              'counselling or crisis service. If you or ${p.ownerDisplayName} are in immediate '
              'danger, contact emergency services.\n\n'
              'Either person can end this partnership at any time.',
              style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: GraceWayColor.warmWhite.withValues(alpha: 0.75)),
            ),
          ]),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!,
              style: const TextStyle(fontSize: 13, color: GraceWayColor.warmCoral)),
        ],

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _acting ? null : _accept,
            style: ElevatedButton.styleFrom(
              backgroundColor: GraceWayColor.sage,
              foregroundColor: GraceWayColor.charcoal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _acting
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: GraceWayColor.charcoal))
                : const Text('Accept',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _acting ? null : _decline,
            style: TextButton.styleFrom(
              foregroundColor: GraceWayColor.warmWhite.withValues(alpha: 0.45),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Decline', style: TextStyle(fontSize: 15)),
          ),
        ),
      ]),
    );
  }

  Widget _doneState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _accepted
                ? Icons.check_circle_rounded
                : Icons.cancel_outlined,
            size: 64,
            color: _accepted ? GraceWayColor.sage : GraceWayColor.warmWhite.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 20),
          Text(
            _accepted
                ? 'You\'re walking together'
                : 'Invite declined',
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: GraceWayColor.warmWhite),
          ),
          const SizedBox(height: 10),
          Text(
            _accepted
                ? 'You\'ll be notified when ${_partnership?.ownerDisplayName ?? 'your partner'} reaches out.'
                : 'You can always connect with people in your Prayer Circles.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: GraceWayColor.softGold.withValues(alpha: 0.7),
                height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: GraceWayColor.golden.withValues(alpha: 0.15),
              foregroundColor: GraceWayColor.softGold,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.link_off_rounded, size: 56,
              color: GraceWayColor.warmWhite.withValues(alpha: 0.25)),
          const SizedBox(height: 20),
          Text(_errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  color: GraceWayColor.warmWhite.withValues(alpha: 0.6),
                  height: 1.5)),
          const SizedBox(height: 32),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go back',
                style: TextStyle(color: GraceWayColor.softGold)),
          ),
        ]),
      ),
    );
  }
}
