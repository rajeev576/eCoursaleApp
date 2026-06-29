import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/price_text.dart';
import '../../data/models/models.dart';
import '../profile/profile_screen.dart' show meProvider;

/// Free Daily Practice card on the home page — the latest DPP + the student's
/// streak, with a "Practice now" CTA. Hidden when the school has no DPPs. The
/// attempt result then cross-promotes premium content. Reuses the native quiz
/// player in DPP mode.
class _DailyPracticeCard extends ConsumerWidget {
  const _DailyPracticeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final dpp = ref.watch(dppListProvider);
    return dpp.maybeWhen(
      data: (d) {
        final results = (d['results'] as List?) ?? const [];
        if (results.isEmpty) return const SizedBox.shrink();
        final latest = Map<String, dynamic>.from(results.first);
        final streak = (d['streak'] ?? 0) as int;
        final qCount = (latest['question_count'] ?? 0) as int;
        final attempted = latest['attempted'] == true;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/dpp/${latest['slug']}/play',
                extra: {'title': latest['title']}),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [cs.primary, Color.alphaBlend(Colors.black.withValues(alpha: 0.18), cs.primary)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.bolt, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  const Text('Daily Practice',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  const Spacer(),
                  if (streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.local_fire_department, color: Colors.white, size: 15),
                        const SizedBox(width: 3),
                        Text('$streak-day streak',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  const SizedBox(width: 6),
                  // "See all" → the full Daily Practice list (all DPPs, like web).
                  GestureDetector(
                    onTap: () => context.push('/dpp'),
                    child: const Text('See all',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline, decorationColor: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 10),
                Text((latest['title'] ?? '') as String,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text('$qCount question${qCount == 1 ? '' : 's'} · Free',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () => context.push('/dpp/${latest['slug']}/play',
                        extra: {'title': latest['title']}),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: cs.primary),
                    child: Text(attempted ? 'Practice again' : 'Practice now',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// The home / dashboard. White-label and PERSONAL: it greets the student, shows
/// what's live, lets them continue their own courses, recalls their recent test
/// activity, then surfaces featured content. Everything draws from the active
/// [ColorScheme] (the school's brand colour) so each tenant's app feels its own.
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
          ref.invalidate(meProvider);
          await ref.read(homeProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            const _Greeting(),
            home.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load home.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
              data: (h) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (h.liveNow.isNotEmpty) _LiveNowCard(items: h.liveNow),
                  // Free Daily Practice — top engagement hook (also cross-promotes
                  // premium on the result screen).
                  const _DailyPracticeCard(),
                  if (h.myCourses.isNotEmpty)
                    _CourseRail(
                      title: 'Continue learning',
                      subtitle: 'Pick up where you left off',
                      courses: h.myCourses,
                    ),
                  if (h.recentActivity.isNotEmpty)
                    _RecentActivity(items: h.recentActivity),
                  if (h.featuredCourses.isNotEmpty)
                    _CourseRail(title: 'Featured courses', courses: h.featuredCourses),
                  if (h.featuredTestSeries.isNotEmpty)
                    _TestSeriesRail(title: 'Popular test series', items: h.featuredTestSeries),
                  // On the PLATFORM school the Bundles tab is replaced by PASS in
                  // the bottom nav, so bundles surface HERE on the home page (with
                  // an "All bundles" link). Other schools keep Bundles as a tab.
                  if (config.maybeWhen(data: (c) => c.isPlatform, orElse: () => false) &&
                      h.featuredBundles.isNotEmpty)
                    _BundleRail(title: 'Bundles', items: h.featuredBundles),
                  if (_isEmptyHome(h))
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'Explore courses, test series and bundles using the tabs below.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isEmptyHome(HomeData h) =>
      h.liveNow.isEmpty &&
      h.myCourses.isEmpty &&
      h.recentActivity.isEmpty &&
      h.featuredCourses.isEmpty &&
      h.featuredTestSeries.isEmpty;
}

/// A calm, personal greeting using the student's first name and the school's brand.
class _Greeting extends ConsumerWidget {
  const _Greeting();

  String _partOfDay() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final name = ref.watch(meProvider).maybeWhen(
          data: (u) => u == null
              ? ''
              : (u.firstName.isNotEmpty
                  ? u.firstName
                  : (u.fullName.isNotEmpty ? u.fullName.split(' ').first : '')),
          orElse: () => '',
        );
    final mission = ref.watch(schoolConfigProvider).maybeWhen(
          data: (c) => c.missionStatement,
          orElse: () => '',
        );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, Color.alphaBlend(Colors.black.withValues(alpha: 0.18), cs.primary)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_partOfDay(),
              style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85), fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            name.isEmpty ? 'Welcome back' : name,
            style: TextStyle(
                color: cs.onPrimary, fontSize: 22, fontWeight: FontWeight.w700, height: 1.1),
          ),
          if (mission.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(mission,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.85), fontSize: 13, height: 1.3)),
          ],
        ],
      ),
    );
  }
}

