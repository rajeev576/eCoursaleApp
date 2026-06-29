import 'package:flutter/material.dart';

import '../../core/widgets/rich_content.dart';
import '../../data/models/test_models.dart';
import 'player_theme.dart';

/// One question's state for the palette (decoupled from the player's private
/// _AnswerState so this widget stays standalone).
class PaletteQState {
  PaletteQState({required this.answered, required this.marked, required this.seen});
  final bool answered;
  final bool marked;
  final bool seen;
}

/// Testbook-style question palette, shown as a right-side slide-in sheet. Has
/// Grid View / List View tabs, a legend (Marked / Unseen / Unattempted /
/// Attempted), a "View Instructions" row, then a collapsible group per SECTION
/// with a progress bar, per-state counts and the numbered question circles.
/// Bottom: Submit Section (sectional mode) + Submit Test.
Future<void> showTestPaletteDrawer({
  required BuildContext context,
  required List<TestSection> sections,
  required Map<String, PaletteQState> answers,
  required int currentSection,
  required int currentQuestion,
  required bool sectional,
  required Set<int> lockedSections,
  required Set<int> submittedSections,
  required void Function(int section, int question) onJump,
  VoidCallback? onSubmitSection,
  required VoidCallback onSubmitTest,
  required VoidCallback onViewInstructions,
  required String Function(String) langNameOf,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Question palette',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, __) {
      final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
      return Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: slide,
          child: FractionallySizedBox(
            widthFactor: 0.82,
            child: _PaletteSheet(
              sections: sections,
              answers: answers,
              currentSection: currentSection,
              currentQuestion: currentQuestion,
              sectional: sectional,
              lockedSections: lockedSections,
              submittedSections: submittedSections,
              onJump: onJump,
              onSubmitSection: onSubmitSection,
              onSubmitTest: onSubmitTest,
              onViewInstructions: onViewInstructions,
            ),
          ),
        ),
      );
    },
  );
}

class _PaletteSheet extends StatefulWidget {
  const _PaletteSheet({
    required this.sections,
    required this.answers,
    required this.currentSection,
    required this.currentQuestion,
    required this.sectional,
    required this.lockedSections,
    required this.submittedSections,
    required this.onJump,
    required this.onSubmitSection,
    required this.onSubmitTest,
    required this.onViewInstructions,
  });

  final List<TestSection> sections;
  final Map<String, PaletteQState> answers;
  final int currentSection;
  final int currentQuestion;
  final bool sectional;
  final Set<int> lockedSections;
  final Set<int> submittedSections;
  final void Function(int section, int question) onJump;
  final VoidCallback? onSubmitSection;
  final VoidCallback onSubmitTest;
  final VoidCallback onViewInstructions;

  @override
  State<_PaletteSheet> createState() => _PaletteSheetState();
}

