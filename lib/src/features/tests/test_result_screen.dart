import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

final testResultProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
    (ref, uuid) => ref.watch(contentRepoProvider).testResult(uuid));

/// Native test result — score + section breakdown (computed by the backend).
class TestResultScreen extends ConsumerWidget {
  const TestResultScreen({super.key, required this.attemptUuid});
  final String attemptUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(testResultProvider(attemptUuid));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        automaticallyImplyLeading: false,
        actions: [TextButton(onPressed: () => context.go('/home'), child: const Text('Done', style: TextStyle(color: Colors.white)))],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load result.')),
        data: (d) {
          final score = d['total_score'] ?? 0;
          final List sections = (d['sections'] as List?) ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primary,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 44),
                    const SizedBox(height: 10),
                    Text('$score',
                        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                    const Text('Total Score', style: TextStyle(color: Colors.white70)),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              if (sections.isNotEmpty) ...[
                const Text('Section-wise', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 8),
                ...sections.map((s) {
                  final sec = Map<String, dynamic>.from(s);
                  return Card(
                    child: ListTile(
                      title: Text((sec['title'] ?? 'Section') as String),
                      subtitle: Text(
                        '✓ ${sec['correct']}   ✗ ${sec['incorrect']}   – ${sec['unattempted']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text('${sec['score']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),
              FilledButton(onPressed: () => context.go('/home'), child: const Text('Back to home')),
            ],
          );
        },
      ),
    );
  }
}
