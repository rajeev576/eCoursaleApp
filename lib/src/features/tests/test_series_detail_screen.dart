import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/price_text.dart';
import '../../data/models/models.dart';
import '../cart/cart_screen.dart' show addToCart;
import '../checkout/checkout_service.dart';

/// Native test-series detail: TestSeries → Categories → Tests. Fully native.
/// The test attempt runs in the NATIVE test engine. Locked tests prompt to buy.
///
/// REUSED for external exams ([isExternal] = true): the backend returns the same
/// shape (sections→categories, external tests→tests). For external exams the
/// attempt runs with auth_mode=true, "enrolled" means "holds a PASS", and locked
/// tests send the student to the native PASS screen (not the cart).
///
/// Design note: this screen is white-label. It draws entirely from the active
/// [ColorScheme] (the school's brand colour) — no hardcoded accent colours — so
/// every tenant's app feels like their own.
class TestSeriesDetailScreen extends ConsumerWidget {
  const TestSeriesDetailScreen({super.key, required this.uuid, this.isExternal = false});
  final String uuid;
  final bool isExternal;

  AutoDisposeFutureProvider<TestSeriesContents> get _provider =>
      isExternal ? externalExamContentsProvider(uuid) : testSeriesContentsProvider(uuid);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contents = ref.watch(_provider);
    return Scaffold(
      appBar: AppBar(title: Text(isExternal ? 'Exam' : 'Test Series')),
      body: AsyncView<TestSeriesContents>(
        value: contents,
        isEmpty: (c) => c.categories.isEmpty,
        emptyMessage: 'No tests published yet.',
        emptyIcon: Icons.assignment_outlined,
        onRefresh: () async {
          ref.invalidate(_provider);
          await ref.read(_provider.future);
        },
        builder: (context, c) => ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 90 + MediaQuery.of(context).padding.bottom),
          children: [
            _Header(contents: c, isExternal: isExternal),
            const SizedBox(height: 18),
            ...c.categories.map((cat) => _SectionCard(
                  category: cat,
                  parentUuid: uuid,
                  isExternal: isExternal,
                  primary: Theme.of(context).colorScheme.primary,
                  onAttempt: (t, fresh) => _attempt(context, t, fresh: fresh),
                  onResult: (t) => _viewResult(context, t),
                  onLockedTap: () => _enroll(context, ref, c),
                )),
          ],
        ),
      ),
      bottomNavigationBar: contents.maybeWhen(
        data: (c) => (c.isEnrolled || c.isFree) ? null : _enrollBar(context, c),
        orElse: () => null,
      ),
    );
  }

  void _attempt(BuildContext context, SeriesTest t, {bool fresh = false}) {
    if (!t.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_unavailableMsg(t))));
      return;
    }
    // NATIVE test engine (native UI; backend scores). External exams = auth_mode=true.
    // `fresh=true` forces a new attempt (Reattempt); otherwise resume if in progress.
    final q = <String>[
      if (isExternal) 'auth_mode=true',
      if (fresh) 'fresh=true',
    ].join('&');
    context.push('/test/${t.uuid}/attempt${q.isEmpty ? '' : '?$q'}');
  }

  void _viewResult(BuildContext context, SeriesTest t) {
    final id = t.completedAttemptId;
    if (id == null) return;
    context.push('/test-result/$id');
  }

  String _unavailableMsg(SeriesTest t) {
    switch (t.availabilityStatus) {
      case 'upcoming':
        final d = t.availFrom != null ? DateTime.tryParse(t.availFrom!) : null;
        return d != null
            ? 'This test opens on ${_fmtDate(d.toLocal())}.'
            : 'This test is scheduled and not open yet.';
      case 'expired':
        return 'This test window has closed.';
      default:
        return 'This test is not available yet.';
    }
  }

  // Locked-test tap: external exams unlock via PASS (native PASS screen); priced
  // test series go through native in-app Razorpay checkout.
  void _enroll(BuildContext context, WidgetRef ref, TestSeriesContents c) {
    if (isExternal) {
      context.push('/pass');
    } else {
      NativeCheckout(ref).buyItem(context, 'test_series', c.uuid);
    }
  }

  Widget _enrollBar(BuildContext context, TestSeriesContents c) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: Theme.of(context).cardColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          // External exams unlock via a single PASS subscription (no per-item cart).
          child: isExternal
              ? Row(children: [
                  Icon(Icons.workspace_premium_outlined, color: cs.primary, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Unlock all exams with the PASS',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  FilledButton(
                    onPressed: () => context.push('/pass'),
                    child: const Text('Get PASS'),
                  ),
                ])
              : Row(children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Price',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                        PriceText(
                          price: c.price, finalPrice: c.finalPrice,
                          discountActive: c.discountActive, isFree: c.isFree,
                          size: 20),
                      ],
                    ),
                  ),
                  Consumer(builder: (context, ref, _) => OutlinedButton(
                        onPressed: () => addToCart(context, ref, 'test_series', c.uuid),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        child: const Icon(Icons.add_shopping_cart_outlined, size: 20),
                      )),
                  const SizedBox(width: 8),
                  Consumer(builder: (context, ref, _) => FilledButton(
                        onPressed: () => _enroll(context, ref, c),
                        child: const Text('Buy now'),
                      )),
                ]),
        ),
      ),
    );
  }
}

