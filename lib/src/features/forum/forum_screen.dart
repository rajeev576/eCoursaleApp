import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

/// Native community Q&A forum — list questions, ask, view answers, answer, vote.
class ForumScreen extends ConsumerWidget {
  const ForumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forum = ref.watch(forumProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      floatingActionButton: forum.maybeWhen(
        data: (d) => d['enabled'] == true
            ? FloatingActionButton.extended(
                onPressed: () => _ask(context, ref),
                icon: const Icon(Icons.add), label: const Text('Ask'))
            : null,
        orElse: () => null,
      ),
      body: forum.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton.icon(onPressed: () => ref.invalidate(forumProvider),
              icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ),
        data: (d) {
          if (d['enabled'] != true) {
            return const Center(child: Padding(padding: EdgeInsets.all(32),
                child: Text('Community is not available on this plan.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))));
          }
          final List qs = (d['results'] as List?) ?? [];
          if (qs.isEmpty) {
            return const Center(child: Text('No questions yet. Be the first to ask!',
                style: TextStyle(color: Colors.black54)));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(forumProvider);
              await ref.read(forumProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: qs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final q = Map<String, dynamic>.from(qs[i]);
                return Card(
                  child: ListTile(
                    title: Text((q['title'] ?? '') as String,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${q['votes']} votes · ${q['answers']} answers · ${q['author']}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/forum/${q['uuid']}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _ask(BuildContext context, WidgetRef ref) async {
    final titleC = TextEditingController();
    final bodyC = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ask a question', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: bodyC, maxLines: 4, decoration: const InputDecoration(labelText: 'Details', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Post'))),
          const SizedBox(height: 16),
        ]),
      ),
    );
    if (ok == true && titleC.text.trim().length >= 5) {
      try {
        await ref.read(contentRepoProvider).forumAsk(titleC.text.trim(), bodyC.text.trim(), '');
        ref.invalidate(forumProvider);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not post.')));
        }
      }
    }
  }
}

class ForumDetailScreen extends ConsumerWidget {
  const ForumDetailScreen({super.key, required this.uuid});
  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(forumDetailProvider(uuid));
    return Scaffold(
      appBar: AppBar(title: const Text('Question')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load.')),
        data: (d) {
          final q = Map<String, dynamic>.from(d['question'] ?? {});
          final List answers = (d['answers'] as List?) ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text((q['title'] ?? '') as String,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text((q['body'] ?? '') as String),
              const SizedBox(height: 8),
              Row(children: [
                _voteBtn(ref, 'question', uuid, 1),
                Text('${q['votes']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                _voteBtn(ref, 'question', uuid, -1),
                const Spacer(),
                Text('${q['author']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ]),
              const Divider(height: 28),
              Text('${answers.length} Answer${answers.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...answers.map((a) {
                final ans = Map<String, dynamic>.from(a);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (ans['is_accepted'] == true)
                        const Padding(padding: EdgeInsets.only(bottom: 6),
                            child: Text('✓ Accepted', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
                      Text((ans['body'] ?? '') as String),
                      const SizedBox(height: 6),
                      Row(children: [
                        _voteBtn(ref, 'answer', ans['uuid'] as String, 1),
                        Text('${ans['votes']}'),
                        _voteBtn(ref, 'answer', ans['uuid'] as String, -1),
                        const Spacer(),
                        Text('${ans['author']}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                      ]),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.reply),
                label: const Text('Write an answer'),
                onPressed: () => _answer(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _voteBtn(WidgetRef ref, String target, String id, int value) => IconButton(
        icon: Icon(value > 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 18),
        onPressed: () async {
          try {
            await ref.read(contentRepoProvider).forumVote(target, id, value);
            ref.invalidate(forumDetailProvider(uuid));
          } catch (_) {}
        },
      );

  Future<void> _answer(BuildContext context, WidgetRef ref) async {
    final c = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Your answer', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(controller: c, maxLines: 5, decoration: const InputDecoration(border: OutlineInputBorder())),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post answer'))),
          const SizedBox(height: 16),
        ]),
      ),
    );
    if (ok == true && c.text.trim().length >= 2) {
      try {
        await ref.read(contentRepoProvider).forumAnswer(uuid, c.text.trim());
        ref.invalidate(forumDetailProvider(uuid));
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not post answer.')));
        }
      }
    }
  }
}
