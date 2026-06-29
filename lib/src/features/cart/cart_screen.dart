import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models/models.dart';
import '../checkout/checkout_service.dart';

/// Native cart: review items, remove, see the combined total, then checkout — the
/// combined payment runs on the web checkout (the only accepted webview) so the
/// student pays ONE amount for everything.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: AsyncView<CartData>(
        value: cart,
        isEmpty: (c) => c.items.isEmpty,
        emptyMessage: 'Your cart is empty.',
        emptyIcon: Icons.shopping_cart_outlined,
        onRefresh: () async {
          ref.invalidate(cartProvider);
          await ref.read(cartProvider.future);
        },
        builder: (context, c) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: c.items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final it = c.items[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEFF3FB),
                  child: Icon(_icon(it.type), color: Theme.of(context).colorScheme.primary),
                ),
                title: Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(it.type.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('₹${it.price}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      onPressed: () async {
                        await ref.read(contentRepoProvider).cartRemove(it.id);
                        ref.invalidate(cartProvider);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: cart.maybeWhen(
        data: (c) => c.items.isEmpty ? null : _checkoutBar(context, ref, c),
        orElse: () => null,
      ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'course': return Icons.play_circle_outline;
      case 'test_series': return Icons.assignment_outlined;
      case 'bundle': return Icons.inventory_2_outlined;
      default: return Icons.shopping_bag_outlined;
    }
  }

  Widget _checkoutBar(BuildContext context, WidgetRef ref, CartData c) {
    final hasCoupon = c.couponCode.isNotEmpty;
    final hasCoins = c.coinsUsed > 0;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2)),
        ]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Coupon + coins row
          Row(children: [
            TextButton.icon(
              icon: Icon(hasCoupon ? Icons.check_circle : Icons.local_offer_outlined, size: 16,
                  color: hasCoupon ? Colors.green : null),
              label: Text(hasCoupon ? 'Coupon ${c.couponCode}' : 'Apply coupon'),
              onPressed: () => _couponDialog(context, ref, hasCoupon),
            ),
            const Spacer(),
            Row(children: [
              const Text('Use coins', style: TextStyle(fontSize: 13)),
              Switch(
                value: hasCoins,
                onChanged: (v) async {
                  await ref.read(contentRepoProvider).cartCoins(v);
                  ref.invalidate(cartProvider);
                },
              ),
            ]),
          ]),
          // Breakdown
          if (hasCoupon || hasCoins) ...[
            _line(context, 'Subtotal', '₹${c.total}'),
            if (hasCoupon) _line(context, 'Coupon (${c.couponCode})', '- ₹${c.couponDiscount}', green: true),
            if (hasCoins) _line(context, 'Coins', '- ₹${c.coinsDiscount}', green: true),
          ],
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payable (${c.count} item${c.count == 1 ? '' : 's'})',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  Text('₹${c.finalAmount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Checkout'),
              onPressed: () => NativeCheckout(ref).buyCart(context),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value, {bool green = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        Text(value, style: TextStyle(fontSize: 12, color: green ? Colors.green : cs.onSurface)),
      ]),
    );
  }

  Future<void> _couponDialog(BuildContext context, WidgetRef ref, bool hasCoupon) async {
    final ctrl = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Apply coupon'),
        content: TextField(controller: ctrl, textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Coupon code', border: OutlineInputBorder())),
        actions: [
          if (hasCoupon) TextButton(onPressed: () => Navigator.pop(context, 'remove'), child: const Text('Remove')),
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, 'apply'), child: const Text('Apply')),
        ],
      ),
    );
    if (action == null) return;
    try {
      await ref.read(contentRepoProvider).cartCoupon(action == 'remove' ? '' : ctrl.text.trim());
      ref.invalidate(cartProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().contains('detail') ? 'Invalid coupon.' : 'Could not apply coupon.')));
      }
    }
  }
}

/// Add-to-cart helper used by product detail screens.
Future<void> addToCart(BuildContext context, WidgetRef ref, String itemType, String uuid) async {
  try {
    await ref.read(contentRepoProvider).cartAdd(itemType, uuid);
    ref.invalidate(cartProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Added to cart'),
        action: SnackBarAction(label: 'VIEW', onPressed: () => context.push('/cart')),
      ));
    }
  } catch (e) {
    if (context.mounted) {
      final msg = e.toString().contains('already') ? 'You already own this.' : 'Could not add to cart.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
