import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';

/// Reusable async renderer: consistent loading / error / empty / data states for
/// every screen, with pull-to-refresh. Keeps screens DRY and polished.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.onRefresh,
    required this.builder,
    this.isEmpty,
    this.emptyMessage = 'Nothing here yet.',
    this.emptyIcon = Icons.inbox_outlined,
  });

  final AsyncValue<T> value;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext, T) builder;
  final bool Function(T)? isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) {
        final expired = e is SessionExpired;
        return _Message(
          icon: expired ? Icons.lock_clock : Icons.wifi_off,
          title: expired ? 'Session expired' : 'Couldn’t load',
          subtitle: expired
              ? 'Please sign in again.'
              : 'Check your connection and try again.',
          onRetry: onRefresh,
        );
      },
      data: (data) {
        if (isEmpty?.call(data) ?? false) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.3),
              _Message(icon: emptyIcon, title: emptyMessage, onRetry: onRefresh),
            ]),
          );
        }
        return RefreshIndicator(onRefresh: onRefresh, child: builder(context, data));
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.subtitle, this.onRetry});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.black26),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
