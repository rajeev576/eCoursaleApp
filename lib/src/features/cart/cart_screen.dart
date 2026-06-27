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
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
        data: (c) => c.items.isEmpty ? null : _checkoutBar(context, c),
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

  Widget _checkoutBar(BuildContext context, CartData c) {
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
                Text('Total (${c.count} item${c.count == 1 ? '' : 's'})',
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
                Text('₹${c.total}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          Consumer(builder: (context, ref, _) => FilledButton.icon(
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Checkout'),
                // Combined payment via the NATIVE Razorpay sheet (in-app, one order
                // for the whole cart).
                onPressed: () => NativeCheckout(ref).buyCart(context),
              )),
        ]),
      ),
    );
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
