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
    // Show CACHED data while a refresh is in flight — only the very first load
    // (no value yet) shows a spinner. This makes returning to a tab / pulling to
    // refresh feel instant instead of flashing a full-screen loader every time.
    if (value.hasValue) {
      final data = value.requireValue;
      if (isEmpty?.call(data) ?? false) {
        // Empty + still loading on first fetch → spinner, not the empty message.
        if (value.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        // EMPTY is NOT an error — show the message WITHOUT a Retry button (a
        // retry on a legitimately-empty list reads like a load failure). Pull-to-
        // refresh is still available by dragging the list.
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            _Message(icon: emptyIcon, title: emptyMessage),
          ]),
        );
      }
      return RefreshIndicator(onRefresh: onRefresh, child: builder(context, data));
    }

    // No cached value yet: first-ever load, or an error before any data arrived.
    if (value.hasError) {
      final e = value.error!;
      final expired = e is SessionExpired;
      return _Message(
        icon: expired ? Icons.lock_clock : Icons.wifi_off,
        title: expired ? 'Session expired' : 'Couldn’t load',
        subtitle: expired
            ? 'Please sign in again.'
            : 'Check your connection and try again.',
        onRetry: onRefresh,
      );
    }
    return const Center(child: CircularProgressIndicator());
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
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurface)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant)),
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
