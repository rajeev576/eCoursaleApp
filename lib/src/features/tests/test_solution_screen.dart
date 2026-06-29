import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/html_text.dart';
import '../../core/providers.dart';
import '../../core/secure_screen.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/rich_content.dart';
import '../../data/models/test_models.dart';
import 'player_theme.dart';
import 'question_watermark.dart';

/// Native detailed-solution review, styled like Testbook's "Solutions" tab.
/// A filter row (All / Incorrect / Unattempted / Correct with counts), then a
/// list of compact question cards (status-coloured number badge + a truncated
/// preview) that open the full solution (your answer vs correct +
/// explanation, HTML + LaTeX + images rendered natively). Light/dark follows the
/// device; the brand accent themes the active filter.
class TestSolutionScreen extends ConsumerStatefulWidget {
  const TestSolutionScreen({super.key, required this.attemptUuid, this.embedded = false});
  final String attemptUuid;
  /// When true, render WITHOUT the Scaffold/AppBar (used as a tab inside the
  /// result screen). The language switcher moves into the body.
  final bool embedded;
  @override
  ConsumerState<TestSolutionScreen> createState() => _TestSolutionScreenState();
}

enum _Filter { all, incorrect, unattempted, correct }

class _TestSolutionScreenState extends ConsumerState<TestSolutionScreen> {
  String _lang = 'en';
  bool _langInit = false;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    // Protect exam content — block screenshots on the full-screen solution view.
    // (Embedded-in-result use leaves it to the result screen.)
    if (!widget.embedded) SecureScreen.enable();
  }

  @override
  void dispose() {
    if (!widget.embedded) SecureScreen.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerPalette.of(context);
    final sol = ref.watch(testSolutionProvider(widget.attemptUuid));
    final codes = sol.maybeWhen(data: (s) => s.languageCodes, orElse: () => const <String>[]);
    if (!_langInit && codes.isNotEmpty) {
      _lang = codes.contains('en') ? 'en' : codes.first;
      _langInit = true;
    }
    final langSwitcher = codes.length > 1
        ? sol.maybeWhen(
            data: (s) => PopupMenuButton<String>(
              tooltip: 'Language',
              icon: Icon(Icons.translate, color: p.text),
              color: p.surface,
              initialValue: _lang,
              onSelected: (c) => setState(() => _lang = c),
              itemBuilder: (_) => [
                for (final c in codes)
                  PopupMenuItem(value: c,
                      child: Text(s.languageName(c), style: TextStyle(color: p.text))),
              ],
            ),
            orElse: () => const SizedBox.shrink(),
          )
        : const SizedBox.shrink();

    final body = SafeArea(
        top: false,
        child: AsyncView<TestSolution>(
        value: sol,
        isEmpty: (s) => s.questions.isEmpty,
        emptyMessage: 'Solutions are not available for this test.',
        emptyIcon: Icons.menu_book_outlined,
        onRefresh: () async {
          ref.invalidate(testSolutionProvider(widget.attemptUuid));
          await ref.read(testSolutionProvider(widget.attemptUuid).future);
        },
        builder: (context, s) {
          final filtered = s.questions.where(_matches).toList();
          return Column(
            children: [
              _filterBar(p, s),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Expanded(
                    child: Text(s.testName.isEmpty ? 'Test' : s.testName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                  const SizedBox(width: 10),
                  Text('${s.questions.length} Questions',
                      style: TextStyle(color: p.textMuted, fontSize: 13)),
                ]),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('No questions in this filter.',
                        style: TextStyle(color: p.textMuted)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _QuestionCard(
                          q: filtered[i],
                          lang: _lang,
                          languageName: s.languageName,
                          languageCodes: s.languageCodes,
                          p: p,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      );

    // Embedded (result-screen tab): no Scaffold/AppBar — just a header strip
    // with the language switcher (when needed) + the body.
    if (widget.embedded) {
      return Column(
        children: [
          if (codes.length > 1)
            Align(alignment: Alignment.centerRight, child: langSwitcher),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        elevation: 0,
        title: const Text('Solutions'),
        actions: [langSwitcher],
      ),
      body: body,
    );
  }

  bool _matches(SolutionQuestion q) {
    switch (_filter) {
      case _Filter.all: return true;
      case _Filter.correct: return q.isCorrect;
      case _Filter.incorrect: return q.isIncorrect;
      case _Filter.unattempted: return q.isUnattempted;
    }
  }

  Widget _filterBar(PlayerPalette p, TestSolution s) {
    final all = s.questions.length;
    final incorrect = s.questions.where((q) => q.isIncorrect).length;
    final unattempted = s.questions.where((q) => q.isUnattempted).length;
    final correct = s.questions.where((q) => q.isCorrect).length;
    final chips = [
      (_Filter.all, 'All', all),
      (_Filter.incorrect, 'Incorrect', incorrect),
      (_Filter.unattempted, 'Unattempted', unattempted),
      (_Filter.correct, 'Correct', correct),
    ];
    return Container(
      color: p.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final c in chips) ...[
            _chip(p, '${c.$2} (${c.$3})', selected: _filter == c.$1,
                onTap: () => setState(() => _filter = c.$1)),
            const SizedBox(width: 10),
          ],
        ]),
      ),
    );
  }

  Widget _chip(PlayerPalette p, String label, {required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? p.accent : p.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? p.onAccent : p.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            )),
      ),
    );
  }
}

