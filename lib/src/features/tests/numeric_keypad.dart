import 'package:flutter/material.dart';

/// Polished, APP-NATIVE numeric keypad for NUM / NAT (GATE) questions — mirrors
/// the website's on-screen keypad (readonly field + 7-8-9 / 4-5-6 / 1-2-3 / 0 -
/// . grid + backspace + clear), with the same input rules:
///   • '-' only allowed as the FIRST character,
///   • a single '.',
///   • max 10 characters.
/// No system keyboard pops up (matches the web's readonly field) — feels native.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  void _append(String key) {
    var v = value;
    if (v.length >= 10) return;
    if (key == '-') {
      if (v.isEmpty) onChanged('-');
      return;
    }
    if (key == '.') {
      if (!v.contains('.')) onChanged('$v.');
      return;
    }
    onChanged('$v$key');
  }

  void _backspace() {
    if (value.isNotEmpty) onChanged(value.substring(0, value.length - 1));
  }

  void _clear() => onChanged('');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const keys = ['7', '8', '9', '4', '5', '6', '1', '2', '3', '0', '-', '.'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Answer display (readonly, like the web).
        Container(
          height: 52,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            value.isEmpty ? 'Enter your answer' : value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: value.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 3-column keypad.
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.0,
          children: [
            for (final k in keys)
              _Key(label: k, onTap: () => _append(k)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: value.isEmpty ? null : _backspace,
                icon: const Icon(Icons.backspace_outlined, size: 18),
                label: const Text('Backspace'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: value.isEmpty ? null : _clear,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Clear'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