/// Sober header: title, a status chip, and a one-line summary of what's inside.
class _Header extends StatelessWidget {
  const _Header({required this.contents, required this.isExternal});
  final TestSeriesContents contents;
  final bool isExternal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = contents;
    final testCount = c.categories.fold<int>(0, (n, cat) => n + cat.tests.length);

    final String statusLabel;
    final Color statusColor;
    if (c.isEnrolled) {
      statusLabel = isExternal ? 'PASS active' : 'Enrolled';
      statusColor = Colors.green.shade700;
    } else if (c.isFree) {
      statusLabel = 'Free';
      statusColor = Colors.green.shade700;
    } else {
      statusLabel = isExternal ? 'Unlock with PASS' : '₹${c.finalPrice}';
      statusColor = cs.primary;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isExternal ? Icons.public_outlined : Icons.assignment_outlined,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  c.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, Icons.verified_outlined, statusLabel, statusColor, filled: true),
              if (c.categories.isNotEmpty)
                _chip(context, Icons.folder_outlined,
                    '${c.categories.length} section${c.categories.length == 1 ? '' : 's'}',
                    cs.onSurfaceVariant),
              if (testCount > 0)
                _chip(context, Icons.assignment_outlined,
                    '$testCount test${testCount == 1 ? '' : 's'}', cs.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label, Color color,
      {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.12) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: filled ? 0.0 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ap = d.hour < 12 ? 'AM' : 'PM';
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]}, $h:$mm $ap';
}

/// One section (category) as a clean card with an expandable list of tests.
class _SectionCard extends ConsumerStatefulWidget {
  const _SectionCard({
    required this.category,
    required this.parentUuid,
    required this.isExternal,
    required this.primary,
    required this.onAttempt,
    required this.onResult,
    required this.onLockedTap,
  });
  final SeriesCategory category;
  final String parentUuid;
  final bool isExternal;
  final Color primary;
  final void Function(SeriesTest test, bool fresh) onAttempt;
  final void Function(SeriesTest test) onResult;
  final VoidCallback onLockedTap;

