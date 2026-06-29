import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Help & Feedback — raise a complaint or send feedback (→ the existing web
/// Complaint model, so admins see app-raised issues in the same dashboard) and
/// see the status of past entries. Reached from Profile.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final items = ref.watch(complaintsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Feedback')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _raise(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Raise an issue'),
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(complaintsProvider),
            icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.support_agent_outlined, size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('Need help or have feedback?',
                      style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Tap “Raise an issue” to contact your institute.',
                      textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                ]),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(complaintsProvider);
              await ref.read(complaintsProvider.future);
            },
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 90 + MediaQuery.of(context).padding.bottom),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final c = list[i];
                final resolved = c['status'] == 'resolved';
                final isFeedback = c['entry_type'] == 'feedback';
                return Card(
                  child: ListTile(
                    leading: Icon(
                      isFeedback ? Icons.feedback_outlined : Icons.report_gmailerrorred_outlined,
                      color: cs.primary),
                    title: Text((c['subject'] ?? '') as String,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text((c['description'] ?? '') as String,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (resolved ? Colors.green : cs.primary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(resolved ? 'Resolved' : 'Open',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: resolved ? Colors.green.shade700 : cs.primary)),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _raise(BuildContext context, WidgetRef ref) async {
    final subjectC = TextEditingController();
    final descC = TextEditingController();
    String entryType = 'complaint';
    String category = 'other';

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Raise an issue',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'complaint', label: Text('Complaint'), icon: Icon(Icons.report_gmailerrorred_outlined)),
                  ButtonSegment(value: 'feedback', label: Text('Feedback'), icon: Icon(Icons.feedback_outlined)),
                ],
                selected: {entryType},
                onSelectionChanged: (s) => setSheet(() => entryType = s.first),
              ),
              const SizedBox(height: 12),
              TextField(controller: subjectC,
                  decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'technical', child: Text('Technical Issue')),
                  DropdownMenuItem(value: 'payment', child: Text('Payment')),
                  DropdownMenuItem(value: 'content', child: Text('Content Quality')),
                  DropdownMenuItem(value: 'account', child: Text('Account')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setSheet(() => category = v ?? 'other'),
              ),
              const SizedBox(height: 10),
              TextField(controller: descC, maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Describe the issue', border: OutlineInputBorder())),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Submit'))),
              const SizedBox(height: 16),
            ]),
          );
        });
      },
    );

    if (ok != true) return;
    if (subjectC.text.trim().length < 3 || descC.text.trim().length < 5) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please add a subject and a description.')));
      }
      return;
    }
    try {
      await ref.read(contentRepoProvider).submitComplaint(
            subject: subjectC.text.trim(),
            description: descC.text.trim(),
            entryType: entryType,
            category: category,
          );
      ref.invalidate(complaintsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Submitted. Your institute will respond.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not submit. Please try again.')));
      }
    }
  }
}
