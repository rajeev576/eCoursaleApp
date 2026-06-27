import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/html_text.dart';
import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../data/models/models.dart';
import '../../data/repositories/content_repository.dart';
import '../cart/cart_screen.dart' show addToCart;
import '../checkout/checkout_service.dart';

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.uuid});
  final String uuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = ref.watch(courseLessonsProvider(uuid));
    final course = ref.watch(courseDetailProvider(uuid));
    return Scaffold(
      bottomNavigationBar: course.maybeWhen(
        data: (c) => (c.isEnrolled || c.isFree)
            ? null
            : _BuyBar(course: c),
        orElse: () => null,
      ),
      appBar: AppBar(
        title: const Text('Course'),
        actions: [
          IconButton(
            tooltip: 'Quizzes',
            icon: const Icon(Icons.quiz_outlined),
            // The web quiz page is per-COURSE (/quiz/<course_uuid>/) and lists all
            // the course's quizzes; open it via the authenticated handoff.
            onPressed: () => context.push('/handoff', extra: {
              'next': '/quiz/$uuid/',
              'title': 'Quizzes',
            }),
          ),
        ],
      ),
      body: AsyncView<CourseLessons>(
        value: lessons,
        isEmpty: (cl) => cl.lessons.isEmpty,
        emptyMessage: 'No lessons published yet.',
        emptyIcon: Icons.menu_book_outlined,
        onRefresh: () async {
          ref.invalidate(courseLessonsProvider(uuid));
          await ref.read(courseLessonsProvider(uuid).future);
        },
        builder: (context, cl) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: cl.lessons.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final l = cl.lessons[i];
            final locked = !cl.isEnrolled && !l.isFree;
            final leading = CircleAvatar(
              backgroundColor: const Color(0xFFEFF3FB),
              child: Icon(_iconFor(l.lessonType),
                  color: locked ? Colors.black26 : Theme.of(context).colorScheme.primary),
            );

            // Lessons with attachments expand to show them natively; otherwise a
            // plain tappable tile that opens the lesson media.
            if (!locked && l.attachments.isNotEmpty) {
              return ExpansionTile(
                leading: leading,
                title: Text(l.title),
                subtitle: Text(
                  '${l.duration > 0 ? '${l.duration} min · ' : ''}${l.attachments.length} attachment${l.attachments.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                childrenPadding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
                children: [
                  Row(
                    children: [
                      if (l.lessonType == 'video' || l.playbackUrl.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.play_circle_outline, size: 18),
                          label: const Text('Play'),
                          onPressed: () => _openLesson(context, l),
                        ),
                      TextButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline, size: 16),
                        label: const Text('Discussion'),
                        onPressed: () => _openDiscussion(context, l),
                      ),
                    ],
                  ),
                  ...l.attachments.map((a) => _AttachmentTile(
                        attachment: a,
                        onOpen: () => _openAttachment(context, a),
                      )),
                ],
              );
            }

            return ListTile(
              leading: leading,
              title: Text(l.title,
                  style: TextStyle(color: locked ? Colors.black45 : null)),
              subtitle: l.duration > 0 ? Text('${l.duration} min') : null,
              trailing: locked
                  ? const Icon(Icons.lock_outline, size: 18, color: Colors.black38)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          color: Colors.black45,
                          tooltip: 'Discussion',
                          onPressed: () => _openDiscussion(context, l),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
              onTap: locked
                  ? () => _snack(context, 'Enroll to unlock this lesson.')
                  : () => _openLesson(context, l),
            );
          },
        ),
      ),
    );
  }

  void _openDiscussion(BuildContext context, Lesson l) {
    context.push('/comments', extra: {'lessonUuid': l.uuid, 'title': l.title});
  }

  void _openAttachment(BuildContext context, Attachment a) {
    // Rich-text note → show inline; file → open the signed URL.
    if (a.isContent && a.richText.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RichNoteSheet(title: a.title, html: a.richText),
      );
      return;
    }
    if (a.fileUrl.isNotEmpty) {
      _open(context, a.fileUrl);
      return;
    }
    _snack(context, 'This attachment has no file.');
  }

  void _openLesson(BuildContext context, Lesson l) {
    // LIVE class (real-time LiveKit room + chat + polls) → open the web live page
    // via handoff. Rebuilding the live room natively is a large tradeoff; the web
    // page already does video + chat + polls correctly.
    if (l.lessonType == 'live') {
      if (l.categoryUuid.isEmpty) {
        _snack(context, 'Live class not available.');
        return;
      }
      context.push('/handoff', extra: {
        'next': '/watch/${l.categoryUuid}/lesson/${l.uuid}/',
        'title': l.title,
      });
      return;
    }
    // Recorded video → in-app native player (Bunny embed). PDF/other → resource.
    if (l.lessonType == 'video' && l.playbackUrl.isNotEmpty) {
      context.push('/video', extra: {'url': l.playbackUrl, 'title': l.title});
      return;
    }
    if (l.resourceUrl.isNotEmpty) {
      _open(context, l.resourceUrl);
      return;
    }
    if (l.playbackUrl.isNotEmpty) {
      _open(context, l.playbackUrl); // external video (YouTube etc.)
      return;
    }
    _snack(context, 'No media for this lesson.');
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'video': return Icons.play_circle_outline;
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'ppt': return Icons.slideshow_outlined;
      case 'live': return Icons.sensors;
      default: return Icons.description_outlined;
    }
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) _snack(context, 'Could not open the lesson.');
    }
  }

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment, required this.onOpen});
  final Attachment attachment;
  final VoidCallback onOpen;

  IconData _icon() {
    if (attachment.isContent) return Icons.article_outlined;
    switch (attachment.type) {
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'ppt': return Icons.slideshow_outlined;
      case 'doc': return Icons.description_outlined;
      case 'image': return Icons.image_outlined;
      default: return Icons.attach_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(_icon(), size: 20, color: Theme.of(context).colorScheme.primary),
      title: Text(attachment.title, style: const TextStyle(fontSize: 14)),
      trailing: Icon(
          attachment.isContent ? Icons.chevron_right : Icons.open_in_new, size: 18),
      onTap: onOpen,
    );
  }
}

class _RichNoteSheet extends StatelessWidget {
  const _RichNoteSheet({required this.title, required this.html});
  final String title;
  final String html;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          controller: controller,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Text(stripHtml(html), style: const TextStyle(fontSize: 15, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

/// Bottom "Enroll" bar shown for paid courses the student hasn't bought. Tapping
/// opens the school's WEB course page (Enroll → Razorpay checkout) in the in-app
/// browser, so payment goes straight to the school (no Google Play billing / cut).
class _BuyBar extends StatelessWidget {
  const _BuyBar({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Price', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  Text('₹${course.price}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            Consumer(builder: (context, ref, _) => OutlinedButton(
                  onPressed: () => addToCart(context, ref, 'course', course.uuid),
                  child: const Icon(Icons.add_shopping_cart, size: 20),
                )),
            const SizedBox(width: 8),
            Consumer(builder: (context, ref, _) => FilledButton.icon(
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Buy Now'),
                  // Native in-app Razorpay sheet (no webview/browser).
                  onPressed: () => NativeCheckout(ref).buyItem(context, 'course', course.uuid),
                )),
          ],
        ),
      ),
    );
  }
}
