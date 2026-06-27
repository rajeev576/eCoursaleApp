import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../data/models/models.dart';

/// Loads the current user from /me/ (also validates the session).
final meProvider = FutureProvider.autoDispose<AppUser?>(
    (ref) => ref.watch(authRepoProvider).me());

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final config = ref.watch(schoolConfigProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  child: Icon(Icons.person, size: 44, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 12),
                me.maybeWhen(
                  data: (u) => Column(children: [
                    Text(u?.fullName.isNotEmpty == true ? u!.fullName : 'Student',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (u?.email.isNotEmpty == true)
                      Text(u!.email, style: const TextStyle(color: Colors.black54)),
                  ]),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          config.maybeWhen(
            data: (c) => Card(
              child: ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text(c.name),
                subtitle: const Text('Your institute'),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Order history'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/orders'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign out', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await ref.read(authRepoProvider).logout();
                ref.invalidate(hasSessionProvider);
                if (context.mounted) context.go('/login');
              },
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('${AppConfig.appName} · v0.1.0',
                style: const TextStyle(color: Colors.black38, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