class _PaletteSheetState extends State<_PaletteSheet> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  // Which sections are expanded (the current one starts open).
  late final Set<int> _open = {widget.currentSection};

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PlayerPalette.of(context);
    return Material(
      color: p.bg,
      child: SafeArea(
        child: Column(
          children: [
            // Grid View / List View tabs
            Container(
              color: p.surface,
              child: TabBar(
                controller: _tab,
                labelColor: p.text,
                unselectedLabelColor: p.textMuted,
                indicatorColor: p.accent,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                tabs: const [Tab(text: 'Grid View'), Tab(text: 'List View')],
              ),
            ),
            // View instructions
            InkWell(
              onTap: widget.onViewInstructions,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(children: [
                  Icon(Icons.info_outline, color: p.text, size: 22),
                  const SizedBox(width: 12),
                  Text('View Instructions',
                      style: TextStyle(color: p.text, fontWeight: FontWeight.w600, fontSize: 16)),
                ]),
              ),
            ),
            Divider(height: 1, color: p.border),
            _legend(p),
            Divider(height: 1, color: p.border),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _sectionList(p, grid: true),
                  _sectionList(p, grid: false),
                ],
              ),
            ),
            _submitBar(p),
          ],
        ),
      ),
    );
  }

  Widget _legend(PlayerPalette p) {
    Widget item(Widget marker, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          marker,
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: TextStyle(color: p.text, fontSize: 13))),
        ]);
    Widget dot(Color c) => Container(width: 16, height: 16,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(children: [
        Row(children: [
          Expanded(child: item(
              const Icon(Icons.star, color: PlayerPalette.marked, size: 18), 'Marked for\nReview')),
          Expanded(child: item(dot(PlayerPalette.unattempted), 'Unattempted')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: item(
              Icon(Icons.circle_outlined, color: p.textMuted, size: 16), 'Unseen')),
          Expanded(child: item(dot(PlayerPalette.attempted), 'Attempted')),
        ]),
      ]),
    );
  }

  Widget _sectionList(PlayerPalette p, {required bool grid}) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: widget.sections.length,
      itemBuilder: (_, s) => _sectionGroup(p, s, grid: grid),
    );
  }

  Widget _sectionGroup(PlayerPalette p, int s, {required bool grid}) {
    final sec = widget.sections[s];
    final qs = sec.questions;
    final multi = widget.sections.length > 1;
    final title = sec.title.isEmpty ? 'Section ${s + 1}' : sec.title;
    final open = _open.contains(s) || !multi;

    // counts
    int marked = 0, attempted = 0, unattempted = 0, unseen = 0;
    for (final q in qs) {
      final st = widget.answers[q.uuid];
      if (st == null) { unseen++; continue; }
      if (st.marked) {
        marked++;
      } else if (st.answered) {
        attempted++;
      } else if (st.seen) {
        unattempted++;
      } else {
        unseen++;
      }
    }
    final progress = qs.isEmpty ? 0.0 : (attempted + marked) / qs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // header (collapsible only when there's more than one section)
        InkWell(
          onTap: multi ? () => setState(() {
            if (!_open.remove(s)) _open.add(s);
          }) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(color: p.text, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              if (multi)
                Icon(open ? Icons.expand_less : Icons.expand_more, color: p.textMuted),
            ]),
          ),
        ),
        // progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: p.border,
              valueColor: AlwaysStoppedAnimation(p.accent),
            ),
          ),
        ),
        if (open) ...[
          // counts row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              _count(const Icon(Icons.star, color: PlayerPalette.marked, size: 16), marked),
              const SizedBox(width: 18),
              _count(_solid(PlayerPalette.attempted), attempted),
              const SizedBox(width: 18),
              _count(_solid(PlayerPalette.unattempted), unattempted),
              const SizedBox(width: 18),
              _count(Icon(Icons.circle_outlined, color: p.textMuted, size: 15), unseen, p: p),
            ]),
          ),
          if (grid)
            _grid(p, s, qs)
          else
            _list(p, s, qs),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _solid(Color c) =>
      Container(width: 15, height: 15, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _count(Widget marker, int n, {PlayerPalette? p}) => Row(mainAxisSize: MainAxisSize.min, children: [
        marker,
        const SizedBox(width: 6),
        Text('$n', style: TextStyle(color: p?.text ?? const Color(0xFFB6BCC8), fontWeight: FontWeight.w600)),
      ]);

  // colour for a question circle by its state
  ({Color bg, Color fg, Color border, bool star}) _style(PlayerPalette p, PaletteQState? st) {
    if (st == null || (!st.seen && !st.answered && !st.marked)) {
      return (bg: Colors.transparent, fg: p.text, border: p.textFaint, star: false);
    }
    if (st.marked) return (bg: PlayerPalette.marked, fg: Colors.white, border: PlayerPalette.marked, star: true);
    if (st.answered) return (bg: PlayerPalette.attempted, fg: Colors.white, border: PlayerPalette.attempted, star: false);
    return (bg: PlayerPalette.unattempted, fg: Colors.white, border: PlayerPalette.unattempted, star: false);
  }

  bool _isCurrent(int s, int q) => s == widget.currentSection && q == widget.currentQuestion;

  Widget _grid(PlayerPalette p, int s, List<TestQuestion> qs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 14,
        runSpacing: 14,
        children: List.generate(qs.length, (q) {
          final st = widget.answers[qs[q].uuid];
          final style = _style(p, st);
          final current = _isCurrent(s, q);
          return InkWell(
            customBorder: const CircleBorder(),
            onTap: () => widget.onJump(s, q),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 44, height: 44, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: current ? p.accent : style.border,
                    width: current ? 2.2 : 1.4,
                  ),
                ),
                child: Text('${q + 1}',
                    style: TextStyle(color: style.bg == Colors.transparent ? p.text : style.fg,
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              if (style.star)
                const Positioned(top: -2, right: -2,
                    child: Icon(Icons.star, size: 14, color: PlayerPalette.marked)),
            ]),
          );
        }),
      ),
    );
  }

  Widget _list(PlayerPalette p, int s, List<TestQuestion> qs) {
    return Column(
      children: List.generate(qs.length, (q) {
        final st = widget.answers[qs[q].uuid];
        final style = _style(p, st);
        final current = _isCurrent(s, q);
        // a short preview of the question text (strip the heaviest tags)
        final preview = qs[q].lang('en').question;
        return InkWell(
          onTap: () => widget.onJump(s, q),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.border, width: 0.6)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36, height: 36, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: current ? p.accent : style.border,
                    width: current ? 2.2 : 1.4,
                  ),
                ),
                child: Text('${q + 1}',
                    style: TextStyle(color: style.bg == Colors.transparent ? p.text : style.fg,
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 92),
                  child: ClipRect(
                    child: RichContent(html: preview, fontSize: 14, color: p.textMuted),
                  ),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _submitBar(PlayerPalette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(children: [
        if (widget.onSubmitSection != null) ...[
          Expanded(
            child: FilledButton(
              onPressed: widget.onSubmitSection,
              style: FilledButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('SUBMIT SECTION',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: FilledButton(
            onPressed: widget.onSubmitTest,
            style: FilledButton.styleFrom(
              backgroundColor: widget.onSubmitSection != null
                  ? (p.isDark ? const Color(0xFF8B97A3) : const Color(0xFFAEB9C4))
                  : p.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('SUBMIT TEST',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ]),
    );
  }
}
