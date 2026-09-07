import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xC1FFFFFF); // ~76% opacity
  static const Color textMuted = Color(0x8FFFFFFF);     // ~56% opacity
  static const Color border = Color(0x33FFFFFF);        // ~20% opacity
  static const Color cardFill = Color(0x1EFFFFFF);      // ~12% opacity
  static const Color overlayStrong = Color(0x2EFFFFFF); // ~18% opacity
  static const Color overlaySoft = Color(0x14FFFFFF);   // ~8% opacity
  static const Color inputFill = Color(0x1AFFFFFF);     // ~10% opacity
  static const Color accent = Color(0xFFFFFFFF);
  static const Color accentBright = Color(0xFFE0E0E0);
  static const Color success = Color(0xFFE0E0E0);
  static const Color danger = Color(0xFF888888);
  
  static const Color chart1 = Color(0xFFFFFFFF);
  static const Color chart2 = Color(0xFFD0D0D0);
  static const Color chart3 = Color(0xFFB0B0B0);
  static const Color chart4 = Color(0xFF909090);
  static const Color chart5 = Color(0xFF707070);
  static const Color chart6 = Color(0xFF505050);
  static const Color chart7 = Color(0xFFE0E0E0);
  static const Color chart8 = Color(0xFFA0A0A0);
}

class AppSpacing {
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

class AppTypography {
  static TextStyle get screenTitle => GoogleFonts.castoro(
        fontSize: 28,
        height: 34 / 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get cardTitle => GoogleFonts.fraunces(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get sectionTitle => GoogleFonts.castoro(
        fontSize: 18,
        height: 24 / 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => GoogleFonts.castoro(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get label => GoogleFonts.castoro(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      );
}

class AppShadows {
  static List<BoxShadow> get defaultShadow => [
        BoxShadow(
          color: const Color(0x3D000000), // 0.24 opacity
          offset: const Offset(0, 18),
          blurRadius: 32,
          spreadRadius: 0,
        ),
      ];
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.transparent, // Background handled globally
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentBright,
      error: AppColors.danger,
      surface: Colors.transparent,
    ),
    textTheme: GoogleFonts.castoroTextTheme(ThemeData.dark().textTheme),
  );
}
