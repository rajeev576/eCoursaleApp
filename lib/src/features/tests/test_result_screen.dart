import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/secure_screen.dart';
import 'player_theme.dart';
import 'test_rating_dialog.dart';
import 'test_solution_screen.dart';

final testResultProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
    (ref, uuid) => ref.watch(contentRepoProvider).testResult(uuid));

/// Native test result — styled like Testbook's "Analysis" tab. A Quick Summary
/// (Rank / Score / Percentile cards with soft-tinted icon badges), a correct /
/// incorrect / skipped breakdown, accuracy & time, and the section-wise table.
/// All numbers come from the backend (single source of truth). Light/dark
/// follows the device; the brand accent themes the highlights.
///
/// NOTE: fields the backend doesn't (yet) return — average/best score,
/// leaderboard, per-question time — are simply omitted (no fake data). Hooks are
/// left where they'd slot in once the API provides them.
// Attempt uuids we've already shown the post-submit rating prompt for (so it
// fires once per fresh submission, never when re-opening an old result).
final _reviewPrompted = <String>{};

class TestResultScreen extends ConsumerWidget {
  const TestResultScreen({super.key, required this.attemptUuid, this.promptReview = false});
  final String attemptUuid;
  final bool promptReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PlayerPalette.of(context);
    if (promptReview && !_reviewPrompted.contains(attemptUuid)) {
      _reviewPrompted.add(attemptUuid);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) showTestRatingDialog(context, ref, attemptUuid);
      });
    }
    return SecureScope(
      child: DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          backgroundColor: p.surface,
          foregroundColor: p.text,
          elevation: 0,
          title: const Text('Result'),
          automaticallyImplyLeading: false,
          actions: [
            _AttemptSwitcher(attemptUuid: attemptUuid, p: p),
            TextButton(
              onPressed: () => context.go('/home'),
              child: Text('Done', style: TextStyle(color: p.accent, fontWeight: FontWeight.w700)),
            )
          ],
          bottom: TabBar(
            labelColor: p.text,
            unselectedLabelColor: p.textMuted,
            indicatorColor: p.accent,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: const [
              Tab(text: 'Analysis'),
              Tab(text: 'Leaderboard'),
              Tab(text: 'Solutions'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _analysisTab(context, ref, p),
              _LeaderboardTab(attemptUuid: attemptUuid),
              _SolutionsTab(attemptUuid: attemptUuid),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _analysisTab(BuildContext context, WidgetRef ref, PlayerPalette p) {
    final result = ref.watch(testResultProvider(attemptUuid));
    return result.when(
        loading: () => Center(child: CircularProgressIndicator(color: p.accent)),
        error: (_, __) => Center(child: Text('Could not load result.', style: TextStyle(color: p.text))),
        data: (d) {
          final score = d['total_score'] ?? 0;
          final maxScore = d['max_score'];
          final accuracy = d['accuracy'];
          final rank = d['rank'];
          final totalAttempts = d['total_attempts'] ?? d['out_of'];
          final percentile = d['percentile'];
          final correct = d['num_correct'] ?? 0;
          final incorrect = d['num_incorrect'] ?? 0;
          final skipped = d['num_skipped'] ?? 0;
          final timeTaken = d['time_taken'];
          final avgScore = d['average_score']; // hook: backend may add later
          final bestScore = d['best_score'];   // hook: backend may add later
          final title = (d['test_title'] ?? '') as String;
          final List sections = (d['sections'] as List?) ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              // Score hero band
              _hero(p, title: title, score: score, maxScore: maxScore,
                  accuracy: accuracy, percentile: percentile),
              const SizedBox(height: 20),
              Text('QUICK SUMMARY',
                  style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w700,
                      fontSize: 12, letterSpacing: 0.5)),
              const SizedBox(height: 12),

              // Rank
              if (rank != null)
                _summaryCard(
                  p,
                  icon: Icons.flag_outlined,
                  iconColor: PlayerPalette.incorrect,
                  label: 'Rank',
                  value: '$rank',
                  suffix: totalAttempts != null ? '/$totalAttempts' : null,
                ),

              // Score (+ optional avg/best sub-row)
              _summaryCard(
                p,
                icon: Icons.emoji_events_outlined,
                iconColor: const Color(0xFF8B5CF6),
                label: 'Score',
                value: _fmtNum(score),
                suffix: maxScore != null ? '/${_fmtNum(maxScore)}' : null,
                footer: (avgScore != null || bestScore != null)
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        if (avgScore != null)
                          Text('Average Score: ${_fmtNum(avgScore)}',
                              style: TextStyle(color: p.textMuted, fontSize: 13)),
                        if (avgScore != null && bestScore != null)
                          Text('   |   ', style: TextStyle(color: p.textFaint)),
                        if (bestScore != null)
                          Text('Best Score: ${_fmtNum(bestScore)}',
                              style: TextStyle(color: p.textMuted, fontSize: 13)),
                      ])
                    : null,
              ),

              // Percentile
              if (percentile != null)
                _summaryCard(
                  p,
                  icon: Icons.person_outline,
                  iconColor: const Color(0xFFA855F7),
                  label: 'Percentile',
                  value: '${_fmtNum(percentile)} %',
                ),

              const SizedBox(height: 8),

              // Correct / Incorrect / Skipped tiles
              Row(children: [
                _stat(p, Icons.check_circle_outline, '$correct', 'Correct', PlayerPalette.correct),
                const SizedBox(width: 10),
                _stat(p, Icons.cancel_outlined, '$incorrect', 'Incorrect', PlayerPalette.incorrect),
                const SizedBox(width: 10),
                _stat(p, Icons.remove_circle_outline, '$skipped', 'Skipped', p.textMuted),
              ]),
              if (accuracy != null || timeTaken != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  if (accuracy != null)
                    _stat(p, Icons.adjust, '${_fmtNum(accuracy)}%', 'Accuracy', p.accent),
                  if (accuracy != null && timeTaken != null) const SizedBox(width: 10),
                  if (timeTaken != null)
                    _stat(p, Icons.timer_outlined, _fmtTime(timeTaken), 'Time', p.accent),
                ]),
              ],

              if (sections.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('SECTION-WISE',
                    style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w700,
                        fontSize: 12, letterSpacing: 0.5)),
                const SizedBox(height: 10),
                ...sections.map((s) => _sectionRow(p, Map<String, dynamic>.from(s))),
              ],

              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => context.go('/home'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.text,
                  side: BorderSide(color: p.border),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Back to home'),
              ),
            ],
          );
        },
      );
  }

  // A prominent score band at the top of the analysis (brand-accent gradient).
  Widget _hero(
    PlayerPalette p, {
    required String title,
    required dynamic score,
    required dynamic maxScore,
    required dynamic accuracy,
    required dynamic percentile,
  }) {
    final dark = Color.alphaBlend(Colors.black.withValues(alpha: 0.22), p.accent);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [p.accent, dark],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        if (title.isNotEmpty) ...[
          Text(title,
              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.onAccent.withValues(alpha: 0.92), fontSize: 13)),
          const SizedBox(height: 12),
        ],
        RichText(
          text: TextSpan(children: [
            TextSpan(text: _fmtNum(score),
                style: TextStyle(color: p.onAccent, fontSize: 46, fontWeight: FontWeight.w800)),
            if (maxScore != null)
              TextSpan(text: '  / ${_fmtNum(maxScore)}',
                  style: TextStyle(color: p.onAccent.withValues(alpha: 0.8), fontSize: 20)),
          ]),
        ),
        Text('Total Score', style: TextStyle(color: p.onAccent.withValues(alpha: 0.85))),
        if (accuracy != null || percentile != null) ...[
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (accuracy != null)
              _heroPill(p, '${_fmtNum(accuracy)}%', 'Accuracy'),
            if (accuracy != null && percentile != null) const SizedBox(width: 12),
            if (percentile != null)
              _heroPill(p, '${_fmtNum(percentile)}%', 'Percentile'),
          ]),
        ],
      ]),
    );
  }

  Widget _heroPill(PlayerPalette p, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: p.onAccent, fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label, style: TextStyle(color: p.onAccent.withValues(alpha: 0.85), fontSize: 11)),
      ]),
    );
  }

  // A Quick-Summary row card: tinted icon badge + label on the left, big value
  // on the right, optional footer beneath.
  Widget _summaryCard(
    PlayerPalette p, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? suffix,
    Widget? footer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: p.isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Text(label, style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 16)),
              const Spacer(),
              RichText(
                text: TextSpan(children: [
                  TextSpan(text: value,
                      style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 22)),
                  if (suffix != null)
                    TextSpan(text: suffix,
                        style: TextStyle(color: p.textFaint, fontWeight: FontWeight.w600, fontSize: 16)),
                ]),
              ),
            ]),
          ),
          if (footer != null) ...[
            Divider(height: 1, color: p.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: footer,
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionRow(PlayerPalette p, Map<String, dynamic> sec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: ListTile(
        title: Text((sec['title'] ?? 'Section') as String,
            style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '✓ ${sec['correct']}   ✗ ${sec['incorrect']}   – ${sec['unattempted']}'
            '${sec['accuracy'] != null ? '   ·   ${_fmtNum(sec['accuracy'])}%' : ''}',
            style: TextStyle(fontSize: 12, color: p.textMuted),
          ),
        ),
        trailing: Text(
          '${_fmtNum(sec['score'])}${sec['max_score'] != null ? ' / ${_fmtNum(sec['max_score'])}' : ''}',
          style: TextStyle(color: p.text, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _stat(PlayerPalette p, IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: p.textMuted)),
        ]),
      ),
    );
  }

  String _fmtNum(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  }

  String _fmtTime(dynamic seconds) {
    final s = (seconds is num) ? seconds.toInt() : int.tryParse('$seconds') ?? 0;
    final m = s ~/ 60, sec = s % 60;
    return m > 0 ? '${m}m ${sec}s' : '${sec}s';
  }
}

