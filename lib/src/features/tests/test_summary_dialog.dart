import 'package:flutter/material.dart';

import 'player_theme.dart';

/// Testbook-style confirm dialog used for Submit Test, Submit Section and Resume.
/// Shows a small summary table (Time Left / Attempted / Unattempted / Marked)
/// above the question + two action buttons. Returns true on confirm, false/null
/// on cancel. Light/dark follows the device; the confirm button uses the brand
/// accent.
Future<bool?> showTestSummaryDialog({
  required BuildContext context,
  required String title,
  required int remaining,
  required int attempted,
  required int unattempted,
  required int marked,
  required String confirmLabel,
  required String cancelLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final p = PlayerPalette.of(ctx);
      return Dialog(
        backgroundColor: p.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(p, Icons.access_time, 'Time Left', _fmt(remaining), valueColor: p.accent),
              _divider(p),
              _row(p, Icons.check_circle_outline, 'Attempted', '$attempted'),
              _divider(p),
              _row(p, Icons.remove_circle_outline, 'Unattempted', '$unattempted'),
              _divider(p),
              _row(p, Icons.star_border, 'Marked', '$marked'),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 17, height: 1.3),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.accent,
                      foregroundColor: p.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.isDark ? const Color(0xFF8B97A3) : const Color(0xFFAEB9C4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text(cancelLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      );
    },
  );
}

Widget _row(PlayerPalette p, IconData icon, String label, String value, {Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(children: [
      Icon(icon, color: p.textMuted, size: 22),
      const SizedBox(width: 14),
      Expanded(child: Text(label, style: TextStyle(color: p.textMuted, fontSize: 16))),
      Text(value,
          style: TextStyle(
            color: valueColor ?? p.text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            fontFeatures: const [],
          )),
    ]),
  );
}

Widget _divider(PlayerPalette p) => Divider(height: 1, color: p.border);

String _fmt(int s) {
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(sec)}';
}
