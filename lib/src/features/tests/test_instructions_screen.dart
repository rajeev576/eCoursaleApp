import 'package:flutter/material.dart';

import '../../core/widgets/rich_content.dart';
import '../../data/models/test_models.dart';
import 'player_theme.dart';

/// APP-NATIVE pre-test screen styled like Testbook's instructions page — the
/// test title, a Duration | Maximum Marks row, the instruction bullets, a
/// "Choose your Default Language" dropdown and an "Agree and Continue" button.
/// Light/dark follows the device; the button uses the school's brand accent.
/// The timer does NOT run here — it starts only when the student continues.
class TestInstructionsScreen extends StatelessWidget {
  const TestInstructionsScreen({
    super.key,
    required this.paper,
    required this.selectedLang,
    required this.onLangChanged,
    required this.onStart,
  });

  final TestPaper paper;
  final String selectedLang;
  final ValueChanged<String> onLangChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final p = PlayerPalette.of(context);
    final codes = paper.languageCodes;
    final qCount = paper.allQuestions.length;
    final mins = paper.durationMinutes;
    final marks = paper.maxMarks;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        elevation: 0,
        title: const Text('Your Test'),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Default-language dropdown (only when multiple languages exist).
                if (codes.length > 1) ...[
                  _LangDropdown(
                    paper: paper,
                    codes: codes,
                    value: selectedLang,
                    onChanged: onLangChanged,
                    p: p,
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.onAccent,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Agree and Continue',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          // Title
          Text(
            paper.testName,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 20, height: 1.3),
          ),
          const SizedBox(height: 16),
          // Duration | Maximum Marks row
          Row(
            children: [
              Expanded(
                child: _metaCol(p, 'Duration',
                    mins > 0 ? '$mins Mins.' : '${qCount}Qs'),
              ),
              Expanded(
                child: _metaCol(p, 'Maximum Marks',
                    marks > 0 ? _fmtMarks(marks) : '$qCount Questions',
                    end: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: p.border),
          const SizedBox(height: 8),
          // Instructions (rendered natively — HTML/LaTeX supported).
          if (paper.instructions.isEmpty)
            _DefaultInstructions(qCount: qCount, mins: mins, p: p)
          else
            ...paper.instructions.map((b) {
              final value = (b['value'] ?? '').toString();
              if (value.trim().isEmpty) return const SizedBox.shrink();
              return _bullet(p, RichContent(html: value, fontSize: 15, color: p.textMuted));
            }),
        ],
      ),
    );
  }

  Widget _metaCol(PlayerPalette p, String label, String value, {bool end = false}) {
    return Column(
      crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: p.textMuted, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 16)),
      ],
    );
  }

  Widget _bullet(PlayerPalette p, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 10),
            child: Container(width: 5, height: 5,
                decoration: BoxDecoration(color: p.textMuted, shape: BoxShape.circle)),
          ),
          Expanded(child: child),
        ]),
      );

  String _fmtMarks(double m) =>
      m == m.roundToDouble() ? '${m.toStringAsFixed(0)}.0' : m.toStringAsFixed(2);
}

class _LangDropdown extends StatelessWidget {
  const _LangDropdown({
    required this.paper,
    required this.codes,
    required this.value,
    required this.onChanged,
    required this.p,
  });
  final TestPaper paper;
  final List<String> codes;
  final String value;
  final ValueChanged<String> onChanged;
  final PlayerPalette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        border: Border.all(color: p.text.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: codes.contains(value) ? value : codes.first,
          isExpanded: true,
          dropdownColor: p.surface,
          icon: Icon(Icons.keyboard_arrow_down, color: p.text),
          hint: Text('Choose your Default Language', style: TextStyle(color: p.text)),
          style: TextStyle(color: p.text, fontSize: 15),
          items: [
            for (final c in codes)
              DropdownMenuItem(value: c, child: Text(paper.languageName(c))),
          ],
          onChanged: (c) { if (c != null) onChanged(c); },
        ),
      ),
    );
  }
}

/// Sensible default instructions when the test ships none.
class _DefaultInstructions extends StatelessWidget {
  const _DefaultInstructions({required this.qCount, required this.mins, required this.p});
  final int qCount;
  final int mins;
  final PlayerPalette p;
  @override
  Widget build(BuildContext context) {
    final items = <String>[
      'The test has $qCount question${qCount == 1 ? '' : 's'}'
          '${mins > 0 ? ' to be completed in $mins minutes' : ''}.',
      'The timer starts when you continue and the test auto-submits at 0.',
      'Use the question palette to jump between questions and mark for review.',
      'Your answers are saved automatically; you can leave and resume.',
      'Tap Submit when you are done.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 10),
                child: Container(width: 5, height: 5,
                    decoration: BoxDecoration(color: p.textMuted, shape: BoxShape.circle)),
              ),
              Expanded(child: Text(t, style: TextStyle(fontSize: 15, height: 1.5, color: p.textMuted))),
            ]),
          ),
      ],
    );
  }
}
