import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../domain/entities/circle.dart';
import '../../../domain/repositories/circle_repository.dart';
import '../../theme/app_theme.dart';

class CircleSettingsView extends StatefulWidget {
  final String circleId;
  final String circleName;
  final String circleDescription;
  final String inviteCode;
  final List<CircleMember> members;
  final String currentUserId;

  const CircleSettingsView({
    super.key,
    required this.circleId,
    required this.circleName,
    required this.circleDescription,
    required this.inviteCode,
    required this.members,
    required this.currentUserId,
  });

  @override
  State<CircleSettingsView> createState() => _CircleSettingsViewState();
}

class _CircleSettingsViewState extends State<CircleSettingsView> {
  // ── Circle details
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;

  bool _saving = false;
  bool _deleting = false;
  bool _isLeaving = false;
  String? _error;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.circleName);
    _descCtrl = TextEditingController(text: widget.circleDescription);
    _nameCtrl.addListener(_onTextChanged);
    _descCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final nameChanged = _nameCtrl.text.trim() != widget.circleName;
    final descChanged = _descCtrl.text.trim() != widget.circleDescription;
    if ((nameChanged || descChanged) != _dirty) {
      setState(() => _dirty = nameChanged || descChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        title: const Text('Circle Settings',
            style: TextStyle(
                color: GraceWayColor.warmWhite,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: GraceWayColor.warmWhite),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: GraceWayColor.golden))
                  : const Text('Save',
                      style: TextStyle(
                          color: GraceWayColor.golden,
                          fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [

          // ── Circle Details ──────────────────────────────────────────────
          _sectionHeader('Circle Details'),
          const SizedBox(height: 8),
          _inputCard(
            label: 'Circle Name',
            controller: _nameCtrl,
            hint: 'e.g. Sunday Morning Group',
          ),
          const SizedBox(height: 8),
          _inputCard(
            label: 'Description',
            controller: _descCtrl,
            hint: 'Optional description',
            maxLines: 3,
          ),

          const SizedBox(height: 24),

          // ── Invite ──────────────────────────────────────────────────────
          _sectionHeader('Invite'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: GraceWayDecorations.card,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Share this code with anyone you want to invite:',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: GraceWayColor.golden.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GraceWayColor.golden.withValues(alpha: 0.25), width: 0.5),
                    ),
                    child: Text(
                      widget.inviteCode,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: GraceWayColor.golden,
                        letterSpacing: 4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: widget.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Invite code copied'),
                      backgroundColor: GraceWayColor.cardBackground,
                      duration: Duration(seconds: 2),
                    ));
                  },
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GraceWayColor.golden.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.copy_rounded, size: 18, color: GraceWayColor.golden),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final text = 'Join my Prayer Circle "${widget.circleName}" on Grace Tracker!\n\n'
                        'Your invite code: ${widget.inviteCode}\n\n'
                        'Already have the app? Go to Circles → Join with Invite Code → enter ${widget.inviteCode}\n\n'
                        "Don't have the app yet?\n"
                        'Android: https://play.google.com/store/apps/details?id=com.gracetracker.com\n'
                        'iPhone: https://apps.apple.com/app/grace-tracker/id[APP_STORE_ID]';
                    Share.share(text);
                  },
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share Invite Link',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GraceWayColor.golden,
                    foregroundColor: GraceWayColor.charcoal,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Members ─────────────────────────────────────────────────────
          _sectionHeader('Members (${widget.members.length})'),
          const SizedBox(height: 8),
          ...widget.members.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _memberRow(m),
          )),

          const SizedBox(height: 24),

          // ── Danger Zone ─────────────────────────────────────────────────
          _sectionHeader('Danger Zone'),
          const SizedBox(height: 8),
          _dangerButton(
            icon: Icons.logout_rounded,
            label: 'Leave Circle',
            subtitle: 'Remove yourself from this circle',
            onTap: _confirmLeave,
            loading: _isLeaving,
          ),
          const SizedBox(height: 8),
          _dangerButton(
            icon: Icons.delete_forever_rounded,
            label: 'Delete Circle',
            subtitle: 'Permanently removes the circle and all its data',
            onTap: _confirmDelete,
            loading: _deleting,
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 14, color: GraceWayColor.warmCoral),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error!,
                    style: const TextStyle(
                        fontSize: 12, color: GraceWayColor.warmCoral)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Text(title.toUpperCase(),
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.4),
          letterSpacing: 1.2));

  Widget _inputCard({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: GraceWayDecorations.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 0.8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 15, color: GraceWayColor.warmWhite),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 15),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          cursorColor: GraceWayColor.golden,
        ),
      ]),
    );
  }

  Widget _memberRow(CircleMember m) {
    final isSelf = m.userId == widget.currentUserId;
    final isAdmin = m.isAdmin;
    final color = isAdmin ? GraceWayColor.golden : GraceWayColor.sage;
    return GestureDetector(
      onTap: isSelf ? null : () => _showRoleDialog(m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: GraceWayDecorations.card,
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12)),
            child: Icon(Icons.person_rounded, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isSelf ? 'You' : m.displayName,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: GraceWayColor.warmWhite)),
            Text(isAdmin ? 'Admin' : 'Member',
                style: TextStyle(
                    fontSize: 11,
                    color: isAdmin
                        ? GraceWayColor.golden
                        : Colors.white.withValues(alpha: 0.4))),
          ])),
          if (!isSelf)
            Icon(Icons.swap_horiz_rounded,
                size: 16, color: Colors.white.withValues(alpha: 0.25)),
        ]),
      ),
    );
  }

  Widget _dangerButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required bool loading,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: GraceWayColor.warmCoral.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: GraceWayColor.warmCoral.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: GraceWayColor.warmCoral.withValues(alpha: 0.12)),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: GraceWayColor.warmCoral))
                : Icon(icon, size: 16, color: GraceWayColor.warmCoral),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: GraceWayColor.warmCoral)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: GraceWayColor.warmCoral.withValues(alpha: 0.5))),
          ])),
        ]),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Circle name cannot be empty.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final repo = context.read<CircleRepository>();
      // Save name/description if changed
      final nameChanged = name != widget.circleName;
      final desc = _descCtrl.text.trim();
      final descChanged = desc != widget.circleDescription;
      if (nameChanged || descChanged) {
        await repo.updateCircle(
          widget.circleId,
          name: nameChanged ? name : null,
          description: descChanged ? desc : null,
        );
      }
      if (mounted) {
        setState(() { _saving = false; _dirty = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Settings saved'),
          backgroundColor: GraceWayColor.cardBackground,
        ));
        // Return updated name so the detail view can refresh its title
        Navigator.pop(context, name);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _saving = false; });
    }
  }

  void _showRoleDialog(CircleMember m) {
    final isAdmin = m.isAdmin;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GraceWayColor.cardBackground,
        title: Text(isAdmin ? 'Remove Admin' : 'Make Admin',
            style: const TextStyle(color: GraceWayColor.warmWhite, fontSize: 16)),
        content: Text(
          isAdmin
              ? 'Remove admin privileges from ${m.displayName}? They will become a regular member.'
              : 'Give ${m.displayName} admin privileges? They will be able to manage habits, events, and circle settings.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CircleRepository>().updateMemberRole(
                widget.circleId, m.userId, isAdmin ? 'member' : 'admin',
              );
            },
            child: Text(isAdmin ? 'Remove Admin' : 'Make Admin',
                style: const TextStyle(color: GraceWayColor.golden)),
          ),
        ],
      ),
    );
  }

  void _confirmLeave() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GraceWayColor.cardBackground,
        title: const Text('Leave Circle',
            style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 16)),
        content: Text(
          "You'll no longer receive prayer requests or see this circle's progress.",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); _leaveCircle(); },
            child: const Text('Leave',
                style: TextStyle(color: GraceWayColor.warmCoral, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveCircle() async {
    setState(() { _isLeaving = true; _error = null; });
    try {
      await context.read<CircleRepository>().leaveCircle(widget.circleId);
      if (mounted) Navigator.pop(context, 'left');
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLeaving = false; });
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: GraceWayColor.cardBackground,
        title: const Text('Delete Circle?',
            style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 16)),
        content: Text(
          'This will permanently delete "${widget.circleName}" and all its data — '
          'prayer requests, scripture threads, habits, events, and member history. '
          'This cannot be undone.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); _deleteCircle(); },
            child: const Text('Delete Circle',
                style: TextStyle(color: GraceWayColor.warmCoral, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCircle() async {
    setState(() { _deleting = true; _error = null; });
    try {
      await context.read<CircleRepository>().deleteCircle(widget.circleId);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _deleting = false; });
    }
  }
}