  @override
  ConsumerState<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends ConsumerState<_SectionCard> {
  late List<SeriesTest> _tests = [...widget.category.tests];
  late bool _hasMore = widget.category.hasMore;
  int _page = 1; // page 1 came with contents; next fetch is page 2
  bool _loadingMore = false;

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final r = await ref.read(contentRepoProvider).moreCategoryTests(
            parentUuid: widget.parentUuid,
            groupUuid: widget.category.uuid,
            page: _page + 1,
            external: widget.isExternal,
          );
      setState(() {
        _tests = [..._tests, ...r.tests];
        _hasMore = r.hasMore;
        _page += 1;
        _loadingMore = false;
      });
    } catch (_) {
      setState(() { _loadingMore = false; _hasMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = widget.category.totalTests > 0 ? widget.category.totalTests : _tests.length;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          leading: Icon(Icons.folder_outlined, color: widget.primary),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(widget.category.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '$total test${total == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            for (int i = 0; i < _tests.length; i++) ...[
              if (i > 0)
                Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.4)),
              _TestRow(
                test: _tests[i],
                primary: widget.primary,
                onAttempt: widget.onAttempt,
                onResult: widget.onResult,
                onLockedTap: widget.onLockedTap,
              ),
            ],
            // Lazy-load: more tests in this category/section load on demand.
            if (_hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _loadingMore
                    ? const Center(child: SizedBox(
                        height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                    : TextButton.icon(
                        onPressed: _loadMore,
                        icon: const Icon(Icons.expand_more),
                        label: Text('Load more (${total - _tests.length} more)'),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A test row that mirrors the web's per-test states:
///  - locked → lock (tap prompts enroll/PASS)
///  - upcoming (scheduled) → shows the open date, no Start
///  - expired → "Closed"
///  - available, never attempted → Start
///  - available, in progress → Resume (+ View result if a completed one exists)
///  - available, completed → View result (+ Reattempt if allowed)
class _TestRow extends StatelessWidget {
  const _TestRow({
    required this.test,
    required this.primary,
    required this.onAttempt,
    required this.onResult,
    required this.onLockedTap,
  });
  final SeriesTest test;
  final Color primary;
  final void Function(SeriesTest test, bool fresh) onAttempt;
  final void Function(SeriesTest test) onResult;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = test;
    final schedule = t.availabilityStatus == 'upcoming' && t.availFrom != null
        ? DateTime.tryParse(t.availFrom!)?.toLocal()
        : null;

    final metaParts = <String>[
      if (t.questions > 0) '${t.questions} Qs',
      if (t.durationMinutes > 0) '${t.durationMinutes} min',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: t.locked ? cs.surfaceContainerHighest : primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(t.locked ? Icons.lock_outline : Icons.description_outlined,
                    size: 19, color: t.locked ? cs.onSurfaceVariant : primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(t.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: t.locked ? cs.onSurfaceVariant : null,
                              )),
                        ),
                        if (t.isFree && t.locked) ...[
                          const SizedBox(width: 6),
                          _freeBadge(),
                        ],
                      ],
                    ),
                    if (metaParts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(metaParts.join('  ·  '),
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ),
                    if (schedule != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          Icon(Icons.event_outlined, size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('Opens ${_fmtDate(schedule)}',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _actions(context, t, cs),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, SeriesTest t, ColorScheme cs) {
    if (t.locked) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onLockedTap,
          icon: const Icon(Icons.lock_outline, size: 16),
          label: const Text('Unlock'),
          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      );
    }
    if (t.availabilityStatus == 'upcoming') {
      return _statusPill(Icons.schedule, 'Scheduled', cs.onSurfaceVariant);
    }
    if (t.availabilityStatus == 'expired') {
      return _statusPill(Icons.lock_clock_outlined, 'Closed', cs.onSurfaceVariant);
    }

    final buttons = <Widget>[];
    if (t.canResume) {
      buttons.add(FilledButton.icon(
        onPressed: () => onAttempt(t, false),
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: const Text('Resume'),
        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
      ));
    } else if (t.canStartFresh && !t.hasCompleted) {
      buttons.add(FilledButton.icon(
        onPressed: () => onAttempt(t, false),
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: const Text('Start'),
        style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
      ));
    }
    if (t.canViewResult) {
      buttons.add(OutlinedButton.icon(
        onPressed: () => onResult(t),
        icon: const Icon(Icons.bar_chart_rounded, size: 16),
        label: const Text('View result'),
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
      ));
    }
    if (t.hasCompleted && t.allowReattempt) {
      buttons.add(OutlinedButton.icon(
        onPressed: () => onAttempt(t, true),
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Reattempt'),
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
      ));
    }
    if (buttons.isEmpty) {
      return _statusPill(Icons.info_outline, 'Not available', cs.onSurfaceVariant);
    }
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Widget _statusPill(IconData icon, String label, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      );

  Widget _freeBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('FREE',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: Colors.green.shade700, letterSpacing: 0.4)),
      );
}
