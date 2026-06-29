import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/price_text.dart';
import '../../data/models/models.dart';
import '../cart/cart_screen.dart' show addToCart;
import '../checkout/checkout_service.dart';

/// Native bundle detail: shows what's INSIDE the bundle — its courses and test
/// series — each tappable to its own native detail. Enroll (if not owned) uses
/// the web checkout (the only accepted webview).
class BundleDetailScreen extends ConsumerWidget {
  const BundleDetailScreen({super.key, required this.uuid});
  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contents = ref.watch(bundleContentsProvider(uuid));
    return Scaffold(
      appBar: AppBar(title: const Text('Bundle')),
      body: AsyncView<BundleContents>(
        value: contents,
        isEmpty: (c) => c.courses.isEmpty && c.testSeries.isEmpty,
        emptyMessage: 'This bundle has no items yet.',
        emptyIcon: Icons.inventory_2_outlined,
        onRefresh: () async {
          ref.invalidate(bundleContentsProvider(uuid));
          await ref.read(bundleContentsProvider(uuid).future);
        },
        builder: (context, c) => ListView(
          // Extra bottom inset so the last item clears the bottom action bar +
          // the Android system nav bar.
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          children: [
            Text(c.bundle.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              c.isEnrolled ? 'Owned' : (c.bundle.isFree ? 'Free' : '₹${c.bundle.finalPrice}'),
              style: TextStyle(color: c.isEnrolled ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if (!c.bundle.isFree && !c.isEnrolled && (double.tryParse(c.bundle.savings) ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('You save ₹${c.bundle.savings}', style: const TextStyle(color: Colors.green, fontSize: 13)),
              ),
            const SizedBox(height: 20),

            if (c.courses.isNotEmpty) ...[
              const Text('Courses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              ...c.courses.map((course) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: _thumb(course.thumbnail, Icons.play_circle_outline),
                      title: Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${course.totalLessons} lessons',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/course/${course.uuid}'),
                    ),
                  )),
              const SizedBox(height: 16),
            ],

            if (c.testSeries.isNotEmpty) ...[
              const Text('Test Series', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              ...c.testSeries.map((ts) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: _thumb(ts.thumbnail, Icons.assignment_outlined),
                      title: Text(ts.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${ts.totalTests} tests',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/test-series/${ts.uuid}'),
                    ),
                  )),
            ],
          ],
        ),
      ),
      bottomNavigationBar: contents.maybeWhen(
        data: (c) => (c.isEnrolled || c.bundle.isFree) ? null : _enrollBar(context, c.bundle),
        orElse: () => null,
      ),
    );
  }

  Widget _thumb(String url, IconData fallback) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url, width: 48, height: 48, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _ph(fallback))
            : _ph(fallback),
      );

  Widget _ph(IconData icon) => Container(
      width: 48, height: 48, color: const Color(0xFFE2E8F0),
      child: Icon(icon, color: Colors.black38, size: 22));

  Widget _enrollBar(BuildContext context, BundleItem b) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ]),
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bundle price', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                // Worth (total_value) struck through + the discounted bundle price,
                // exactly like the website's bundle-detail.
                PriceText(
                  price: b.totalValue, finalPrice: b.finalPrice,
                  discountActive: true, isFree: b.isFree, size: 18),
                if ((double.tryParse(b.savings) ?? 0) > 0)
                  Text('You save ₹${b.savings}',
                      style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Consumer(builder: (context, ref, _) => OutlinedButton(
                onPressed: () => addToCart(context, ref, 'bundle', b.uuid),
                child: const Icon(Icons.add_shopping_cart, size: 20),
              )),
          const SizedBox(width: 8),
          Consumer(builder: (context, ref, _) => FilledButton.icon(
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('Buy Now'),
                // Native in-app Razorpay checkout for the bundle.
                onPressed: () => NativeCheckout(ref).buyItem(context, 'bundle', b.uuid),
              )),
        ]),
      ),
    );
  }
}
