import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models/test_models.dart';

/// Native test-taking engine. Renders the test natively (sections, questions,
/// timer, navigation, mark-for-review, autosave) and submits answers to the
/// BACKEND scorer (no native scoring — single source of truth). Supports MCQ,
/// MSQ (multi), and numeric/FIB questions.
class TestPlayerScreen extends ConsumerStatefulWidget {
  const TestPlayerScreen({super.key, required this.testUuid, this.authMode = false});
  final String testUuid;
  final bool authMode;

  @override
  ConsumerState<TestPlayerScreen> createState() => _TestPlayerScreenState();
}

class _AnswerState {
  dynamic value;          // String (mcq/num) or List<String> (msq)
  bool answered = false;
  bool markedForReview = false;
}

class _TestPlayerScreenState extends ConsumerState<TestPlayerScreen> {
  TestPaper? _paper;
  String? _attemptId;
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  int _qIndex = 0;                 // index into the flat question list
  final Map<String, _AnswerState> _answers = {}; // by question uuid
  final _numCtrl = TextEditingController();

  int _remaining = 0;             // seconds
  Timer? _timer;
  Timer? _autosave;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autosave?.cancel();
    _numCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final repo = ref.read(contentRepoProvider);
      final res = await repo.testPaper(widget.testUuid, authMode: widget.authMode);
      if (res['status'] != 'success' || res['data'] == null) {
        throw Exception(res['error'] ?? 'Could not load test.');
      }
      final paper = TestPaper.fromJson(Map<String, dynamic>.from(res['data']));
      final attempt = await repo.createAttempt(widget.testUuid, authMode: widget.authMode);
      for (final q in paper.allQuestions) {
        _answers[q.uuid] = _AnswerState();
      }
      setState(() {
        _paper = paper;
        _attemptId = attempt;
        _remaining = paper.durationMinutes * 60;
        _loading = false;
      });
      _startTimers();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _startTimers() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 0) {
        _timer?.cancel();
        _submit(auto: true);
      } else {
        setState(() => _remaining--);
      }
    });
    // Periodic autosave every 20s.
    _autosave = Timer.periodic(const Duration(seconds: 20), (_) => _save());
  }

  List<TestQuestion> get _qs => _paper?.allQuestions ?? [];
  TestQuestion get _current => _qs[_qIndex];

  Map<String, dynamic> _answersPayload() {
    final out = <String, dynamic>{};
    int i = 0;
    for (final q in _qs) {
      final a = _answers[q.uuid]!;
      out['$i'] = {
        'questionUUID': q.uuid,
        'answered': a.answered,
        'markedForReview': a.markedForReview,
        'value': a.value,
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
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Submit test?'),
          content: Text('${_answeredCount()} of ${_qs.length} answered. You can’t change answers after submitting.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
          ],
        ),
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
      if (mounted) context.pushReplacement('/test-result/$resultId');
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not submit. Check connection and try again.')));
      }
    }
  }

  int _answeredCount() => _answers.values.where((a) => a.answered).length;

  String _fmt(int s) {
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center))),
      );
    }
    final q = _current;
    final a = _answers[q.uuid]!;
    if (q.isNumeric) _numCtrl.text = (a.value ?? '').toString();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final leave = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
          title: const Text('Leave test?'),
          content: const Text('Your answers are saved, but the test stays in progress.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave')),
          ],
        ));
        if (leave == true && mounted) {
          await _save();
          if (mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_paper!.testName, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            Center(child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _remaining < 60 ? Colors.red : Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(_fmt(_remaining), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ]),
              ),
            )),
          ],
        ),
        body: Column(
          children: [
            // Question count + palette toggle
            Container(
              color: const Color(0xFFF1F5F9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                Text('Q ${_qIndex + 1} / ${_qs.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${q.marks}  ${q.penalty}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(width: 10),
                TextButton.icon(
                  icon: const Icon(Icons.grid_view, size: 18),
                  label: const Text('Palette'),
                  onPressed: _showPalette,
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (q.comprehension.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                        child: Text(q.comprehension),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(q.question, style: const TextStyle(fontSize: 16, height: 1.4)),
                    const SizedBox(height: 16),
                    if (q.isNumeric)
                      TextField(
                        controller: _numCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'Your answer', border: OutlineInputBorder()),
                        onChanged: (v) {
                          a.value = v.trim();
                          a.answered = v.trim().isNotEmpty;
                          setState(() {});
                        },
                      )
                    else
                      ...q.options.map((opt) => _optionTile(q, a, opt)),
                  ],
                ),
              ),
            ),
            _bottomBar(a),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(TestQuestion q, _AnswerState a, TestOption opt) {
    final selected = q.isMulti
        ? (a.value is List && (a.value as List).contains(opt.slNo))
        : a.value == opt.slNo;
    return Card(
      color: selected ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: q.isMulti
            ? Icon(selected ? Icons.check_box : Icons.check_box_outline_blank,
                color: selected ? Theme.of(context).colorScheme.primary : Colors.black38)
            : Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: selected ? Theme.of(context).colorScheme.primary : Colors.black38),
        title: Text('${opt.slNo}. ${opt.text}'),
        onTap: () {
          setState(() {
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
      ),
    );
  }

  Widget _bottomBar(_AnswerState a) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, -1)),
        ]),
        child: Row(children: [
          IconButton(
            onPressed: _qIndex > 0 ? () => _goto(_qIndex - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          OutlinedButton(
            onPressed: () => setState(() => a.markedForReview = !a.markedForReview),
            child: Text(a.markedForReview ? 'Unmark' : 'Mark for review',
                style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: () {
              setState(() { a.value = null; a.answered = false; });
              _numCtrl.clear();
            },
            child: const Text('Clear'),
          ),
          const Spacer(),
          if (_qIndex < _qs.length - 1)
            FilledButton(onPressed: () => _goto(_qIndex + 1), child: const Text('Next'))
          else
            FilledButton(
              onPressed: _submitting ? null : () => _submit(),
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit'),
            ),
        ]),
      ),
    );
  }

  void _goto(int i) {
    _save();
    setState(() => _qIndex = i);
  }

  void _showPalette() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: List.generate(_qs.length, (i) {
            final st = _answers[_qs[i].uuid]!;
            Color c;
            if (st.markedForReview) {
              c = Colors.purple;
            } else if (st.answered) {
              c = Colors.green;
            } else {
              c = Colors.grey.shade300;
            }
            final fg = st.answered || st.markedForReview ? Colors.white : Colors.black87;
            return InkWell(
              onTap: () { Navigator.pop(context); _goto(i); },
              child: Container(
                width: 40, height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
                child: Text('${i + 1}', style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
              ),
            );
          })),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}
