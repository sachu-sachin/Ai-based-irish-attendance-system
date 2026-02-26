import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ─── Brand Colors ─────────────────────────────
  static const Color primaryColor = Color(0xFF4F46E5); // Indigo
  static const Color accentColor = Color(0xFF06B6D4); // Cyan
  static const Color successColor = Color(0xFF22C55E); // Green
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color onPrimaryColor = Color(0xFFFFFFFF);

  // Light palette (only palette — forced light mode)
  static const Color backgroundColor = Color(0xFFF0F4FF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color onSurfaceColor = Color(0xFF1A1B2E);
  static const Color subtleColor = Color(0xFF64748B);
  static const Color outlineColor = Color(0xFFE2E8F0);

  // ─── Font family ──────────────────────────────
  static const String _font = 'Inter';

  // ─── Static text style helpers ────────────────
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    fontFamily: _font,
    color: onSurfaceColor,
  );
  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    fontFamily: _font,
    color: onSurfaceColor,
  );
  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    fontFamily: _font,
    color: onSurfaceColor,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontFamily: _font,
    color: onSurfaceColor,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    fontFamily: _font,
    color: onSurfaceColor,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    fontFamily: _font,
    color: onSurfaceColor,
  );

  // ─── Light Theme ──────────────────────────────
  static ThemeData get lightTheme {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: primaryColor,
      onPrimary: onPrimaryColor,
      secondary: accentColor,
      onSecondary: onPrimaryColor,
      error: errorColor,
      onError: onPrimaryColor,
      surface: surfaceColor,
      onSurface: onSurfaceColor,
    );

    final textTheme = TextTheme(
      displayLarge: _ts(32, FontWeight.w700),
      displayMedium: _ts(28, FontWeight.w700),
      displaySmall: _ts(24, FontWeight.w600),
      headlineLarge: _ts(24, FontWeight.w700),
      headlineMedium: _ts(20, FontWeight.w600),
      headlineSmall: _ts(18, FontWeight.w600),
      titleLarge: _ts(18, FontWeight.w600),
      titleMedium: _ts(16, FontWeight.w500),
      titleSmall: _ts(14, FontWeight.w500),
      bodyLarge: _ts(16, FontWeight.w400),
      bodyMedium: _ts(14, FontWeight.w400),
      bodySmall: _ts(12, FontWeight.w400),
      labelLarge: _ts(14, FontWeight.w600),
      labelMedium: _ts(12, FontWeight.w500),
      labelSmall: _ts(11, FontWeight.w500),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _font,
      colorScheme: cs,
      textTheme: textTheme,
      scaffoldBackgroundColor: backgroundColor,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: onSurfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: _font,
          color: onSurfaceColor,
        ),
        iconTheme: IconThemeData(color: onSurfaceColor),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outlineColor),
        ),
      ),

      // NavigationBar (M3) — bottom nav
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: Color(0xFFEEF2FF),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryColor, size: 24);
          }
          return const IconThemeData(color: subtleColor, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: _font,
              color: primaryColor,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            fontFamily: _font,
            color: subtleColor,
          );
        }),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryColor,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: _font,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: _font,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: _font,
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontFamily: _font,
          color: subtleColor,
        ),
        hintStyle: TextStyle(
          fontSize: 14,
          fontFamily: _font,
          color: subtleColor.withAlpha(150),
        ),
        errorStyle: const TextStyle(
          fontSize: 12,
          fontFamily: _font,
          color: errorColor,
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEEF2FF),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontFamily: _font,
          color: onSurfaceColor,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: outlineColor),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: outlineColor,
        space: 1,
        thickness: 1,
      ),

      // Dialogs
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: _font,
          color: onSurfaceColor,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontFamily: _font,
          color: subtleColor,
        ),
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        iconColor: primaryColor,
        textColor: onSurfaceColor,
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: _font,
          color: onSurfaceColor,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          fontFamily: _font,
          color: subtleColor,
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurfaceColor,
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontFamily: _font,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // Switches
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? primaryColor : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? const Color(0xFFBBB4F8)
                : Colors.grey.withAlpha(60)),
      ),
    );
  }

  // Dark theme stub — not used (light mode only)
  static ThemeData get darkTheme => lightTheme;
}

// Helper: build TextStyle with Inter
TextStyle _ts(double size, FontWeight weight) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      fontFamily: 'Inter',
      color: AppTheme.onSurfaceColor,
    );
