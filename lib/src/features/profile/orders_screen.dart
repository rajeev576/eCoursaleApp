import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models/models.dart';
import 'invoice_pdf.dart';

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
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final o = list[i];
            final paid = o.paymentStatus;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: paid ? Colors.green.withOpacity(0.12) : const Color(0xFFEFF3FB),
                        child: Icon(_iconFor(o.itemType),
                            color: paid ? Colors.green : Theme.of(context).colorScheme.primary),
                      ),
                      title: Text(o.itemTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          [
                            o.itemType.replaceAll('_', ' '),
                            if (o.paymentDate != null) _date(o.paymentDate!),
                          ].where((s) => s.isNotEmpty).join(' · '),
                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (o.pricePaid != null && o.pricePaid!.isNotEmpty)
                            Text('₹${o.pricePaid}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(paid ? 'Paid' : (o.status),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: paid ? Colors.green : Colors.orange)),
                        ],
                      ),
                    ),
                    // Order history is paid-only → native invoice PDF (web replica).
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
