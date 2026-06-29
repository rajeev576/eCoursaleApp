import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models/models.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Courses')),
      body: AsyncView<List<Course>>(
        value: courses,
        isEmpty: (l) => l.isEmpty,
        emptyMessage: 'No courses available yet.',
        emptyIcon: Icons.play_circle_outline,
        onRefresh: () async {
          ref.invalidate(coursesProvider);
          await ref.read(coursesProvider.future);
        },
        builder: (context, list) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _CourseCard(course: list[i]),
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/course/${course.uuid}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: course.thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: course.thumbnail, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _ph(),
                      placeholder: (_, __) => _ph())
                  : _ph(),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.menu_book_outlined, size: 15,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${course.totalLessons} lessons',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                      const Spacer(),
                      if (course.isEnrolled)
                        const _Badge(text: 'Enrolled', color: Colors.green)
                      else if (course.isFree)
                        const _Badge(text: 'Free', color: Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ph() => Container(
        color: const Color(0xFFE2E8F0),
        child: const Center(child: Icon(Icons.play_circle_outline, size: 40, color: Colors.black26)),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
