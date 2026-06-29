import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../core/secure_screen.dart';
import '../../core/widgets/rich_content.dart';
import '../../data/models/test_models.dart';
import 'numeric_keypad.dart';
import 'player_theme.dart';
import 'question_watermark.dart';
import 'scientific_calculator.dart';
import 'test_instructions_screen.dart';
import 'test_palette_drawer.dart';
import 'test_summary_dialog.dart';

/// Native test-taking engine, styled to match Testbook's player (compact header
/// with timer, section tabs, per-question meta strip, bordered option tiles,
/// Mark/Clear/Save&Next action bar, a slide-in question palette, and the
/// summary submit/resume dialogs). Light/dark FOLLOWS the device; the school's
/// primary colour is the brand accent.
///
/// Renders natively (sections, questions, timer, navigation, mark-for-review,
/// autosave) and submits answers to the BACKEND scorer — no native scoring, so
/// there's a single source of truth. Supports MCQ, MSQ (multi), numeric & FIB.
class TestPlayerScreen extends ConsumerStatefulWidget {
  const TestPlayerScreen({super.key, required this.testUuid, this.authMode = false, this.fresh = false});
  final String testUuid;
  final bool authMode;
  final bool fresh; // force a brand-new attempt (Reattempt) instead of resuming

  @override
  ConsumerState<TestPlayerScreen> createState() => _TestPlayerScreenState();
}

class _AnswerState {
  dynamic value;          // String (mcq/num) or List<String> (msq)
  bool answered = false;
  bool markedForReview = false;
  bool seen = false;      // visited at least once (for the palette "unseen" state)
  bool isSkip = false;    // explicit "Not Attempted" (template skip option)
}

class _TestPlayerScreenState extends ConsumerState<TestPlayerScreen> {
  TestPaper? _paper;
  String? _attemptId;
  String? _error;
  bool _loading = true;
  bool _submitting = false;
  bool _started = false;           // false → show the instruction/language screen
  String _lang = 'en';             // selected display language (live switchable)

  int _secIndex = 0;               // current SECTION index
  int _qIndex = 0;                 // question index WITHIN the current section
  final Set<int> _lockedSections = {}; // sections locked-on-exit the student left
  final Set<int> _submittedSections = {}; // sections already submitted (sectional mode)
  final Map<String, _AnswerState> _answers = {}; // by question uuid
  final _numCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _passageKey = GlobalKey();   // the passage/comprehension block (for "jump")
  bool _passageOffscreen = false;    // show the "Jump to Comprehension" pill

  int _remaining = 0;             // seconds
  Timer? _timer;
  Timer? _autosave;
  bool _paused = false;           // pause overlay (timer frozen)