/// A compact, tappable question card in the Solutions list. Tap → full solution.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.q,
    required this.lang,
    required this.languageName,
    required this.languageCodes,
    required this.p,
  });
  final SolutionQuestion q;
  final String lang;
  final String Function(String) languageName;
  final List<String> languageCodes;
  final PlayerPalette p;

  Color get _badge => q.isCorrect
      ? PlayerPalette.correct
      : q.isIncorrect
          ? PlayerPalette.incorrect
          : PlayerPalette.unattempted;

  @override
  Widget build(BuildContext context) {
    // Plain-text preview (not clipped raw HTML): some questions have empty
    // leading lines / blank <p> tags, which made the clipped HTML preview look
    // empty. stripHtml + trim guarantees the first real text shows. Math markers
    // are kept as text; full rendering happens on the detail screen.
    final raw = q.lang(lang).question;
    var preview = stripHtml(raw).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (preview.length > 140) preview = '${preview.substring(0, 140)}…';
    if (preview.isEmpty) preview = 'View question';
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => _SolutionDetailScreen(
            q: q, lang: lang, languageName: languageName, languageCodes: languageCodes),
        )),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 28, height: 28, alignment: Alignment.center,
                  decoration: BoxDecoration(color: _badge, shape: BoxShape.circle),
                  child: Text('${q.slNo}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 20, color: p.textFaint),
              ]),
              const SizedBox(height: 10),
              Text(preview,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: p.text, height: 1.35)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full per-question solution (your answer vs correct + explanation).
class _SolutionDetailScreen extends StatefulWidget {
  const _SolutionDetailScreen({
    required this.q,
    required this.lang,
    required this.languageName,
    required this.languageCodes,
  });
  final SolutionQuestion q;
  final String lang;
  final String Function(String) languageName;
  final List<String> languageCodes;
  @override
  State<_SolutionDetailScreen> createState() => _SolutionDetailScreenState();
}

class _SolutionDetailScreenState extends State<_SolutionDetailScreen> {
  late String _lang = widget.lang;

  @override
  Widget build(BuildContext context) {
    final p = PlayerPalette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.surface,
        foregroundColor: p.text,
        elevation: 0,
        title: Text('Q${widget.q.slNo}'),
        actions: [
          if (widget.languageCodes.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Language',
              icon: Icon(Icons.translate, color: p.text),
              color: p.surface,
              initialValue: _lang,
              onSelected: (c) => setState(() => _lang = c),
              itemBuilder: (_) => [
                for (final c in widget.languageCodes)
                  PopupMenuItem(value: c,
                      child: Text(widget.languageName(c), style: TextStyle(color: p.text))),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            const QuestionWatermark(),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [_SolutionBody(q: widget.q, lang: _lang, p: p)],
            ),
          ],
        ),
      ),
    );
  }
}

