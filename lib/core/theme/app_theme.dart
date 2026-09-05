import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const navy = Color(0xFF0B1730);
  static const navy2 = Color(0xFF132247);
  static const blue700 = Color(0xFF1D4ED8);
  static const blue600 = Color(0xFF2563EB);
  static const blue500 = Color(0xFF3B82F6);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue50 = Color(0xFFEEF4FF);
  static const page = Color(0xFFF5F8FD);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0F1B33);
  static const muted = Color(0xFF6B7A93);
  static const line = Color(0xFFE4EAF3);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFDEAEA);
  static const warn = Color(0xFFB45309);
  static const warnSoft = Color(0xFFFDF3E3);
  static const ok = Color(0xFF0F7B4C);
  static const okSoft = Color(0xFFE4F5EC);
  static const navInactive = Color(0xFF94A3B8);
  static const heroSubtext = Color(0xFF8CA0C4);
  static const heroAccent = Color(0xFF7FB0FF);
}

class AppStyles {
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: AppColors.muted,
  );

  static TextStyle get eyebrow => GoogleFonts.jetBrainsMono(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    color: AppColors.heroAccent,
  );

  static TextStyle get sectionTitle => GoogleFonts.sora(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.navy, AppColors.navy2],
  );

  static BoxDecoration get card => BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.line),
    boxShadow: [
      BoxShadow(
        color: AppColors.navy.withValues(alpha: 0.08),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class AppTheme {
  static ThemeData get light {
    final interBody = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.page,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.blue600,
        primary: AppColors.blue600,
        surface: AppColors.page,
      ),
      textTheme: interBody.copyWith(
        headlineLarge: GoogleFonts.sora(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.sora(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        titleLarge: GoogleFonts.sora(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: AppColors.ink),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: AppColors.muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.blue600, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: GoogleFonts.inter(color: AppColors.muted, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue600,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
