import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../checkout/checkout_service.dart';

final passPlansProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
    (ref) => ref.watch(contentRepoProvider).passPlans());

/// Native PASS subscription screen (platform-only): pick a 3/6/12-month plan →
/// native Razorpay checkout. Free 3-day trial for new users. No webview.
class PassScreen extends ConsumerWidget {
  const PassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(passPlansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Get the PASS')),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(passPlansProvider),
            icon: const Icon(Icons.refresh), label: const Text('Retry'),
          ),
        ),
        data: (data) {
          if (data['available'] != true) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('PASS is not available for this institute.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
              ),
            );
          }
          final List plans = (data['plans'] as List?) ?? [];
          final trialEligible = data['trial_eligible'] == true;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('One PASS unlocks all external exams',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Choose a plan:', style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 12),
              ...plans.map((p) => _PlanCard(plan: Map<String, dynamic>.from(p))),
              if (trialEligible) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.green.withOpacity(0.06),
                  child: ListTile(
                    leading: const Icon(Icons.card_giftcard, color: Colors.green),
                    title: const Text('Try free for 3 days'),
                    subtitle: const Text('New users only', style: TextStyle(fontSize: 12)),
                    trailing: OutlinedButton(
                      onPressed: () => _startTrial(context, ref),
                      child: const Text('Start trial'),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _startTrial(BuildContext context, WidgetRef ref) async {
    try {
      final res = await ref.read(contentRepoProvider).passTrial();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text((res['message'] ?? 'Trial started!') as String)));
        ref.invalidate(passPlansProvider);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not start trial.')));
      }
    }
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.plan});
  final Map<String, dynamic> plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final months = plan['months'] as int;
    final original = plan['original_price'];
    final fin = plan['final_price'];
    final discount = plan['discount_percent'] ?? 0;
    final hasDiscount = (discount is int && discount > 0) && (fin != original);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          child: Text('$months', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
        ),
        title: Text('$months months', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: hasDiscount
            ? Row(children: [
                Text('₹$original', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.black45, fontSize: 12)),
                const SizedBox(width: 6),
                Text('$discount% off', style: const TextStyle(color: Colors.green, fontSize: 12)),
              ])
            : null,
        trailing: FilledButton(
          onPressed: () => NativeCheckout(ref).buyPass(context, months),
          child: Text('₹$fin'),
        ),
      ),
    );
  }
}
