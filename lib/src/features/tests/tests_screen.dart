import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models/models.dart';

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
            Tab(text: 'External Exams'),
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
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEFF3FB),
                child: Icon(Icons.assignment_outlined,
                    color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(ts.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (ts.totalTests > 0) _meta(Icons.assignment_outlined, '${ts.totalTests} tests'),
                  if (ts.totalQuestions > 0) _meta(Icons.help_outline, '${ts.totalQuestions} Qs'),
                  if (ts.isEnrolled)
                    const Text('Enrolled', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600))
                  else if (ts.isFree)
                    const Text('Free', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600))
                  else
                    Text('₹${ts.price}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
              trailing: const Icon(Icons.chevron_right),
              // NATIVE test-series detail (categories → tests). Only the actual
              // attempt drops to web (the exam engine, for now).
              onTap: () => context.push('/test-series/${ts.uuid}'),
            ),
          );
        },
      ),
    );
  }
}

class _ExternalExamsList extends ConsumerWidget {
  const _ExternalExamsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(externalExamsProvider);
    return AsyncView<List<ExternalExam>>(
      value: exams,
      isEmpty: (l) => l.isEmpty,
      emptyMessage: 'No external exams available.',
      emptyIcon: Icons.public_outlined,
      onRefresh: () async {
        ref.invalidate(externalExamsProvider);
        await ref.read(externalExamsProvider.future);
      },
      builder: (context, list) => ListView.separated(
        padding: const EdgeInsets.all(16),
        // +1 for the "Buy PASS" banner at the top.
        itemCount: list.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, idx) {
          if (idx == 0) {
            // External exams are unlocked via a PASS subscription — surface it up front.
            return Card(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
              child: ListTile(
                leading: Icon(Icons.workspace_premium_outlined,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Get the PASS', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('One subscription unlocks all external exams',
                    style: TextStyle(fontSize: 12)),
                trailing: FilledButton(
                  // Native PASS screen (plan selection + native Razorpay).
                  onPressed: () => context.push('/pass'),
                  child: const Text('Get PASS'),
                ),
              ),
            );
          }
          final e = list[idx - 1];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFEFF3FB),
                child: Icon(Icons.public, color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 12, children: [
                  if (e.totalTests > 0) _meta(Icons.assignment_outlined, '${e.totalTests} tests'),
                  if (e.totalQuestions > 0) _meta(Icons.help_outline, '${e.totalQuestions} Qs'),
                  if (e.isFree) _meta(Icons.lock_open_outlined, 'Free'),
                ]),
              ),
              trailing: const Icon(Icons.chevron_right),
              // Opens the external exam on the web (test-series page w/ auth_mode=True).
              // Access is PASS-based; the web page offers PASS subscribe when needed.
              onTap: e.slug.isEmpty
                  ? null
                  : () => context.push('/handoff', extra: {
                        'next': '/testseries/${e.slug}/?auth_mode=True',
                        'title': e.title,
                      }),
            ),
          );
        },
      ),
    );
  }
}

Widget _meta(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.black45),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ],
    );
