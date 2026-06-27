import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/html_text.dart';
import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models/models.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: AsyncView<List<AppNotification>>(
        value: items,
        isEmpty: (l) => l.isEmpty,
        emptyMessage: 'You’re all caught up.',
        emptyIcon: Icons.notifications_none,
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(notificationsProvider.future);
        },
        builder: (context, list) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final n = list[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: n.isImportant
                      ? Colors.red.withOpacity(0.1)
                      : const Color(0xFFEFF3FB),
                  child: Icon(
                    n.isImportant ? Icons.priority_high : Icons.notifications_outlined,
                    color: n.isImportant ? Colors.red : Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(stripHtml(n.text), maxLines: 4, overflow: TextOverflow.ellipsis),
                ),
                isThreeLine: n.text.length > 40,
              ),
            );
          },
        ),
      ),
    );
  }
}
