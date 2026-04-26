import 'package:flutter/material.dart';

class JournalTheme {
  final Color bgPrimary;
  final Color bgCard;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentAction;
  final Color accentMuted;
  final String heroImageAsset;

  const JournalTheme({
    required this.bgPrimary,
    required this.bgCard,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentAction,
    required this.accentMuted,
    required this.heroImageAsset,
  });

  static const parchment = JournalTheme(
    bgPrimary:      Color(0xFFE8D5B7),
    bgCard:         Color(0xFFF0DFC5),
    textPrimary:    Color(0xFF3A2A18),
    textSecondary:  Color(0xFF6B5035),
    accentAction:   Color(0xFFC4894A),
    accentMuted:    Color(0xFFDDD0C0),
    heroImageAsset: 'assets/journal/seadistantmod.webp',
  );
}
