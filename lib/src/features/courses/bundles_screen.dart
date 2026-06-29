import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/price_text.dart';
import '../../data/models/models.dart';

class BundlesScreen extends ConsumerWidget {
  const BundlesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundles = ref.watch(bundlesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bundles')),
      body: AsyncView<List<BundleItem>>(
        value: bundles,
        isEmpty: (l) => l.isEmpty,
        emptyMessage: 'No bundles available yet.',
        emptyIcon: Icons.inventory_2_outlined,
        onRefresh: () async {
          ref.invalidate(bundlesProvider);
          await ref.read(bundlesProvider.future);
        },
        builder: (context, list) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _BundleCard(bundle: list[i]),
        ),
      ),
    );
  }
}

class _BundleCard extends StatelessWidget {
  const _BundleCard({required this.bundle});
  final BundleItem bundle;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/bundle/${bundle.uuid}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: bundle.thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: bundle.thumbnail, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _ph(), placeholder: (_, __) => _ph())
                  : _ph(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bundle.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (!bundle.isFree)
                        // Worth (total_value) struck + discounted price — same basis
                        // as the bundle detail, so it reconciles with "Save ₹savings".
                        PriceText(
                          price: bundle.totalValue, finalPrice: bundle.finalPrice,
                          discountActive: true, isFree: bundle.isFree,
                          size: 15),
                      if (!bundle.isFree && (double.tryParse(bundle.savings) ?? 0) > 0) ...[
                        const SizedBox(width: 8),
                        Text('Save ₹${bundle.savings}',
                            style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                      const Spacer(),
                      if (bundle.isEnrolled)
                        const _Badge(text: 'Owned', color: Colors.green)
                      else
                        const Text('View details', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ph() => Container(
        color: const Color(0xFFE2E8F0),
        child: const Center(child: Icon(Icons.inventory_2_outlined, size: 40, color: Colors.black26)),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
