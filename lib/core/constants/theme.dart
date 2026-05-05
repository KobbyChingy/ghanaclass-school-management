import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ERP Color Palette
  static const Color primarySlate = Color(0xFF020617); // Slate 950 - Authority/Sidebars
  static const Color actionIndigo = Color(0xFF4F46E5); // Indigo 600 - Student tasks
  static const Color authorityYellow = Color(0xFFEAB308); // Yellow 500 - Staff/AI features
  static const Color executiveTeal = Color(0xFF0F766E);
  static const Color executiveRose = Color(0xFFBE185D);
  static const Color executiveSky = Color(0xFF0284C7);

  // Surfaces
  static const Color background = Color(0xFFF8FAFC); // Slate 50 - main workspace
  static const Color surface = Color(0xFFFFFFFF); // Cards / header
  static const Color surfaceMuted = Color(0xFFE2E8F0); // Slate 200
  static const Color surfaceSoft = Color(0xFFF1F5F9);
  static const Color surfaceElevated = Color(0xFFFCFDFE);

  // Text
  static const Color textMain = Color(0xFF020617); // Slate 950
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  
  // Semantic colors
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  
  // Custom Styles
  static const Color cardBackground = Colors.white;
  static final Color border = Colors.black.withValues(alpha: 0.04);

  static LinearGradient get appBackgroundGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF7FAFF),
          Color(0xFFF8FAFC),
          Color(0xFFEEF4FF),
        ],
        stops: [0, 0.55, 1],
      );

  static LinearGradient get sidebarGradient => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF081120),
          Color(0xFF0F1E39),
          Color(0xFF111827),
        ],
      );

  static ThemeData get darkTheme {
    final base = ThemeData.light();
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.sora(fontWeight: FontWeight.w800, letterSpacing: -1.4),
      displayMedium: GoogleFonts.sora(fontWeight: FontWeight.w800, letterSpacing: -1.0),
      displaySmall: GoogleFonts.sora(fontWeight: FontWeight.w700, letterSpacing: -0.8),
      headlineLarge: GoogleFonts.sora(fontWeight: FontWeight.w800, letterSpacing: -1.0),
      headlineMedium: GoogleFonts.sora(fontWeight: FontWeight.w700, letterSpacing: -0.8),
      headlineSmall: GoogleFonts.sora(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      titleLarge: GoogleFonts.sora(fontWeight: FontWeight.w700, letterSpacing: -0.4),
      titleMedium: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: -0.2),
      titleSmall: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      bodyLarge: GoogleFonts.manrope(fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.manrope(fontWeight: FontWeight.w500),
      bodySmall: GoogleFonts.manrope(fontWeight: FontWeight.w500),
      labelLarge: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      labelMedium: GoogleFonts.manrope(fontWeight: FontWeight.w700),
      labelSmall: GoogleFonts.manrope(fontWeight: FontWeight.w700, letterSpacing: 0.2),
    ).apply(
      bodyColor: textMain,
      displayColor: textMain,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.light(
        primary: actionIndigo,
        secondary: authorityYellow,
        surface: surface,
        error: error,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textMain,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: textMain),
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: surfaceMuted),
        ),
        margin: EdgeInsets.zero,
        shadowColor: primarySlate.withValues(alpha: 0.06),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        labelStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textMuted.withValues(alpha: 0.8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: surfaceMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: executiveSky, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: actionIndigo,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: actionIndigo,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textMain,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          side: const BorderSide(color: surfaceMuted),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: primarySlate,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: const DividerThemeData(
        color: surfaceMuted,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceSoft,
        side: const BorderSide(color: surfaceMuted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

/// Backwards-compatible color access used by legacy screens.
/// Prefer referencing [AppTheme] directly in new code.
class AppColors {
  static const primary = AppTheme.actionIndigo;
  static const secondary = AppTheme.authorityYellow;
  static const background = AppTheme.background;
  static const surface = AppTheme.surface;
  static const surfaceMuted = AppTheme.surfaceMuted;

  static const textMain = AppTheme.textMain;
  static const textMuted = AppTheme.textMuted;

  static const success = AppTheme.success;
  static const warning = AppTheme.warning;
  static const error = AppTheme.error;
}
