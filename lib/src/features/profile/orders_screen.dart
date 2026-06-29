import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models/models.dart';
import 'invoice_pdf.dart';

/// Order history — GROUPED by order (a cart purchase = one order with N line items
/// + one combined invoice). A single Buy Now = a 1-item order.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Order history')),
      body: AsyncView<List<Order>>(
        value: orders,
        isEmpty: (l) => l.isEmpty,
        emptyMessage: 'No purchases yet.',
        emptyIcon: Icons.receipt_long_outlined,
        onRefresh: () async {
          ref.invalidate(ordersProvider);
          await ref.read(ordersProvider.future);
        },
        builder: (context, list) => ListView.separated(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final o = list[i];
            final multi = o.items.length > 1;
            final leading = CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.12),
              child: Icon(multi ? Icons.shopping_bag_outlined : _iconFor(
                  o.items.isNotEmpty ? o.items.first.itemType : ''), color: Colors.green),
            );
            final titleW = Text(o.title, maxLines: 2, overflow: TextOverflow.ellipsis);
            final subtitleW = Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (multi) '${o.itemCount} items',
                  if (o.date != null) _date(o.date!),
                ].where((s) => s.isNotEmpty).join(' · '),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            );
            final trailingW = Text('₹${o.totalPaid}', style: const TextStyle(fontWeight: FontWeight.w700));

            return Card(
              child: Column(
                children: [
                  // Multi-item → expandable to show line items; single → plain tile.
                  if (multi)
                    ExpansionTile(
                      leading: leading,
                      title: titleW,
                      subtitle: subtitleW,
                      trailing: trailingW,
                      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                      children: o.items.map((it) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(_iconFor(it.itemType), size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            title: Text(it.title, style: const TextStyle(fontSize: 14)),
                            trailing: Text('₹${it.pricePaid}', style: const TextStyle(fontSize: 13)),
                          )).toList(),
                    )
                  else
                    ListTile(leading: leading, title: titleW, subtitle: subtitleW, trailing: trailingW),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 4),
                      child: TextButton.icon(
                        icon: const Icon(Icons.receipt_long, size: 16),
                        label: const Text('Invoice'),
                        onPressed: o.invoice == null ? null : () => InvoicePdf.shareForOrder(o),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'course': return Icons.play_circle_outline;
      case 'test_series': return Icons.assignment_outlined;
      case 'bundle': return Icons.inventory_2_outlined;
      default: return Icons.receipt_long_outlined;
    }
  }

  String _date(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day}/${d.month}/${d.year}';
  }
}
