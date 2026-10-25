import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color textPrimary = Color(0xFFF5F7F7);
  static const Color textSecondary = Color(0xC1F5F7F7); // ~76% opacity
  static const Color textMuted = Color(0x8FF5F7F7);     // ~56% opacity
  static const Color accent = Color(0xFFFFFFFF);
  static const Color accentBright = Color(0xFFE0E0E0);
  static const Color danger = Color(0xFF888888);
  static const Color background = Colors.transparent;
}

class AppTypography {
  static final TextStyle screenTitle = GoogleFonts.castoro(
        fontSize: 28,
        height: 34 / 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static final TextStyle sectionTitle = GoogleFonts.fraunces(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static final TextStyle label = GoogleFonts.fraunces(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      );
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentBright,
      error: AppColors.danger,
      surface: Color(0xFF0C1214),
    ),
    textTheme: GoogleFonts.frauncesTextTheme(ThemeData.dark().textTheme),
  );
}