  @override
  void initState() {
    super.initState();
    SecureScreen.enable(); // block screenshots / screen-record during the test
    _scrollCtrl.addListener(_onScroll);
    _start();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    _timer?.cancel();
    _autosave?.cancel();
    _numCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// When the passage/comprehension block has a key (this question has one) and
  /// the user has scrolled it above the viewport, show a "Jump to Comprehension"
  /// pill (like the web test window).
  void _onScroll() {
    final ctx = _passageKey.currentContext;
    final hasPassage = ctx != null;
    bool offscreen = false;
    if (hasPassage) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final dy = box.localToGlobal(Offset.zero).dy;
        offscreen = dy + box.size.height < 0; // scrolled fully above the top
      }
    }
    if (offscreen != _passageOffscreen) {
      setState(() => _passageOffscreen = offscreen);
    }
  }

  void _jumpToComprehension() {
    final ctx = _passageKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  Future<void> _start() async {
    try {
      final repo = ref.read(contentRepoProvider);
      final res = await repo.testPaper(widget.testUuid, authMode: widget.authMode);
      if (res['status'] != 'success' || res['data'] == null) {
        throw Exception(res['error'] ?? 'Could not load test.');
      }
      final paper = TestPaper.fromJson(Map<String, dynamic>.from(res['data']));
      final attempt = await repo.createAttempt(widget.testUuid, authMode: widget.authMode, fresh: widget.fresh);
      for (final q in paper.allQuestions) {
        _answers[q.uuid] = _AnswerState();
      }
      // Default language: English if present, else the first available.
      final codes = paper.languageCodes;
      setState(() {
        _paper = paper;
        _attemptId = attempt;
        _remaining = paper.durationSeconds;
        _lang = codes.contains('en') ? 'en' : (codes.isNotEmpty ? codes.first : 'en');
        _loading = false;
      });
      // Show the instruction/language screen first (don't start the timer yet).
    } catch (e) {
      // If the session is gone (token refresh failed), don't strand the student
      // on a dead error — invalidate the session so the router sends them to
      // /login, where they can sign back in and re-open the test.
      if (e is SessionExpired) {
        ref.invalidate(hasSessionProvider);
        if (mounted) {
          context.go('/login');
        }
        return;
      }
      setState(() {
        _error = apiErrorMessage(e, fallback: 'Could not load the test.');
        _loading = false;
      });
    }
  }

  /// Called from the instruction screen's "Start test" button — NOW the timer runs.
  void _beginTest() {
    setState(() {
      _started = true;
      _secIndex = 0;
      _qIndex = 0;
      // Sectional-submit tests run a per-SECTION timer; others a single overall one.
      _remaining = _sectional
          ? (_sections.isNotEmpty ? _sections.first.timeSeconds : _paper!.durationSeconds)
          : _paper!.durationSeconds;
    });
    _markSeen();
    _startTimers();
  }

  void _startTimers() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_paused) return; // frozen while the pause overlay is up
      if (_remaining <= 0) {
        _timer?.cancel();
        // In sectional mode, time-up submits the SECTION (auto-advances); the
        // last section's time-up submits the whole test.
        if (_sectional && !_isLastSection) {
          _submitSection(auto: true);
        } else {
          _submit(auto: true);
        }
      } else {
        setState(() => _remaining--);
      }
    });
    // Periodic autosave every 20s (skipped while paused).
    _autosave = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_paused) _save();
    });
  }

  /// Pause/resume the test — freezes the timer and shows a blocking overlay so
  /// the student can't read/answer questions while paused.
  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) _save();
  }

  // ── section helpers ──
  bool get _sectional => _paper?.sectionalSubmit ?? false;
  List<TestSection> get _sections => _paper?.sections ?? const [];
  TestSection get _section => _sections[_secIndex];
  bool get _isLastSection => _secIndex >= _sections.length - 1;
  List<TestQuestion> get _qs => _section.questions; // questions of CURRENT section
  TestQuestion get _current => _qs[_qIndex];
  List<TestQuestion> get _allQs => _paper?.allQuestions ?? [];

  void _markSeen() {
    if (_qs.isEmpty) return;
    _answers[_current.uuid]?.seen = true;
  }

  /// Switch to section [i]. Enforces sectional-submit (no going back / to a
  /// submitted section) and lock-on-exit (CAT) rules; records a leaving section
  /// that locks on exit.
  void _gotoSection(int i) {
    if (i == _secIndex) return;
    if (_lockedSections.contains(i) || _submittedSections.contains(i)) {
      _snack('This section is locked.');
      return;
    }
    if (_sectional && i < _secIndex) {
      _snack('You can’t go back to a previous section.');
      return;
    }
    // Leaving a lock-on-exit section → lock it.
    if (_section.lockOnExit) _lockedSections.add(_secIndex);
    _save();
    setState(() {
      _secIndex = i;
      _qIndex = 0;
    });
    _markSeen();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  /// Submit the current section and advance to the next (sectional-submit mode).
  Future<void> _submitSection({bool auto = false}) async {
    if (!auto) {
      final ok = await showTestSummaryDialog(
        context: context,
        title: 'Are you sure you want to submit the section?',
        remaining: _remaining,
        attempted: _sectionAttempted(),
        unattempted: _qs.length - _sectionAttempted(),
        marked: _sectionMarked(),
        confirmLabel: 'Yes',
        cancelLabel: 'No',
      );
      if (ok != true) return;
    }
    await _save();
    _submittedSections.add(_secIndex);
    final next = _secIndex + 1;
    if (next >= _sections.length) {
      _submit(auto: true); // was the last section → finish the test
      return;
    }
    setState(() {
      _secIndex = next;
      _qIndex = 0;
      _remaining = _sections[next].timeSeconds; // next section's own timer
    });
    _markSeen();
  }

  Map<String, dynamic> _answersPayload() {
    // ALL questions across ALL sections (the backend scores the whole paper).
    final out = <String, dynamic>{};
    int i = 0;
    for (final q in _allQs) {
      final a = _answers[q.uuid]!;
      out['$i'] = {
        'questionUUID': q.uuid,
        'answered': a.answered,
        'markedForReview': a.markedForReview,
        'value': a.value,
        // Explicit "Not Attempted" (template skip option). Backend persists this
        // to AttemptedQuestion.skipped_flag so its scorer routes through the
        // explicit-skip branch (0 marks, no negative).
        'isSkip': a.isSkip,
      };
      i++;
    }
    return out;
  }

  Future<void> _save() async {
    if (_attemptId == null) return;
    try {
      await ref.read(contentRepoProvider).saveAnswers(_attemptId!, _answersPayload(), authMode: widget.authMode);
    } catch (_) {/* will retry on next tick / submit */}
  }

  Future<void> _submit({bool auto = false}) async {
    if (_attemptId == null || _submitting) return;
    if (!auto) {
      final ok = await showTestSummaryDialog(
        context: context,
        title: 'Are you sure you want to submit the test?',
        remaining: _remaining,
        attempted: _answeredCount(),
        unattempted: _allQs.length - _answeredCount(),
        marked: _markedCount(),
        confirmLabel: 'Yes',
        cancelLabel: 'No',
      );
      if (ok != true) return;
    }
    setState(() => _submitting = true);
    _timer?.cancel();
    _autosave?.cancel();
    try {
      await _save(); // final save
      final res = await ref.read(contentRepoProvider).submitTest(_attemptId!, authMode: widget.authMode);
      final resultId = (res['test_result'] ?? _attemptId).toString();
      // ?review=1 → the result screen prompts for a rating once (fresh submit only).
      if (mounted) context.pushReplacement('/test-result/$resultId?review=1');
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not submit. Check connection and try again.')));
      }
    }
  }

  int _answeredCount() => _answers.values.where((a) => a.answered).length;
  int _markedCount() => _answers.values.where((a) => a.markedForReview).length;
  int _sectionAttempted() => _qs.where((q) => _answers[q.uuid]?.answered ?? false).length;
  int _sectionMarked() => _qs.where((q) => _answers[q.uuid]?.markedForReview ?? false).length;

  String _fmt(int s) {
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(sec)}';
  }

  // ── question palette / state ──

  /// Open the slide-in question palette (Testbook-style drawer).
  void _openPalette() {
    _save();
    showTestPaletteDrawer(
      context: context,
      sections: _sections,
      answers: { for (final e in _answers.entries) e.key: PaletteQState(
        answered: e.value.answered,
        marked: e.value.markedForReview,
        seen: e.value.seen,
      ) },
      currentSection: _secIndex,
      currentQuestion: _qIndex,
      sectional: _sectional,
      lockedSections: _lockedSections,
      submittedSections: _submittedSections,
      onJump: (sec, q) {
        Navigator.pop(context);
        _jumpTo(sec, q);
      },
      onSubmitSection: _sectional && !_isLastSection
          ? () { Navigator.pop(context); _submitSection(); }
          : null,
      onSubmitTest: () { Navigator.pop(context); _submit(); },
      onViewInstructions: () {
        Navigator.pop(context);
        _showInstructionsSheet();
      },
      langNameOf: _paper!.languageName,
    );
  }

  void _jumpTo(int sec, int q) {
    if (sec != _secIndex) {
      _gotoSection(sec);
      if (_secIndex != sec) return; // jump blocked by lock/sectional rule
    }
    setState(() => _qIndex = q);
    _markSeen();
    _scrollToTop();
  }

  void _showInstructionsSheet() {
    final p = PlayerPalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text('Instructions',
                style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 12),
            if (_paper!.instructions.isEmpty)
              Text(
                'The test has ${_allQs.length} questions'
                '${_paper!.durationMinutes > 0 ? ' and a ${_paper!.durationMinutes}-minute timer' : ''}. '
                'Your answers are saved automatically.',
                style: TextStyle(color: p.textMuted, height: 1.5),
              )
            else
              ..._paper!.instructions.map((b) {
                final v = (b['value'] ?? '').toString();
                if (v.trim().isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3, right: 8),
                      child: Icon(Icons.check_circle_outline, size: 16, color: p.accent),
                    ),
                    Expanded(child: RichContent(html: v, fontSize: 14, color: p.text)),
                  ]),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _scrollToTop() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerPalette.of(context);
    if (_loading) {
      return Scaffold(
        backgroundColor: p.bg,
        body: Center(child: CircularProgressIndicator(color: p.accent)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(backgroundColor: p.surface, foregroundColor: p.text, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 44, color: p.textMuted),
                const SizedBox(height: 14),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: p.text)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    setState(() { _error = null; _loading = true; });
                    _start();
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: p.accent, foregroundColor: p.onAccent),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text('Go back', style: TextStyle(color: p.textMuted)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Pre-test: polished native instruction + language screen (the web's 2 pages,
    // merged into one app-native screen). Timer starts only on "Start test".
    if (!_started) {
      return TestInstructionsScreen(
        paper: _paper!,
        selectedLang: _lang,
        onLangChanged: (c) => setState(() => _lang = c),
        onStart: _beginTest,
      );
    }
    final q = _current;
    final a = _answers[q.uuid]!;
    // Only the FREE-TEXT (FIB/TITA) field uses the controller; sync without
    // clobbering the caret when the text already matches. The NUM/NAT keypad
    // manages its own value through _AnswerState, so it must NOT touch _numCtrl.
    if (q.isFreeText) {
      final v = (a.value ?? '').toString();
      if (_numCtrl.text != v) _numCtrl.text = v;
    }
    final L = q.lang(_lang); // content in the chosen language

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(context: context, builder: (_) {
          final pp = PlayerPalette.of(context);
          return AlertDialog(
            backgroundColor: pp.surface,
            title: Text('Leave test?', style: TextStyle(color: pp.text)),
            content: Text('Your answers are saved, but the test stays in progress.',
                style: TextStyle(color: pp.textMuted)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
            ],
          );
        });
        if (leave == true && mounted) {
          await _save();
          if (mounted && context.mounted) context.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: p.bg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(p),
                if (_sections.length > 1) _sectionTabs(p),
                _metaStrip(p, q, a),
                Expanded(
                  child: Stack(
                    children: [
                      // Faint school-logo watermark behind the question (web parity).
                      const QuestionWatermark(),
                      SingleChildScrollView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shared passage / case-study (4–5 questions reference one).
                        if (q.group != null && q.group!.text(_lang).isNotEmpty) ...[
                          KeyedSubtree(key: _passageKey, child: PassageBlock(group: q.group!, lang: _lang)),
                          const SizedBox(height: 14),
                        ],
                        if (L.comprehension.isNotEmpty) ...[
                          Container(
                            key: q.group == null ? _passageKey : null,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: p.surface, borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: p.border)),
                            // HTML + LaTeX + images, rendered like the web test window.
                            // Images render full-width (e.g. a pie-chart figure).
                            child: RichContent(html: L.comprehension, fontSize: 14, color: p.text),
                          ),
                          const SizedBox(height: 14),
                        ],
                        // Question text may contain HTML tags, LaTeX and inline images.
                        RichContent(html: L.question, fontSize: 16, color: p.text),
                        const SizedBox(height: 18),
                        // Input area depends on the question type (web parity):
                        //   NUM / NAT  → on-screen numeric keypad
                        //   FIB / TITA → free-text field (system keyboard)
                        //   MCQ        → single-select option tiles
                        //   MSQ/MAMCQ  → multi-select option tiles
                        if (q.isNumericKeypad)
                          NumericKeypad(
                            value: (a.value ?? '').toString(),
                            onChanged: (v) {
                              setState(() {
                                a.value = v;
                                a.answered = v.trim().isNotEmpty;
                              });
                            },
                          )
                        else if (q.isFreeText)
                          TextField(
                            controller: _numCtrl,
                            keyboardType: TextInputType.text,
                            style: TextStyle(color: p.text),
                            decoration: InputDecoration(
                              labelText: 'Type your answer',
                              labelStyle: TextStyle(color: p.textMuted),
                              filled: true,
                              fillColor: p.surface,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: p.border)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: p.border)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: p.accent, width: 1.5)),
                            ),
                            onChanged: (v) {
                              a.value = v;
                              a.answered = v.trim().isNotEmpty;
                              setState(() {});
                            },
                          )
                        else
                          ...() {
                            final cfg = _paper!.configFor(q.type);
                            // The template can mark the LAST option as an explicit
                            // "Not Attempted / Skip" choice (e.g. some commission
                            // exams). It's rendered distinctly and selecting it
                            // sets isSkip (the backend scores it as an explicit skip).
                            final skipIdx = (cfg.lastOptIsSkip && L.options.isNotEmpty)
                                ? L.options.length - 1
                                : -1;
                            return L.options.asMap().entries.map((e) =>
                                _optionTile(p, q, a, e.value, e.key, isSkipOption: e.key == skipIdx));
                          }(),
                      ],
                    ),
                  ),
                      // "Jump to Comprehension" pill — appears when a passage/
                      // comprehension is scrolled above the viewport.
                      if (_passageOffscreen)
                        Positioned(
                          left: 0, right: 0, bottom: 12,
                          child: Center(
                            child: Material(
                              color: p.surfaceAlt,
                              elevation: 4,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _jumpToComprehension,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Text('Jump to Comprehension',
                                        style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Icon(Icons.keyboard_arrow_up, size: 18, color: p.text),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Pause overlay — covers the questions while paused.
                      if (_paused)
                        Positioned.fill(
                          child: Container(
                            color: p.bg,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.pause_circle_filled, size: 64, color: p.accent),
                                const SizedBox(height: 16),
                                Text('Test paused',
                                    style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text('The timer is frozen.',
                                    style: TextStyle(color: p.textMuted)),
                                const SizedBox(height: 24),
                                FilledButton.icon(
                                  onPressed: _togglePause,
                                  style: FilledButton.styleFrom(
                                      backgroundColor: p.accent, foregroundColor: p.onAccent),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Resume test'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _bottomBar(p, a),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── header: pause + timer + name + lang toggle + palette ──
  Widget _header(PlayerPalette p) {
    return Container(
      color: p.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          // Working pause button — freezes the timer and blurs the questions.
          IconButton(
            tooltip: _paused ? 'Resume' : 'Pause',
            visualDensity: VisualDensity.compact,
            onPressed: _togglePause,
            icon: Icon(_paused ? Icons.play_circle_outline : Icons.pause_circle_outline,
                color: p.textMuted, size: 26),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fmt(_remaining),
                  style: TextStyle(
                    color: _remaining < 60 ? PlayerPalette.incorrect : p.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  _paper!.testName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          // Scientific calculator (GATE-style) — only when the test allows it.
          if (_paper!.showCalculator)
            IconButton(
              tooltip: 'Calculator',
              visualDensity: VisualDensity.compact,
              onPressed: () => showScientificCalculator(context),
              icon: Icon(Icons.calculate_outlined, color: p.text),
            ),
          if (_paper!.languageCodes.length > 1) _langToggle(p),
          IconButton(
            tooltip: 'Question palette',
            visualDensity: VisualDensity.compact,
            onPressed: _openPalette,
            icon: Icon(Icons.menu, color: p.text),
          ),
        ],
      ),
    );
  }

  /// Compact language toggle that cycles the available languages (like the web's
  /// E/अ button). Long-press opens the full picker when there are 3+ languages.
  Widget _langToggle(PlayerPalette p) {
    final codes = _paper!.languageCodes;
    final i = codes.indexOf(_lang);
    final nextLabel = codes.length == 2
        ? _paper!.languageName(codes[(i + 1) % codes.length]).substring(0, 1)
        : _paper!.languageName(_lang).substring(0, 1);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        if (codes.length == 2) {
          setState(() => _lang = codes[(i + 1) % codes.length]);
        } else {
          _showLangPicker(p, codes);
        }
      },
      onLongPress: () => _showLangPicker(p, codes),
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.translate, size: 14, color: p.text),
          const SizedBox(width: 4),
          Text(nextLabel, style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }

  void _showLangPicker(PlayerPalette p, List<String> codes) {
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: p.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          for (final c in codes)
            ListTile(
              title: Text(_paper!.languageName(c), style: TextStyle(color: p.text)),
              trailing: c == _lang ? Icon(Icons.check, color: p.accent) : null,
              onTap: () { setState(() => _lang = c); Navigator.pop(context); },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── section tabs ──
  Widget _sectionTabs(PlayerPalette p) {
    return Container(
      color: p.surface,
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _sections.length,
        itemBuilder: (_, i) {
          final s = _sections[i];
          final active = i == _secIndex;
          final locked = _lockedSections.contains(i);
          final submitted = _submittedSections.contains(i);
          final disabled = locked || submitted || (_sectional && i < _secIndex);
          return InkWell(
            onTap: disabled ? null : () => _gotoSection(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? p.accent : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  s.title.isEmpty ? 'Section ${i + 1}' : s.title,
                  style: TextStyle(
                    color: active ? p.text : (disabled ? p.textFaint : p.textMuted),
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (locked || submitted) ...[
                  const SizedBox(width: 5),
                  Icon(Icons.lock, size: 12, color: p.textFaint),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── meta strip: Q-number + marks/penalty chips + mark-for-review ──
  Widget _metaStrip(PlayerPalette p, TestQuestion q, _AnswerState a) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border, width: 0.6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        // question number bubble
        Container(
          width: 30, height: 30, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            shape: BoxShape.circle,
            border: Border.all(color: p.border),
          ),
          child: Text('${_qIndex + 1}',
              style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Container(width: 1, height: 18, color: p.border),
        const SizedBox(width: 10),
        if (q.marks.isNotEmpty) _markChip(p, '+ ${q.marks}', positive: true),
        if (q.penalty.isNotEmpty) ...[
          const SizedBox(width: 6),
          _markChip(p, '- ${q.penalty.replaceAll('-', '')}', positive: false),
        ],
        const Spacer(),
        // mark for review (star) — wired to the answer state
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: a.markedForReview ? 'Unmark' : 'Mark for review',
          onPressed: () => setState(() => a.markedForReview = !a.markedForReview),
          icon: Icon(
            a.markedForReview ? Icons.star : Icons.star_border,
            size: 22,
            color: a.markedForReview ? PlayerPalette.marked : p.textFaint,
          ),
        ),
      ]),
    );
  }

  Widget _markChip(PlayerPalette p, String label, {required bool positive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: positive ? p.positiveChipBg : p.negativeChipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              color: positive ? p.positiveChipText : p.negativeChipText,
              fontWeight: FontWeight.w700,
              fontSize: 12)),
    );
  }

  // ── option tile (Testbook bordered style) ──
  Widget _optionTile(PlayerPalette p, TestQuestion q, _AnswerState a, TestOption opt, int idx,
      {bool isSkipOption = false}) {
    final selected = q.isMulti
        ? (a.value is List && (a.value as List).contains(opt.slNo))
        : a.value == opt.slNo;
    final label = opt.slNo.isNotEmpty ? opt.slNo : '${idx + 1}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? p.accent.withValues(alpha: 0.10) : p.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              if (isSkipOption) {
                // Explicit "Not Attempted": single-select the skip option, clear
                // any real answer, and flag isSkip for the backend scorer.
                a.value = opt.slNo;
                a.answered = true;
                a.isSkip = true;
                return;
              }
              // Picking a real option always clears a prior skip.
              a.isSkip = false;
              if (q.isMulti) {
                final list = (a.value is List) ? List<String>.from(a.value) : <String>[];
                if (list.contains(opt.slNo)) {
                  list.remove(opt.slNo);
                } else {
                  list.add(opt.slNo);
                }
                a.value = list;
                a.answered = list.isNotEmpty;
              } else {
                a.value = opt.slNo;
                a.answered = true;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? p.accent : p.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // number / checkbox indicator (skip option shows a distinct icon)
                if (isSkipOption)
                  Icon(selected ? Icons.block : Icons.block_outlined,
                      color: selected ? p.accent : p.textFaint, size: 22)
                else if (q.isMulti)
                  Icon(
                    selected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: selected ? p.accent : p.textFaint, size: 22,
                  )
                else
                  Text('$label.',
                      style: TextStyle(
                        color: selected ? p.accent : p.textFaint,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      )),
                const SizedBox(width: 12),
                // Option content can be HTML / LaTeX / an inline diagram image.
                // The skip option always reads "Not Attempted" for clarity.
                Expanded(
                  child: isSkipOption
                      ? Text('Not Attempted (skip)',
                          style: TextStyle(
                              color: p.textMuted, fontSize: 15, fontWeight: FontWeight.w600))
                      : RichContent(html: opt.text, fontSize: 15, color: p.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── bottom action bar: Mark & Next · Clear · Save & Next ──
  Widget _bottomBar(PlayerPalette p, _AnswerState a) {
    final isLastInSection = _qIndex >= _qs.length - 1;
    final lastOverall = isLastInSection && (!_sectional || _isLastSection);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border)),
        ),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() => a.markedForReview = true);
                _next();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: p.text,
                side: BorderSide(color: p.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Mark & Next', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() { a.value = null; a.answered = false; a.isSkip = false; });
                _numCtrl.clear();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: p.text,
                side: BorderSide(color: p.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Clear', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _submitting
                  ? null
                  : () {
                      if (lastOverall) {
                        _submit();
                      } else if (isLastInSection && _sectional) {
                        _submitSection();
                      } else {
                        _saveAndNext();
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: _submitting && lastOverall
                  ? SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: p.onAccent))
                  : Text(
                      lastOverall
                          ? 'Submit'
                          : (isLastInSection && _sectional ? 'Submit Section' : 'Save & Next'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  void _saveAndNext() {
    _maybeWarnMandatory();
    _save();
    _next();
  }

  /// If the template marks the current question's type as MANDATORY and it's
  /// still blank, show a soft warning. We DON'T block (the backend already scores
  /// a blank mandatory question as wrong); this is just so the student knows.
  void _maybeWarnMandatory() {
    if (_qs.isEmpty) return;
    final q = _current;
    final a = _answers[q.uuid]!;
    final cfg = _paper!.configFor(q.type);
    if (cfg.mandatory && !a.answered) {
      _snack('This question must be answered — leaving it blank will be marked wrong.');
    }
  }

  void _next() {
    if (_qIndex < _qs.length - 1) {
      setState(() => _qIndex++);
      _markSeen();
      _scrollToTop();
    }
  }
}
