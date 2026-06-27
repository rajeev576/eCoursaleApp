import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../data/repositories/content_repository.dart';

class QuizzesScreen extends ConsumerWidget {
  const QuizzesScreen({super.key, required this.courseUuid});
  final String courseUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzes = ref.watch(courseQuizzesProvider(courseUuid));
    return Scaffold(
      appBar: AppBar(title: const Text('Quizzes')),
      body: AsyncView<CourseQuizzes>(
        value: quizzes,
        isEmpty: (q) => q.quizzes.isEmpty,
        emptyMessage: 'No quizzes for this course yet.',
        emptyIcon: Icons.quiz_outlined,
        onRefresh: () async {
          ref.invalidate(courseQuizzesProvider(courseUuid));
          await ref.read(courseQuizzesProvider(courseUuid).future);
        },
        builder: (context, q) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: q.quizzes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final quiz = q.quizzes[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEFF3FB),
                  child: Icon(Icons.quiz_outlined,
                      color: Theme.of(context).colorScheme.primary),
                ),
                title: Text(quiz.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 12, children: [
                    if (quiz.questions > 0) _meta(Icons.help_outline, '${quiz.questions} Qs'),
                    if (quiz.time > 0) _meta(Icons.timer_outlined, '${quiz.time} min'),
                  ]),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/handoff', extra: {
                  'next': '/quiz/${quiz.uuid}/',
                  'title': quiz.title,
                }),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black45),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      );
}
