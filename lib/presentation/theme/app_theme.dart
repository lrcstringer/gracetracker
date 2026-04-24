import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JournalColor {
  static const bgPrimary    = Color(0xFFF3EDE2);
  static const bgCard       = Color(0xFFFBF7F0);
  static const accentMuted  = Color(0xFFDCE3D6);
  static const accentBlue   = Color(0xFFC9D3D6);
  static const textPrimary  = Color(0xFF5B4B3E);
  static const textSecondary = Color(0xFF7A6B5D);
}

class GraceWayColor {
  static const charcoal = Color(0xFF1E1E2E);
  static const warmWhite = Color(0xFFFAF7F2);
  static const golden = Color(0xFFD4A843);
  static const sage = Color(0xFF7A9E7E);
  static const warmCoral = Color(0xFFD4836B);
  static const softGold = Color(0xFFE8D5A3);
  static const mutedSage = Color(0xFFC5D8C7);

  static const cardBackground = Color(0xFF262638);
  static const cardBorder = Color(0x0FFFFFFF); // white 6% opacity

  static const surfaceOverlay = Color(0x0AFFFFFF); // white 4%
  static const inputBackground = Color(0x1AFFFFFF); // white 10%

  static const LinearGradient goldenGradient = LinearGradient(
    colors: [Color(0xFFD4A843), Color(0xFFE8D5A3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient warmGlow = RadialGradient(
    colors: [Color(0x1FD4A843), Color(0x0AD4A843), Colors.transparent],
    center: Alignment.topCenter,
    radius: 1.0,
  );
}

class AppTheme {
  static TextTheme _buildTextTheme(Color baseColor) {
    final inter = GoogleFonts.interTextTheme().apply(bodyColor: baseColor, displayColor: baseColor);
    return inter.copyWith(
      displayLarge: GoogleFonts.dmSerifDisplay(color: baseColor),
      displayMedium: GoogleFonts.dmSerifDisplay(color: baseColor),
      headlineLarge: GoogleFonts.dmSerifDisplay(color: baseColor, fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.dmSerifDisplay(color: baseColor, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.dmSerifDisplay(color: baseColor, fontWeight: FontWeight.w600),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: GraceWayColor.charcoal,
      colorScheme: const ColorScheme.dark(
        primary: GraceWayColor.golden,
        secondary: GraceWayColor.sage,
        surface: GraceWayColor.cardBackground,
        onPrimary: GraceWayColor.charcoal,
        onSurface: GraceWayColor.warmWhite,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: GraceWayColor.charcoal,
        selectedItemColor: GraceWayColor.golden,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GraceWayColor.charcoal,
        foregroundColor: GraceWayColor.warmWhite,
        elevation: 0,
      ),
      textTheme: _buildTextTheme(GraceWayColor.warmWhite),
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: GraceWayColor.warmWhite,
      colorScheme: ColorScheme.light(
        primary: GraceWayColor.golden,
        secondary: GraceWayColor.sage,
        surface: const Color(0xFFF0EDE8),
        onPrimary: GraceWayColor.charcoal,
        onSurface: GraceWayColor.charcoal,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: GraceWayColor.warmWhite,
        selectedItemColor: GraceWayColor.golden,
        unselectedItemColor: GraceWayColor.charcoal.withValues(alpha: 0.4),
        type: BottomNavigationBarType.fixed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GraceWayColor.warmWhite,
        foregroundColor: GraceWayColor.charcoal,
        elevation: 0,
      ),
      textTheme: _buildTextTheme(GraceWayColor.charcoal),
    );
  }
}

// Reusable decoration helpers
class GraceWayDecorations {
  static BoxDecoration get card => BoxDecoration(
    color: GraceWayColor.cardBackground,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: GraceWayColor.cardBorder, width: 0.5),
  );

  static BoxDecoration get inputField => BoxDecoration(
    color: GraceWayColor.inputBackground,
    borderRadius: BorderRadius.circular(12),
  );
}

// Reusable button style
class GraceWayButtonStyle {
  static ButtonStyle primary({Color color = GraceWayColor.golden}) =>
      ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: GraceWayColor.charcoal,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      );
}
