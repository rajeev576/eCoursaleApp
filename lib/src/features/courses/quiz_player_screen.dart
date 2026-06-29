import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/widgets/rich_content.dart';
import '../../data/models/quiz_models.dart';
import '../tests/numeric_keypad.dart';
import '../tests/player_theme.dart';

/// Native QUIZ player. Quizzes embed their correct answers, so this scores
/// LOCALLY (web parity) then records the attempt for gamification. One question
/// at a time, MCQ/MSQ/numeric/FIB, palette, and an inline result with per-question
/// correctness + explanation. Light/dark follows the device; brand accent.
class QuizPlayerScreen extends ConsumerStatefulWidget {
  const QuizPlayerScreen({super.key, required this.quizUuid, this.title = 'Quiz'});
  final String quizUuid;
  final String title;
  @override
  ConsumerState<QuizPlayerScreen> createState() => _QuizPlayerScreenState();
}

class _QAns {
  dynamic value;       // String (mcq/num/fib) or List<String> (msq)
  bool answered = false;
}

class _QuizPlayerScreenState extends ConsumerState<QuizPlayerScreen> {
  QuizPaper? _quiz;
  String? _error;
  bool _loading = true;
  bool _submitted = false;
  String _lang = 'en';
  int _index = 0;
  final Map<int, _QAns> _answers = {};
  final _fibCtrl = TextEditingController();
  final _startedAt = DateTime.now();
  int _remaining = 0;      // seconds left (0 = untimed)
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fibCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    final mins = _quiz?.durationMinutes ?? 0;
    if (mins <= 0) return; // untimed quiz
    _remaining = mins * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 0) {
        _timer?.cancel();
        if (!_submitted) _finishAndScore(); // auto-submit at time-up
      } else {
        setState(() => _remaining--);
      }
    });
  }

  String _fmtTime(int s) {
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  Future<void> _load() async {
    try {
      final quiz = await ref.read(contentRepoProvider).quizData(widget.quizUuid);
      for (final q in quiz.questions) {
        _answers[q.id] = _QAns();
      }
      final codes = quiz.languageCodes;
      setState(() {
        _quiz = quiz;
        _lang = codes.contains('en') ? 'en' : (codes.isNotEmpty ? codes.first : 'en');
        _loading = false;
      });
      _startTimer(); // no-op for untimed quizzes
    } catch (e) {
      setState(() {
        _error = apiErrorMessage(e, fallback: 'Could not load the quiz.');
        _loading = false;
      });
    }
  }

  List<QuizQuestion> get _qs => _quiz?.questions ?? [];

  double _score() {
    double s = 0;
    for (final q in _qs) {
      final a = _answers[q.id]!;
      if (!a.answered) continue;
      if (q.isAnswerCorrect(a.value)) {
        s += q.marks;
      } else {
        s -= q.penalty;
      }
    }
    return s < 0 ? 0 : s;
  }

  int _correctCount() =>
      _qs.where((q) => _answers[q.id]!.answered && q.isAnswerCorrect(_answers[q.id]!.value)).length;

  Future<void> _submit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = PlayerPalette.of(ctx);
        final answered = _answers.values.where((a) => a.answered).length;
        return AlertDialog(
          backgroundColor: p.surface,
          title: Text('Submit quiz?', style: TextStyle(color: p.text)),
          content: Text('$answered of ${_qs.length} answered.', style: TextStyle(color: p.textMuted)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
          ],
        );
      },
    );
    if (ok != true) return;
    _finishAndScore();
  }

  /// Score locally + record the attempt + show the result. Called by the Submit
  /// button (after confirm) and by the timer at time-up (no confirm).
  Future<void> _finishAndScore() async {
    if (_submitted) return;
    _timer?.cancel();
    setState(() => _submitted = true);
    // Record the attempt (best-effort — local score is the source of truth here).
    try {
      await ref.read(contentRepoProvider).recordQuizAttempt(
            widget.quizUuid, _score(), _quiz!.totalMarks,
            DateTime.now().difference(_startedAt).inSeconds);
    } catch (_) {/* keep showing the result even if recording fails */}
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerPalette.of(context);
    if (_loading) {
      return Scaffold(backgroundColor: p.bg, body: Center(child: CircularProgressIndicator(color: p.accent)));
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(backgroundColor: p.surface, foregroundColor: p.text, elevation: 0),
        body: Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: p.text)))),
      );
    }
    if (_submitted) return _result(p);
    return _player(p);
  }

  // ── attempt UI ──
  Widget _player(PlayerPalette p) {
    final q = _qs[_index];
    final a = _answers[q.id]!;
    final L = q.lang(_lang);
    if (q.isFreeText) {
      final v = (a.value ?? '').toString();
      if (_fibCtrl.text != v) _fibCtrl.text = v;
    }
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.surface, foregroundColor: p.text, elevation: 0,
        title: Text(_quiz!.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          // Countdown for timed quizzes (auto-submits at 0).
          if (_timer != null)
            Center(child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _remaining < 60 ? PlayerPalette.incorrect : p.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined, size: 15,
                      color: _remaining < 60 ? Colors.white : p.text),
                  const SizedBox(width: 4),
                  Text(_fmtTime(_remaining),
                      style: TextStyle(
                          color: _remaining < 60 ? Colors.white : p.text,
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            )),
          if (_quiz!.languageCodes.length > 1)
            PopupMenuButton<String>(
              icon: Icon(Icons.translate, color: p.text), color: p.surface, initialValue: _lang,
              onSelected: (c) => setState(() => _lang = c),
              itemBuilder: (_) => [
                for (final c in _quiz!.languageCodes)
                  PopupMenuItem(value: c, child: Text(_quiz!.languageName(c), style: TextStyle(color: p.text))),
              ],
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Container(
            color: p.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Text('Q ${_index + 1} / ${_qs.length}',
                  style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (q.marks > 0)
                Text('+${_fmt(q.marks)}  -${_fmt(q.penalty)}',
                    style: TextStyle(color: p.textMuted, fontSize: 12)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RichContent(html: L.question, fontSize: 16, color: p.text),
                const SizedBox(height: 16),
                if (q.isNumeric)
                  NumericKeypad(
                    value: (a.value ?? '').toString(),
                    onChanged: (v) => setState(() { a.value = v; a.answered = v.trim().isNotEmpty; }),
                  )
                else if (q.isFreeText)
                  TextField(
                    controller: _fibCtrl,
                    style: TextStyle(color: p.text),
                    decoration: InputDecoration(
                      labelText: 'Type your answer', labelStyle: TextStyle(color: p.textMuted),
                      filled: true, fillColor: p.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: p.border)),
                    ),
                    onChanged: (v) => setState(() { a.value = v; a.answered = v.trim().isNotEmpty; }),
                  )
                else
                  ...L.options.map((o) => _optionTile(p, q, a, o)),
              ]),
            ),
          ),
          _bottomBar(p, a),
        ]),
      ),
    );
  }

  Widget _optionTile(PlayerPalette p, QuizQuestion q, _QAns a, QuizOption o) {
    final selected = q.isMulti
        ? (a.value is List && (a.value as List).contains(o.slNo))
        : a.value == o.slNo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? p.accent.withValues(alpha: 0.10) : p.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            if (q.isMulti) {
              final list = (a.value is List) ? List<String>.from(a.value) : <String>[];
              list.contains(o.slNo) ? list.remove(o.slNo) : list.add(o.slNo);
              a.value = list;
              a.answered = list.isNotEmpty;
            } else {
              a.value = o.slNo;
              a.answered = true;
            }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? p.accent : p.border, width: selected ? 1.6 : 1),
            ),
            child: Row(children: [
              Icon(
                q.isMulti
                    ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
                    : (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                color: selected ? p.accent : p.textFaint, size: 22),
              const SizedBox(width: 12),
              Expanded(child: RichContent(html: o.text, fontSize: 15, color: p.text)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(PlayerPalette p, _QAns a) {
    final last = _index >= _qs.length - 1;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.border))),
        child: Row(children: [
          IconButton(
            onPressed: _index > 0 ? () => setState(() => _index--) : null,
            icon: const Icon(Icons.chevron_left)),
          TextButton(
            onPressed: () => setState(() { a.value = null; a.answered = false; _fibCtrl.clear(); }),
            child: const Text('Clear')),
          const Spacer(),
          if (last)
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent),
              child: const Text('Submit'))
          else
            FilledButton(
              onPressed: () => setState(() => _index++),
              style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent),
              child: const Text('Next')),
        ]),
      ),
    );
  }

  // ── result UI (local correctness + explanations) ──
  Widget _result(PlayerPalette p) {
    final score = _score();
    final total = _quiz!.totalMarks;
    final correct = _correctCount();
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.surface, foregroundColor: p.text, elevation: 0,
        title: const Text('Quiz Result'), automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Done', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)))],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [p.accent, Color.alphaBlend(Colors.black.withValues(alpha: 0.22), p.accent)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(children: [
                Text('${_fmt(score)} / ${_fmt(total)}',
                    style: TextStyle(color: p.onAccent, fontSize: 40, fontWeight: FontWeight.w800)),
                Text('$correct of ${_qs.length} correct',
                    style: TextStyle(color: p.onAccent.withValues(alpha: 0.9))),
              ]),
            ),
            const SizedBox(height: 16),
            ..._qs.asMap().entries.map((e) => _solutionCard(p, e.key, e.value)),
          ],
        ),
      ),
    );
  }

  Widget _solutionCard(PlayerPalette p, int idx, QuizQuestion q) {
    final a = _answers[q.id]!;
    final L = q.lang(_lang);
    final correct = a.answered && q.isAnswerCorrect(a.value);
    final statusColor = !a.answered
        ? PlayerPalette.unattempted
        : (correct ? PlayerPalette.correct : PlayerPalette.incorrect);
    final label = !a.answered ? 'Skipped' : (correct ? 'Correct' : 'Incorrect');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Q${idx + 1}', style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
            child: Text(label, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 8),
        RichContent(html: L.question, fontSize: 15, color: p.text),
        const SizedBox(height: 10),
        if (q.hasOptions)
          ...L.options.map((o) {
            final picked = q.isMulti
                ? (a.value is List && (a.value as List).contains(o.slNo))
                : a.value == o.slNo;
            Color border = p.border;
            Color? bg;
            if (o.isCorrect) { border = PlayerPalette.correct; bg = PlayerPalette.correct.withValues(alpha: p.isDark ? 0.16 : 0.08); }
            else if (picked) { border = PlayerPalette.incorrect; bg = PlayerPalette.incorrect.withValues(alpha: p.isDark ? 0.16 : 0.07); }
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
              child: Row(children: [
                Expanded(child: RichContent(html: o.text, fontSize: 14, color: p.text)),
                if (o.isCorrect) const Icon(Icons.check_circle, size: 18, color: PlayerPalette.correct)
                else if (picked) const Icon(Icons.cancel, size: 18, color: PlayerPalette.incorrect),
              ]),
            );
          })
        else
          Text('Correct answer: ${_correctAnswerText(q)}',
              style: const TextStyle(color: PlayerPalette.correct, fontWeight: FontWeight.w600)),
        if (L.explanation.trim().isNotEmpty && L.explanation.trim() != 'NA') ...[
          const SizedBox(height: 8),
          Divider(color: p.border),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.lightbulb_outline, size: 16, color: p.accent),
            const SizedBox(width: 6),
            Text('Explanation', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          RichContent(html: L.explanation, fontSize: 14, color: p.text),
        ],
      ]),
    );
  }

  String _correctAnswerText(QuizQuestion q) {
    final ca = q.correctAnswer;
    if (ca is Map && ca['start'] != null) return '${ca['start']} – ${ca['end']}';
    return (ca ?? '—').toString();
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
