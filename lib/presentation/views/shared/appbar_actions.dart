import 'package:flutter/material.dart';
import '../settings/settings_view.dart';
import 'notification_bell.dart';
import '../../theme/app_theme.dart';

/// Standard AppBar actions for Today, Progress, and Circles screens.
/// Order: Notifications | Settings | ⋮ (Help)
List<Widget> standardAppBarActions(BuildContext context, {Widget? helpView}) {
  final iconColor = GraceWayColor.warmWhite.withValues(alpha: 0.7);
  return [
    const NotificationBell(),
    IconButton(
      icon: Icon(Icons.settings_outlined, color: iconColor),
      onPressed: () => Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const SettingsView()),
      ),
      tooltip: 'Settings',
    ),
    if (helpView != null)
      PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: iconColor),
        color: GraceWayColor.cardBackground,
        onSelected: (value) {
          if (value == 'help') {
            Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => helpView),
            );
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'help',
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: GraceWayColor.warmWhite.withValues(alpha: 0.7)),
                const SizedBox(width: 12),
                const Text('Help',
                    style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
  ];
}

/// Info / Help icon — kept for screens that don't use standardAppBarActions
/// (e.g. Journal which uses a theme-aware color).
Widget infoIconAction(
  BuildContext context,
  Widget helpView, {
  Color? color,
}) {
  return IconButton(
    icon: Icon(
      Icons.info_outline,
      color: color ?? GraceWayColor.warmWhite.withValues(alpha: 0.7),
    ),
    onPressed: () => Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => helpView),
    ),
    tooltip: 'Help',
  );
}