/// "Live now" — tappable: a live lesson opens the native live room; a live test
/// opens the native attempt engine.
class _LiveNowCard extends StatelessWidget {
  const _LiveNowCard({required this.items});
  final List<LiveNowItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            _LiveDot(),
            SizedBox(width: 8),
            Text('Live now',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red, letterSpacing: 0.2)),
          ]),
          const SizedBox(height: 6),
          ...items.take(4).map((i) => InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _open(context, i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Icon(i.kind == 'lesson' ? Icons.videocam_rounded : Icons.timer_outlined,
                        size: 18, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(i.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right, size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ]),
                ),
              )),
        ],
      ),
    );
  }

  void _open(BuildContext context, LiveNowItem i) {
    if (i.uuid.isEmpty) return;

    // If the student can't open it yet (not free / not enrolled / no PASS), send
    // them to the buyable PARENT (course / test series / external exam) where the
    // Buy / Get-PASS button lives — never into an attempt the backend would 403.
    if (!i.hasAccess) {
      _openParent(context, i);
      return;
    }

    if (i.kind == 'lesson') {
      context.push('/live/${i.uuid}', extra: {'title': i.title});
    } else if (i.kind == 'test') {
      context.push('/test/${i.uuid}/attempt${i.authMode ? '?auth_mode=true' : ''}');
    }
  }

  void _openParent(BuildContext context, LiveNowItem i) {
    if (i.parentUuid.isNotEmpty) {
      switch (i.parentKind) {
        case 'external_exam':
          context.push('/external-exam/${i.parentUuid}');
          return;
        case 'test_series':
          context.push('/test-series/${i.parentUuid}');
          return;
        case 'course':
          context.push('/course/${i.parentUuid}');
          return;
      }
    }
    // No resolvable parent → at least take external (PASS) items to the PASS screen.
    if (i.kind == 'test' && i.authMode) {
      context.push('/pass');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enroll to access this.')));
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();
  @override
  Widget build(BuildContext context) => Container(
        width: 9, height: 9,
        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      );
}

/// Recent test/exam attempts with score — taps through to the native result.
class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.items});
  final List<RecentActivity> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Recent activity'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: items.take(4).map((a) {
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: ListTile(
                  onTap: () => context.push('/test-result/${a.attemptUuid}'),
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.history_edu_outlined, color: cs.primary, size: 20),
                  ),
                  title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('Score: ${a.score}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null && subtitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
          ],
        ),
      );
}

class _CourseRail extends StatelessWidget {
  const _CourseRail({required this.title, required this.courses, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Course> courses;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title, subtitle: subtitle),
        SizedBox(
          // Generous height so 2-line titles + the larger system text scales never
          // overflow the card (was 208 — exactly the content height, which clipped
          // and printed "bottom overflowed by N pixels").
          height: 234,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final c = courses[i];
              return SizedBox(
                width: 224,
                child: Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: InkWell(
                    onTap: () => context.push('/course/${c.uuid}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: c.thumbnail.isNotEmpty
                              ? CachedNetworkImage(imageUrl: c.thumbnail, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _ph(cs))
                              : _ph(cs),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(11),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                const Spacer(),
                                _priceTag(context, c),
                              ],
                            ),
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

  Widget _priceTag(BuildContext context, Course c) {
    final cs = Theme.of(context).colorScheme;
    if (c.isEnrolled) {
      return Row(children: [
        Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
        const SizedBox(width: 4),
        Text('Enrolled',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
      ]);
    }
    return PriceText(
      price: c.price, finalPrice: c.finalPrice,
      discountActive: c.discountActive, isFree: c.isFree,
      size: 13, color: cs.primary);
  }

  Widget _ph(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.play_circle_outline, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
      );
}

class _TestSeriesRail extends StatelessWidget {
  const _TestSeriesRail({required this.title, required this.items});
  final String title;
  final List<TestSeriesItem> items;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title),
        SizedBox(
          // Was 130 — too tight for a 2-line title + meta; bumped to avoid the
          // "bottom overflowed" stripes.
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final ts = items[i];
              return SizedBox(
                width: 240,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push('/test-series/${ts.uuid}'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.assignment_outlined, color: cs.primary, size: 19),
                            ),
                            const Spacer(),
                            if (ts.isEnrolled)
                              Text('Enrolled',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w700,
                                      color: Colors.green.shade700))
                            else
                              PriceText(
                                price: ts.price, finalPrice: ts.finalPrice,
                                discountActive: ts.discountActive, isFree: ts.isFree,
                                size: 12, color: cs.primary),
                          ]),
                          const SizedBox(height: 10),
                          Text(ts.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const Spacer(),
                          Text(
                            [
                              if (ts.totalTests > 0) '${ts.totalTests} tests',
                              if (ts.totalQuestions > 0) '${ts.totalQuestions} Qs',
                            ].join('  ·  '),
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
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
}

/// Bundles rail for the platform-school home (its Bundles tab is replaced by
/// PASS, so bundles surface here with a "See all" link to the bundles page).
class _BundleRail extends StatelessWidget {
  const _BundleRail({required this.title, required this.items});
  final String title;
  final List<BundleItem> items;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
          child: Row(children: [
            Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/bundles'),
              child: const Text('See all'),
            ),
          ]),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final b = items[i];
              return SizedBox(
                width: 240,
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push('/bundle/${b.uuid}'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.inventory_2_outlined, color: cs.primary, size: 19),
                            ),
                            const Spacer(),
                            if (b.isEnrolled)
                              Text('Owned',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                      color: Colors.green.shade700))
                            else
                              // Worth (total_value) struck + the discounted bundle
                              // price — SAME basis as the bundle detail page, so the
                              // numbers reconcile with "Save ₹savings" below.
                              PriceText(
                                price: b.totalValue, finalPrice: b.finalPrice,
                                discountActive: true, isFree: b.isFree,
                                size: 12, color: cs.primary),
                          ]),
                          const SizedBox(height: 10),
                          Text(b.title,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const Spacer(),
                          if (!b.isEnrolled && (double.tryParse(b.savings) ?? 0) > 0)
                            Text('Save ₹${b.savings}',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                        ],
                      ),
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
}
