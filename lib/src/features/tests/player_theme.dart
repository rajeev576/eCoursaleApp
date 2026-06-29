import 'package:flutter/material.dart';

/// Shared design tokens for the test PLAYER / RESULT / SOLUTION screens.
///
/// The test experience replicates Testbook's LAYOUT (compact header, section
/// tabs, meta strip, bordered option tiles, drawer palette, bottom action bar),
/// but the light/dark look FOLLOWS THE DEVICE system brightness — dark on a dark
/// phone, light on a light phone. Either way the school's PRIMARY colour is the
/// brand ACCENT (active tab underline, selected option, Save & Next, the
/// attempted-dots), so it stays white-label rather than fixed Testbook-blue.
///
/// Use [PlayerPalette.of] inside any of these screens to get a consistent set of
/// colours derived from the current theme's primary + the device brightness.
class PlayerPalette {
  const PlayerPalette({
    required this.isDark,
    required this.accent,
    required this.onAccent,
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textFaint,
  });

  /// Whether the player is rendering in dark mode (mirrors device brightness).
  final bool isDark;

  /// School brand accent (selected option, primary buttons, active underline…).
  final Color accent;

  /// Readable foreground ON the accent (button labels).
  final Color onAccent;

  /// Page background.
  final Color bg;

  /// Cards / tiles / header surface (slightly raised from [bg]).
  final Color surface;

  /// A second elevated surface (drawer rows, meta strip).
  final Color surfaceAlt;

  /// Hairline borders on the surfaces.
  final Color border;

  /// Primary text.
  final Color text;

  /// Secondary text.
  final Color textMuted;

  /// Tertiary / disabled text.
  final Color textFaint;

  // ── question-state colours (same hues in both modes — these read fine on
  //    light and dark, matching Testbook's legend) ──
  static const Color attempted = Color(0xFF3B82F6); // blue  — answered
  static const Color marked = Color(0xFFEF4476);    // pink  — marked for review
  static const Color unattempted = Color(0xFF9CA3AF); // grey — seen, not answered
  static const Color correct = Color(0xFF22C55E);   // green — correct (solution)
  static const Color incorrect = Color(0xFFEF4444); // red   — incorrect (solution)

  /// `+marks` chip (green) — bg/text adapt to mode for contrast.
  Color get positiveChipBg => isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
  Color get positiveChipText => isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

  /// `-penalty` chip (red).
  Color get negativeChipBg => isDark ? const Color(0xFF4C1D24) : const Color(0xFFFEE2E2);
  Color get negativeChipText => isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);

  /// Build the palette from the active THEME's brightness (NOT the raw device
  /// brightness) so the in-app Appearance override (System / Light / Dark) is
  /// honoured — e.g. forcing Light on a Dark phone makes the player light too.
  factory PlayerPalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final dark = theme.brightness == Brightness.dark;
    // Readable label colour on the accent (white unless the accent is very light).
    final onAccent =
        accent.computeLuminance() > 0.6 ? const Color(0xFF111827) : Colors.white;
    if (dark) {
      return PlayerPalette(
        isDark: true,
        accent: accent,
        onAccent: onAccent,
        bg: const Color(0xFF15171C),
        surface: const Color(0xFF20232B),
        surfaceAlt: const Color(0xFF2A2E37),
        border: const Color(0xFF3A3F4B),
        text: const Color(0xFFF1F3F6),
        textMuted: const Color(0xFFB6BCC8),
        textFaint: const Color(0xFF7A8190),
      );
    }
    return PlayerPalette(
      isDark: false,
      accent: accent,
      onAccent: onAccent,
      bg: const Color(0xFFF4F6FA),
      surface: Colors.white,
      surfaceAlt: const Color(0xFFF1F4F9),
      border: const Color(0xFFE2E8F0),
      text: const Color(0xFF1A2233),
      textMuted: const Color(0xFF5B6478),
      textFaint: const Color(0xFF98A1B3),
    );
  }
}
