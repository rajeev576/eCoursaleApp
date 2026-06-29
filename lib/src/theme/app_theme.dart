import 'package:flutter/material.dart';

import '../data/models/school_config.dart';

/// Builds the Material theme from the school's server-driven config. This is the
/// automation lever: the school's primary colour (from the backend) drives the
/// whole app's look with no rebuild.
class AppTheme {
  static Color _parseHex(String hex, Color fallback) {
    var h = hex.trim();
    if (h.isEmpty) return fallback;
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(v);
  }

  /// LIGHT theme from the school's brand colour.
  static ThemeData fromConfig(SchoolConfig? config) =>
      _build(config, Brightness.light);

  /// DARK theme from the same brand colour (used when the phone is in dark mode).
  static ThemeData darkFromConfig(SchoolConfig? config) =>
      _build(config, Brightness.dark);

  static ThemeData _build(SchoolConfig? config, Brightness brightness) {
    final primary = _parseHex(config?.primaryColor ?? '', const Color(0xFF2563EB));
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      brightness: brightness,
    );
    final scaffoldBg = isDark ? const Color(0xFF121419) : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF1C1F26) : Colors.white;
    // The AppBar stays brand-coloured in light mode (as before); in dark mode it
    // uses an elevated dark surface so the bright brand colour doesn't glare.
    final appBarBg = isDark ? surface : primary;
    final appBarFg = isDark ? const Color(0xFFF1F3F6) : Colors.white;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        elevation: 0,
        centerTitle: false,
      ),
      // Tab labels need contrast against whatever the AppBar background is.
      tabBarTheme: TabBarThemeData(
        labelColor: appBarFg,
        unselectedLabelColor: appBarFg.withValues(alpha: 0.7),
        indicatorColor: appBarFg,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: surface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor:
              primary.computeLuminance() > 0.6 ? const Color(0xFF111827) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
    );
  }

  /// A neutral light theme used before the config has loaded (splash/login).
  static ThemeData get fallback => fromConfig(null);
}
