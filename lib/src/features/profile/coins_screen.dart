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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Coins are not available on this plan.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
              ),
            );
          }
          final balance = data['balance'] ?? 0;
          final List txns = (data['results'] as List?) ?? [];
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(coinsProvider);
              await ref.read(coinsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Balance card
                Card(
                  color: Theme.of(context).colorScheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.amber, size: 40),
                        const SizedBox(height: 8),
                        Text('$balance',
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                        const Text('Coins', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('History', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                if (txns.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No transactions yet.', style: TextStyle(color: Colors.black54)),
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
