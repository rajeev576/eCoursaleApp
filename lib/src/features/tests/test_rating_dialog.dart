import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'player_theme.dart';

/// Post-submit feedback: a star rating (1–5) + optional review text, saved into
/// the existing Review model (attaches to the test's parent series/exam). Shown
/// once on the result screen after a fresh submission.
Future<void> showTestRatingDialog(BuildContext context, WidgetRef ref, String attemptUuid) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _RatingDialog(attemptUuid: attemptUuid, ref: ref),
  );
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({required this.attemptUuid, required this.ref});
  final String attemptUuid;
  final WidgetRef ref;
  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 0;
  final _textCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _submitting = true);
    try {
      await widget.ref
          .read(contentRepoProvider)
          .submitTestReview(widget.attemptUuid, _rating.toDouble(), _textCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thanks for your feedback!')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not submit. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerPalette.of(context);
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How was this test?',
                style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Your rating helps other students.',
                style: TextStyle(color: p.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(
                      i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 36,
                      color: i <= _rating ? const Color(0xFFFFC107) : p.textFaint,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textCtrl,
              maxLines: 3,
              style: TextStyle(color: p.text),
              decoration: InputDecoration(
                hintText: 'Add a review (optional)',
                hintStyle: TextStyle(color: p.textFaint),
                filled: true,
                fillColor: p.surfaceAlt,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              TextButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                child: Text('Not now', style: TextStyle(color: p.textMuted)),
              ),
              const Spacer(),
              FilledButton(
                onPressed: (_rating == 0 || _submitting) ? null : _submit,
                style: FilledButton.styleFrom(
                    backgroundColor: p.accent, foregroundColor: p.onAccent),
                child: _submitting
                    ? SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: p.onAccent))
                    : const Text('Submit'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
