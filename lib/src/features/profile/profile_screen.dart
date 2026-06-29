import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme_controller.dart';
import '../../data/models/models.dart';
import '../tests/pass_screen.dart' show passPlansProvider;

/// Loads the current user from /me/ (full profile; also validates the session).
final meProvider = FutureProvider.autoDispose<AppUser?>(
    (ref) => ref.watch(contentRepoProvider).me());

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
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.person, size: 44, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 12),
                me.maybeWhen(
                  data: (u) => Column(children: [
                    Text(u?.fullName.isNotEmpty == true ? u!.fullName : 'Student',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (u?.email.isNotEmpty == true)
                      Text(u!.email,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit profile'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile/edit'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('My learning'),
              subtitle: const Text('Courses, test series & bundles you own'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/my-enrolled'),
            ),
          ),
          // PASS — PLATFORM-ONLY. On every other school's white-label app this
          // entry (and the whole PASS/external-exam footprint) is absent entirely.
          if (config.maybeWhen(data: (c) => c.isPlatform, orElse: () => false)) ...[
            const SizedBox(height: 8),
            const _PassProfileTile(),
          ],
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
              leading: const Icon(Icons.monetization_on_outlined),
              title: const Text('My Coins'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/coins'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: const Text('Community'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/forum'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Help & Feedback'),
              subtitle: const Text('Raise an issue or send feedback'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/support'),
            ),
          ),
          const SizedBox(height: 8),
          const _AppearanceTile(),
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
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Appearance override: System (follow phone) / Light / Dark. Persisted, so the
/// student can force Light even when the phone is in Dark mode (and vice-versa).
class _AppearanceTile extends ConsumerWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    String label(ThemeMode m) => switch (m) {
          ThemeMode.system => 'System',
          ThemeMode.light => 'Light',
          ThemeMode.dark => 'Dark',
        };
    IconData icon(ThemeMode m) => switch (m) {
          ThemeMode.system => Icons.brightness_auto_outlined,
          ThemeMode.light => Icons.light_mode_outlined,
          ThemeMode.dark => Icons.dark_mode_outlined,
        };
    return Card(
      child: ListTile(
        leading: Icon(icon(mode)),
        title: const Text('Appearance'),
        subtitle: Text(label(mode)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in ThemeMode.values)
                  ListTile(
                    leading: Icon(icon(m)),
                    title: Text(label(m)),
                    subtitle: m == ThemeMode.system
                        ? const Text('Follow your phone setting')
                        : null,
                    trailing: mode == m
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      ref.read(themeModeProvider.notifier).set(m);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PASS entry for the profile (PLATFORM-ONLY — the caller gates it on isPlatform).
/// Shows "PASS active · valid till X" when the student holds one, otherwise
/// invites them to get it. A clear selling point, always one tap from the profile.
class _PassProfileTile extends ConsumerWidget {
  const _PassProfileTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pass = ref.watch(passPlansProvider);
    final status = pass.maybeWhen(
        data: (d) => Map<String, dynamic>.from(d['pass_status'] ?? const {}),
        orElse: () => const <String, dynamic>{});
    final active = status['active'] == true;
    final isTrial = status['is_trial'] == true;
    final until = DateTime.tryParse((status['valid_till'] ?? '').toString())?.toLocal();

    final String subtitle;
    if (active && until != null) {
      subtitle = '${isTrial ? 'Trial' : 'Active'} · valid till ${_fmtPassDate(until)}';
    } else if (active) {
      subtitle = 'Active — every PASS exam unlocked';
    } else {
      subtitle = 'Unlock every PASS-based exam';
    }

    return Card(
      child: ListTile(
        leading: Icon(Icons.workspace_premium_outlined, color: cs.primary),
        title: const Text('PASS'),
        subtitle: Text(subtitle),
        trailing: active
            ? Icon(Icons.verified_rounded, color: Colors.green.shade700)
            : const Icon(Icons.chevron_right),
        onTap: () => context.push('/pass'),
      ),
    );
  }
}

String _fmtPassDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
