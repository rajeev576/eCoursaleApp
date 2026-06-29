import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/price_text.dart';
import '../../data/models/models.dart';
import 'external_exams_controller.dart';

/// Tests area. For the platform school (e.g. MindSpan) it shows a second tab,
/// "External Exams" (platform-exclusive, PASS-subscription). Other schools see
/// only Test Series, with no tab bar.
class TestsScreen extends ConsumerWidget {
  const TestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(schoolConfigProvider);
    final isPlatform = config.maybeWhen(data: (c) => c.isPlatform, orElse: () => false);

    if (!isPlatform) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tests')),
        body: const _TestSeriesList(),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tests'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Test Series'),
            Tab(text: 'Exams (PASS)'),
          ]),
        ),
        body: const TabBarView(children: [
          _TestSeriesList(),
          _ExternalExamsList(),
        ]),
      ),
    );
  }
}

class _TestSeriesList extends ConsumerWidget {
  const _TestSeriesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(testSeriesProvider);
    return AsyncView<List<TestSeriesItem>>(
      value: series,
      isEmpty: (l) => l.isEmpty,
      emptyMessage: 'No test series available yet.',
      emptyIcon: Icons.assignment_outlined,
      onRefresh: () async {
        ref.invalidate(testSeriesProvider);
        await ref.read(testSeriesProvider.future);
      },
      builder: (context, list) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final ts = list[i];
          final cs = Theme.of(context).colorScheme;
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.assignment_outlined, color: cs.primary),
              ),
              title: Text(ts.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Wrap(spacing: 14, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (ts.totalTests > 0) _meta(context, Icons.assignment_outlined, '${ts.totalTests} tests'),
                  if (ts.totalQuestions > 0) _meta(context, Icons.help_outline, '${ts.totalQuestions} Qs'),
                  if (ts.isEnrolled)
                    Text('Enrolled', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w700))
                  else
                    PriceText(
                      price: ts.price, finalPrice: ts.finalPrice,
                      discountActive: ts.discountActive, isFree: ts.isFree,
                      size: 13, color: cs.primary),
                ]),
              ),
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              // NATIVE test-series detail (categories → tests + native attempt engine).
              onTap: () => context.push('/test-series/${ts.uuid}'),
            ),
          );
        },
      ),
    );
  }
}

class _ExternalExamsList extends ConsumerStatefulWidget {
  const _ExternalExamsList();
  @override
  ConsumerState<_ExternalExamsList> createState() => _ExternalExamsListState();
}

class _ExternalExamsListState extends ConsumerState<_ExternalExamsList> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load the next page when the user nears the bottom (infinite scroll). Only
    // when not searching (search filters the already-loaded set client-side).
    if (_query.isNotEmpty) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 400) {
      ref.read(externalExamsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = ref.watch(externalExamsControllerProvider);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error && state.items.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off, size: 44, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Couldn’t load exams.', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.read(externalExamsControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ]),
      );
    }

    final all = state.items;
    return RefreshIndicator(
      onRefresh: () => ref.read(externalExamsControllerProvider.notifier).refresh(),
      child: Builder(builder: (context) {
        final q = _query.trim().toLowerCase();
        final list = q.isEmpty
            ? all
            : all.where((e) => e.title.toLowerCase().contains(q)).toList();
        // +2 header rows (PASS banner + search); +1 trailing row for the
        // load-more spinner / end (only when not searching and there's more).
        final showFooter = q.isEmpty && (state.hasMore || state.loadingMore);
        final base = list.isEmpty ? 3 : list.length + 2;
        return ListView.separated(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(16),
          itemCount: base + (showFooter ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, idx) {
            // trailing load-more footer
            if (showFooter && idx == base) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: SizedBox(
                    height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            if (idx == 1) {
              return TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search exams',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              );
            }
            if (idx == 0) {
            // External exams are unlocked via a PASS subscription — surface it up front.
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                Icon(Icons.workspace_premium_outlined, color: cs.primary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Get the PASS',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('One subscription unlocks every exam',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                FilledButton(
                  // Native PASS screen (plan selection + native Razorpay).
                  onPressed: () => context.push('/pass'),
                  child: const Text('Get PASS'),
                ),
              ]),
            );
          }
          // No exams match the search.
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text('No exams match “$_query”.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            );
          }
          final e = list[idx - 2];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.public_outlined, color: cs.primary),
              ),
              title: Text(e.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Wrap(spacing: 14, runSpacing: 4, children: [
                  if (e.totalTests > 0) _meta(context, Icons.assignment_outlined, '${e.totalTests} tests'),
                  if (e.totalQuestions > 0) _meta(context, Icons.help_outline, '${e.totalQuestions} Qs'),
                  if (e.isFree) _meta(context, Icons.lock_open_outlined, 'Free'),
                ]),
              ),
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              // NATIVE external-exam browser (sections → tests). Access is PASS-based;
              // locked tests send the student to the native PASS screen.
              onTap: () => context.push('/external-exam/${e.uuid}'),
            ),
          );
          },
        );
      }),
    );
  }
}

Widget _meta(BuildContext context, IconData icon, String text) {
  final c = Theme.of(context).colorScheme.onSurfaceVariant;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: c),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(color: c, fontSize: 12)),
    ],
  );
}