class _SolutionBody extends StatelessWidget {
  const _SolutionBody({required this.q, required this.lang, required this.p});
  final SolutionQuestion q;
  final String lang;
  final PlayerPalette p;

  Color get _statusColor => q.isCorrect
      ? PlayerPalette.correct
      : q.isIncorrect
          ? PlayerPalette.incorrect
          : PlayerPalette.unattempted;

  @override
  Widget build(BuildContext context) {
    final L = q.lang(lang);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _statusChip(),
            const Spacer(),
            if (q.marks.isNotEmpty)
              Text('${q.marks} / ${q.penalty}',
                  style: TextStyle(fontSize: 12, color: p.textMuted)),
          ]),
          const SizedBox(height: 12),
          if (q.group != null && q.group!.text(lang).isNotEmpty) ...[
            PassageBlock(group: q.group!, lang: lang),
            const SizedBox(height: 12),
          ],
          if (L.comprehension.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: p.surfaceAlt, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.border)),
              child: RichContent(html: L.comprehension, fontSize: 13, color: p.text),
            ),
            const SizedBox(height: 12),
          ],
          RichContent(html: L.question, fontSize: 16, color: p.text),
          const SizedBox(height: 14),
          if (L.options.isNotEmpty)
            ...L.options.map(_optionRow)
          else
            _numericAnswer(),
          if (L.solutionHtml.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: p.border),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.lightbulb_outline, size: 18, color: p.accent),
              const SizedBox(width: 6),
              Text('Explanation',
                  style: TextStyle(fontWeight: FontWeight.w700, color: p.accent, fontSize: 15)),
            ]),
            const SizedBox(height: 8),
            RichContent(html: L.solutionHtml, fontSize: 14, color: p.text),
          ],
        ],
      ),
    );
  }

  Widget _statusChip() {
    final label = q.isCorrect ? 'Correct' : q.isIncorrect ? 'Incorrect' : 'Skipped';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _statusColor)),
    );
  }

  Widget _optionRow(SolutionOption o) {
    // Correct = green; your wrong pick = red; otherwise neutral.
    Color? bg;
    Color border = p.border;
    IconData? icon;
    Color iconColor = Colors.transparent;
    if (o.isCorrect) {
      bg = PlayerPalette.correct.withValues(alpha: p.isDark ? 0.16 : 0.08);
      border = PlayerPalette.correct;
      icon = Icons.check_circle;
      iconColor = PlayerPalette.correct;
    } else if (o.isSelected) {
      bg = PlayerPalette.incorrect.withValues(alpha: p.isDark ? 0.16 : 0.07);
      border = PlayerPalette.incorrect;
      icon = Icons.cancel;
      iconColor = PlayerPalette.incorrect;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (o.slNo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 1),
              child: Text('${o.slNo}.',
                  style: TextStyle(fontWeight: FontWeight.w600, color: p.text)),
            ),
          Expanded(child: RichContent(html: o.text, fontSize: 14, color: p.text)),
          if (icon != null) Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          if (o.isSelected && !o.isCorrect)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('You',
                  style: TextStyle(fontSize: 10, color: PlayerPalette.incorrect, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _numericAnswer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kv('Your answer', q.yourAnswer.isEmpty ? '—' : q.yourAnswer,
            q.isCorrect ? PlayerPalette.correct : (q.yourAnswer.isEmpty ? p.textMuted : PlayerPalette.incorrect)),
        const SizedBox(height: 6),
        _kv('Correct answer', q.correctAnswer.isEmpty ? '—' : q.correctAnswer, PlayerPalette.correct),
      ],
    );
  }

  Widget _kv(String k, String v, Color color) => Row(
        children: [
          SizedBox(width: 120, child: Text(k, style: TextStyle(fontSize: 13, color: p.textMuted))),
          Expanded(child: Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color))),
        ],
      );
}