/// Attempt switcher (web parity): when the student has multiple completed
/// attempts of this test, a dropdown in the result AppBar lets them switch; the
/// whole result (analysis + leaderboard + solutions) re-opens for that attempt.
class _AttemptSwitcher extends ConsumerWidget {
  const _AttemptSwitcher({required this.attemptUuid, required this.p});
  final String attemptUuid;
  final PlayerPalette p;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attempts = ref.watch(testAttemptsProvider(attemptUuid));
    return attempts.maybeWhen(
      data: (list) {
        if (list.length < 2) return const SizedBox.shrink();
        return PopupMenuButton<String>(
          tooltip: 'Switch attempt',
          color: p.surface,
          icon: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.history, color: p.text, size: 20),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, color: p.text, size: 20),
          ]),
          onSelected: (uuid) {
            if (uuid != attemptUuid) {
              context.pushReplacement('/test-result/$uuid');
            }
          },
          itemBuilder: (_) => [
            for (final a in list)
              PopupMenuItem<String>(
                value: a['attempt_uuid'] as String,
                child: Row(children: [
                  if (a['is_current'] == true)
                    Icon(Icons.check, size: 16, color: p.accent)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text('Attempt ${a['attempt_number']}',
                      style: TextStyle(color: p.text, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (a['score'] != null)
                    Text('  ${_fmtScoreStatic(a['score'])}',
                        style: TextStyle(color: p.textMuted, fontSize: 13)),
                ]),
              ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

String _fmtScoreStatic(dynamic v) {
  final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
  return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
}

/// Solutions tab = the existing solution screen, embedded (no inner AppBar).
class _SolutionsTab extends StatelessWidget {
  const _SolutionsTab({required this.attemptUuid});
  final String attemptUuid;
  @override
  Widget build(BuildContext context) =>
      TestSolutionScreen(attemptUuid: attemptUuid, embedded: true);
}

/// Leaderboard tab — top-3 podium + ranked list + the student's own "You" row.
/// All numbers come from /tests/leaderboard (the SAME shared backend builder the
/// web result page uses, synthetic-fill aware). No client-side computation.
class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab({required this.attemptUuid});
  final String attemptUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = PlayerPalette.of(context);
    final lb = ref.watch(testLeaderboardProvider(attemptUuid));
    return lb.when(
      loading: () => Center(child: CircularProgressIndicator(color: p.accent)),
      error: (_, __) => _retry(context, ref, p),
      data: (d) {
        final List performers = (d['top_performers'] as List?) ?? [];
        final myRank = d['rank'];
        final total = d['total_students'];
        if (performers.isEmpty) {
          return Center(child: Text('Leaderboard not available yet.',
              style: TextStyle(color: p.textMuted)));
        }
        // Split podium (top 3) and the rest; the "You" row is whichever entry
        // is the current student (is_synthetic == false and rank == myRank).
        final top3 = performers.take(3).toList();
        final rest = performers.length > 3 ? performers.sublist(3) : const [];
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  if (total != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('$total participants',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.textMuted, fontSize: 13)),
                    ),
                  _podium(p, top3),
                  const SizedBox(height: 16),
                  ...rest.map((r) => _row(p, Map<String, dynamic>.from(r), myRank)),
                ],
              ),
            ),
            // Pinned "You" row at the bottom (when the student isn't in the list).
            _youRow(p, performers, myRank, d['percentile']),
          ],
        );
      },
    );
  }

  Widget _retry(BuildContext context, WidgetRef ref, PlayerPalette p) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.leaderboard_outlined, size: 40, color: p.textMuted),
          const SizedBox(height: 12),
          Text('Couldn’t load the leaderboard.', style: TextStyle(color: p.textMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(testLeaderboardProvider(attemptUuid)),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ]),
      );

  Widget _podium(PlayerPalette p, List top3) {
    // order: 2nd, 1st, 3rd for the classic podium look
    final order = <int>[];
    if (top3.length > 1) order.add(1);
    if (top3.isNotEmpty) order.add(0);
    if (top3.length > 2) order.add(2);
    final heights = {0: 96.0, 1: 76.0, 2: 64.0};
    final medals = {0: const Color(0xFFFFD54F), 1: const Color(0xFFB0BEC5), 2: const Color(0xFFD0894E)};
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final i in order)
          Expanded(
            child: _podiumCol(
              p,
              Map<String, dynamic>.from(top3[i]),
              height: heights[i]!,
              medal: medals[i]!,
              place: i + 1,
            ),
          ),
      ],
    );
  }

  Widget _podiumCol(PlayerPalette p, Map<String, dynamic> r,
      {required double height, required Color medal, required int place}) {
    final name = (r['name'] ?? '') as String;
    final score = r['score'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: p.surfaceAlt,
            child: Text(_initials(name),
                style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Text(name.isEmpty ? '—' : name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(_fmtScore(score),
              style: TextStyle(color: p.textMuted, fontSize: 11)),
          const SizedBox(height: 6),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: medal.withValues(alpha: p.isDark ? 0.30 : 0.20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            child: Text('$place',
                style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _row(PlayerPalette p, Map<String, dynamic> r, dynamic myRank) {
    final isMe = r['is_synthetic'] == false && r['rank'] == myRank;
    final name = (r['name'] ?? '') as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? p.accent.withValues(alpha: 0.12) : p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isMe ? p.accent : p.border),
      ),
      child: Row(children: [
        SizedBox(width: 28, child: Text('${r['rank']}',
            style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w700))),
        CircleAvatar(radius: 16, backgroundColor: p.surfaceAlt,
            child: Text(_initials(name), style: TextStyle(color: p.text, fontSize: 12))),
        const SizedBox(width: 10),
        Expanded(child: Text(name.isEmpty ? '—' : name,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.text, fontWeight: FontWeight.w600))),
        Text(_fmtScore(r['score']),
            style: TextStyle(color: p.text, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _youRow(PlayerPalette p, List performers, dynamic myRank, dynamic pct) {
    // Only pin a separate "You" row when the student isn't already shown above.
    final shown = performers.any((r) => r['is_synthetic'] == false && r['rank'] == myRank);
    if (shown || myRank == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.12),
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          SizedBox(width: 36, child: Text('#$myRank',
              style: TextStyle(color: p.accent, fontWeight: FontWeight.w800))),
          const SizedBox(width: 4),
          Expanded(child: Text('You',
              style: TextStyle(color: p.text, fontWeight: FontWeight.w700))),
          if (pct != null)
            Text('${_fmtScore(pct)}%ile',
                style: TextStyle(color: p.textMuted, fontSize: 13)),
        ]),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  String _fmtScore(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  }
}
