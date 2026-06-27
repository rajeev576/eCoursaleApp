import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../data/models/models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(schoolConfigProvider);
    final home = ref.watch(homeProvider);

    return Scaffold(
      appBar: AppBar(
        title: config.maybeWhen(
          data: (c) => Row(
            children: [
              if (c.logo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: c.logo, width: 28, height: 28, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
            ],
          ),
          orElse: () => const Text('Home'),
        ),
        actions: [
          // Cart with item-count badge.
          Consumer(builder: (context, ref, _) {
            final count = ref.watch(cartProvider).maybeWhen(data: (c) => c.count, orElse: () => 0);
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  tooltip: 'Cart',
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => context.push('/cart'),
                ),
                if (count > 0)
                  Positioned(
                    right: 6, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text('$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
              ],
            );
          }),
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(schoolConfigProvider);
          ref.invalidate(homeProvider);
          await ref.read(homeProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // Welcome
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: config.maybeWhen(
                data: (c) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome 👋',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        if (c.missionStatement.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(c.missionStatement, style: const TextStyle(color: Colors.black54)),
                        ],
                      ],
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            // Home sections
            home.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load home.', style: TextStyle(color: Colors.black54)),
              ),
              data: (h) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Keep home clean: only "live now" (what's happening) + featured
                  // COURSES rail. Test-series/bundles have their own tabs; listing
                  // them here too made home cluttered.
                  if (h.liveNow.isNotEmpty) _LiveNowStrip(items: h.liveNow),
                  if (h.featuredCourses.isNotEmpty)
                    _CourseRail(title: 'Featured courses', courses: h.featuredCourses),
                  if (h.liveNow.isEmpty && h.featuredCourses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('Explore courses, test series and bundles using the tabs below.',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveNowStrip extends StatelessWidget {
  const _LiveNowStrip({required this.items});
  final List<LiveNowItem> items;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.circle, size: 10, color: Colors.red),
            SizedBox(width: 6),
            Text('Live now', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ]),
          const SizedBox(height: 8),
          ...items.take(4).map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  const Icon(Icons.play_circle_fill, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              )),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
        child: Text(title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _CourseRail extends StatelessWidget {
  const _CourseRail({required this.title, required this.courses});
  final String title;
  final List<Course> courses;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = courses[i];
              return SizedBox(
                width: 220,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push('/course/${c.uuid}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: c.thumbnail.isNotEmpty
                              ? CachedNetworkImage(imageUrl: c.thumbnail, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _ph())
                              : _ph(),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                c.isEnrolled ? 'Enrolled' : (c.isFree ? 'Free' : '₹${c.price}'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: c.isEnrolled ? Colors.green : Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _ph() => Container(color: const Color(0xFFE2E8F0),
      child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.black26)));
}

