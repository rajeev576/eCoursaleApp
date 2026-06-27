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

  static ThemeData fromConfig(SchoolConfig? config) {
    final primary = _parseHex(config?.primaryColor ?? '', const Color(0xFF2563EB));
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
    );
  }

  /// A neutral theme used before the config has loaded (splash/login).
  static ThemeData get fallback => fromConfig(null);
}
