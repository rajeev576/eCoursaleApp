import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models/models.dart';
import '../cart/cart_screen.dart' show addToCart;
import '../checkout/checkout_service.dart';

/// Native test-series detail: TestSeries → Categories → Tests. Fully native
/// browsing. ONLY the actual test attempt opens the web test-window (the exam
/// engine) via handoff. Locked tests prompt to enroll (web checkout).
class TestSeriesDetailScreen extends ConsumerWidget {
  const TestSeriesDetailScreen({super.key, required this.uuid});
  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contents = ref.watch(testSeriesContentsProvider(uuid));
    return Scaffold(
      appBar: AppBar(title: const Text('Test Series')),
      body: AsyncView<TestSeriesContents>(
        value: contents,
        isEmpty: (c) => c.categories.isEmpty,
        emptyMessage: 'No tests published yet.',
        emptyIcon: Icons.assignment_outlined,
        onRefresh: () async {
          ref.invalidate(testSeriesContentsProvider(uuid));
          await ref.read(testSeriesContentsProvider(uuid).future);
        },
        builder: (context, c) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(c.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              c.isEnrolled ? 'Enrolled' : (c.isFree ? 'Free' : '₹${c.price}'),
              style: TextStyle(color: c.isEnrolled ? Colors.green : Colors.black54),
            ),
            const SizedBox(height: 16),
            ...c.categories.map((cat) => _CategoryBlock(
                  category: cat,
                  onAttempt: (t) => _attempt(context, t),
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

  void _attempt(BuildContext context, SeriesTest t) {
    if (!t.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This test is not available yet.')));
      return;
    }
    // NATIVE test engine (native UI; backend scores). Internal tests = auth_mode false.
    context.push('/test/${t.uuid}/attempt');
  }

  // Native in-app Razorpay checkout for the test series.
  void _enroll(BuildContext context, WidgetRef ref, TestSeriesContents c) {
    NativeCheckout(ref).buyItem(context, 'test_series', c.uuid);
  }

  Widget _enrollBar(BuildContext context, TestSeriesContents c) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ]),
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Price', style: TextStyle(color: Colors.black54, fontSize: 12)),
                Text('₹${c.price}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          Consumer(builder: (context, ref, _) => OutlinedButton(
                onPressed: () => addToCart(context, ref, 'test_series', c.uuid),
                child: const Icon(Icons.add_shopping_cart, size: 20),
              )),
          const SizedBox(width: 8),
          Consumer(builder: (context, ref, _) => FilledButton.icon(
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('Buy Now'),
                onPressed: () => _enroll(context, ref, c),
              )),
        ]),
      ),
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({required this.category, required this.onAttempt, required this.onLockedTap});
  final SeriesCategory category;
  final void Function(SeriesTest) onAttempt;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          title: Text(category.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${category.tests.length} test${category.tests.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: category.tests.map((t) => ListTile(
                dense: true,
                leading: Icon(
                  t.locked ? Icons.lock_outline : Icons.assignment_outlined,
                  size: 20,
                  color: t.locked ? Colors.black38 : Theme.of(context).colorScheme.primary,
                ),
                title: Text(t.title, style: TextStyle(color: t.locked ? Colors.black45 : null)),
                subtitle: Text(
                  [
                    if (t.questions > 0) '${t.questions} Qs',
                    if (t.duration > 0) '${t.duration} min',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                trailing: t.locked
                    ? const Icon(Icons.lock_outline, size: 16, color: Colors.black38)
                    : (t.isAvailable
                        ? const Text('Start', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600))
                        : const Text('Soon', style: TextStyle(color: Colors.black45, fontSize: 12))),
                onTap: t.locked ? onLockedTap : () => onAttempt(t),
              )).toList(),
        ),
      ),
    );
  }
}
