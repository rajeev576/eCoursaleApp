import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models/models.dart';

/// Profile → "My learning": everything the student currently owns (courses, test
/// series, bundles) plus their PASS. Each row taps through to its native detail.
class MyEnrolledScreen extends ConsumerWidget {
  const MyEnrolledScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(myEnrolledProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My learning')),
      body: AsyncView<MyEnrolled>(
        value: data,
        isEmpty: (m) => m.isEmpty,
        emptyMessage: 'You haven’t enrolled in anything yet.',
        emptyIcon: Icons.school_outlined,
        onRefresh: () async {
          ref.invalidate(myEnrolledProvider);
          await ref.read(myEnrolledProvider.future);
        },
        builder: (context, m) => ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          children: [
            if (m.hasPass) _PassCard(),
            if (m.courses.isNotEmpty) ...[
              const _Header('Courses'),
              ...m.courses.map((c) => _Tile(
                    icon: Icons.menu_book_outlined,
                    title: c.title,
                    onTap: () => context.push('/course/${c.uuid}'),
                  )),
            ],
            if (m.testSeries.isNotEmpty) ...[
              const _Header('Test series'),
              ...m.testSeries.map((t) => _Tile(
                    icon: Icons.assignment_outlined,
                    title: t.title,
                    onTap: () => context.push('/test-series/${t.uuid}'),
                  )),
            ],
            if (m.bundles.isNotEmpty) ...[
              const _Header('Bundles'),
              ...m.bundles.map((b) => _Tile(
                    icon: Icons.inventory_2_outlined,
                    title: b.title,
                    onTap: () => context.push('/bundle/${b.uuid}'),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 0, 8),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        title: Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _PassCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        leading: Icon(Icons.workspace_premium_outlined, color: cs.primary),
        title: const Text('PASS active',
            style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('You can attempt every PASS-based exam'),
      ),
    );
  }
}
