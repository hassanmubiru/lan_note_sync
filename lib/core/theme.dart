// lib/core/theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants.dart';

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark  => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary:   AppColors.primary,
      secondary: AppColors.secondary,
      tertiary:  AppColors.tertiary,
      error:     AppColors.error,
      surface:   isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      fontFamily: 'Inter',
      textTheme: _textTheme(isDark),

      // ── App bar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.grey[900],
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 19,
          letterSpacing: -0.3,
          color: isDark ? Colors.white : Colors.grey[900],
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white70 : Colors.grey[700],
          size: 22,
        ),
      ),

      // ── Card ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1A2235) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? const Color(0xFF263048) : const Color(0xFFE8ECF4),
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Input ─────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF4F6FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF263048) : const Color(0xFFE8ECF4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.white30 : Colors.grey[400],
          fontFamily: 'Inter',
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── Tab bar ───────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: isDark ? Colors.white38 : Colors.grey[500],
        dividerColor: Colors.transparent,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.primary, width: 2.5),
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.1,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        splashFactory: NoSplash.splashFactory,
      ),

      // ── Elevated button ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── Outlined button ───────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          side: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),

      // ── Chip ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.primary.withOpacity(0.15)
            : AppColors.primary.withOpacity(0.08),
        selectedColor: AppColors.primary.withOpacity(0.22),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),

      // ── Bottom sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF141929) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 20,
        surfaceTintColor: Colors.transparent,
      ),

      // ── Snack bar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF141929) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          color: isDark ? Colors.white : Colors.grey[900],
        ),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF263048) : const Color(0xFFEEF0F6),
        thickness: 1,
        space: 1,
      ),

      // ── List tile ─────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        iconColor: isDark ? Colors.white54 : Colors.grey[600],
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.primary : null),
      ),

      // ── Progress indicator ────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: Colors.transparent,
      ),
    );
  }

  static TextTheme _textTheme(bool isDark) {
    final c  = isDark ? Colors.white       : const Color(0xFF0F172A);
    final c2 = isDark ? Colors.white60     : const Color(0xFF64748B);
    return TextTheme(
      displayLarge:  _s(57, FontWeight.w800, c),
      displayMedium: _s(45, FontWeight.w800, c),
      displaySmall:  _s(36, FontWeight.w700, c),
      headlineLarge: _s(32, FontWeight.w700, c),
      headlineMedium:_s(28, FontWeight.w700, c),
      headlineSmall: _s(24, FontWeight.w700, c),
      titleLarge:    _s(20, FontWeight.w700, c,  spacing: -0.2),
      titleMedium:   _s(16, FontWeight.w600, c,  spacing: -0.1),
      titleSmall:    _s(14, FontWeight.w600, c),
      bodyLarge:     _s(16, FontWeight.w400, c,  height: 1.65),
      bodyMedium:    _s(14, FontWeight.w400, c,  height: 1.55),
      bodySmall:     _s(12, FontWeight.w400, c2, height: 1.5),
      labelLarge:    _s(14, FontWeight.w600, c),
      labelMedium:   _s(12, FontWeight.w500, c2),
      labelSmall:    _s(11, FontWeight.w500, c2),
    );
  }

  static TextStyle _s(double size, FontWeight w, Color c,
      {double? height, double? spacing}) =>
      TextStyle(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: w,
        color: c,
        height: height,
        letterSpacing: spacing,
      );
}
