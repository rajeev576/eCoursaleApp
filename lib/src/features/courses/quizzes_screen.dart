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
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          itemCount: q.quizzes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final cs = Theme.of(context).colorScheme;
            final quiz = q.quizzes[i];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.quiz_outlined, color: cs.primary),
                ),
                title: Text(quiz.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 12, children: [
                    if (quiz.questions > 0) _meta(context, Icons.help_outline, '${quiz.questions} Qs'),
                    if (quiz.time > 0) _meta(context, Icons.timer_outlined, _fmtDuration(quiz.time)),
                  ]),
                ),
                trailing: const Icon(Icons.chevron_right),
                // NATIVE quiz player (was a webview handoff). Quiz embeds answers,
                // so it's scored locally and the attempt is recorded for gamification.
                onTap: () => context.push('/quiz/${quiz.uuid}/play', extra: {'title': quiz.title}),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(color: c, fontSize: 12)),
      ],
    );
  }

  // Quiz time is stored in MINUTES.
  String _fmtDuration(int minutes) => minutes >= 60
      ? '${minutes ~/ 60}h ${minutes % 60 == 0 ? '' : '${minutes % 60}m'}'.trim()
      : '$minutes min';
}
