import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Native coins / rewards: balance + earn/spend history. Hidden gracefully when
/// the school's plan doesn't include coins.
class CoinsScreen extends ConsumerWidget {
  const CoinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(coinsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Coins')),
      body: coins.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(coinsProvider),
            icon: const Icon(Icons.refresh), label: const Text('Retry'),
          ),
        ),
        data: (data) {
          if (data['enabled'] != true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Coins are not available on this plan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            );
          }
          final balance = data['balance'] ?? 0;
          final List txns = (data['results'] as List?) ?? [];
          final label = (data['label'] ?? 'Coins').toString();
          final valueRupees = data['value_rupees'] ?? 0;
          final maxPct = data['max_pct'] ?? 25;
          final maxPerOrder = data['max_per_order'] ?? 100;
          final perRupee = data['coins_per_rupee'] ?? 4;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(coinsProvider);
              await ref.read(coinsProvider.future);
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
              children: [
                // Balance card — balance, its ₹ value, and a muted line explaining
                // how/where coins are used (at checkout) and the per-order caps.
                Card(
                  color: Theme.of(context).colorScheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 34),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('$balance',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('Worth ₹$valueRupees',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Use coins at checkout — $perRupee coins = ₹1. '
                            'Up to $maxPct% of an order (max ₹$maxPerOrder).',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (txns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('No transactions yet.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  )
                else
                  ...txns.map((t) {
                    final tx = Map<String, dynamic>.from(t);
                    final earned = tx['earned'] == true;
                    final coinsAmt = tx['coins'] ?? 0;
                    return Card(
                      child: ListTile(
                        leading: Icon(earned ? Icons.add_circle_outline : Icons.remove_circle_outline,
                            color: earned ? Colors.green : Colors.red),
                        title: Text((tx['reason'] ?? '') as String),
                        subtitle: (tx['description'] ?? '').toString().isNotEmpty
                            ? Text(tx['description'] as String, style: const TextStyle(fontSize: 12))
                            : null,
                        trailing: Text('${earned ? '+' : ''}$coinsAmt',
                            style: TextStyle(fontWeight: FontWeight.bold, color: earned ? Colors.green : Colors.red)),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
