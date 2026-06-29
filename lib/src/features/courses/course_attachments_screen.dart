import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/rich_content.dart';
import '../../data/models/models.dart';
import '../../data/repositories/content_repository.dart';

/// All attachments across a course's lessons in one place (reached from the
/// paperclip in the course header) — so the student doesn't open each lesson.
/// Grouped by lesson. Opening behaves exactly like the lesson attachment tiles:
/// rich-text notes inline, PDFs in the in-app viewer, other files via the OS
/// (download only when the admin allowed it).
class CourseAttachmentsScreen extends ConsumerWidget {
  const CourseAttachmentsScreen({super.key, required this.courseUuid});
  final String courseUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atts = ref.watch(courseAttachmentsProvider(courseUuid));
    return Scaffold(
      appBar: AppBar(title: const Text('Attachments')),
      body: AsyncView<List<CourseAttachment>>(
        value: atts,
        isEmpty: (l) => l.isEmpty,
        emptyMessage: 'No attachments in this course yet.',
        emptyIcon: Icons.attach_file,
        onRefresh: () async {
          ref.invalidate(courseAttachmentsProvider(courseUuid));
          await ref.read(courseAttachmentsProvider(courseUuid).future);
        },
        builder: (context, list) {
          // Group by lesson title, preserving order.
          final groups = <String, List<CourseAttachment>>{};
          for (final a in list) {
            groups.putIfAbsent(a.lessonTitle, () => []).add(a);
          }
          final cs = Theme.of(context).colorScheme;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
            children: [
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Text(entry.key.isEmpty ? 'Lesson' : entry.key,
                      style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, fontSize: 13)),
                ),
                ...entry.value.map((ca) => Card(
                      child: ListTile(
                        leading: Icon(_iconFor(ca.attachment), color: cs.primary),
                        title: Text(ca.attachment.title,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_subtitleFor(ca.attachment),
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(context, ca.attachment),
                      ),
                    )),
                const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }

  IconData _iconFor(Attachment a) {
    if (a.isContent) return Icons.article_outlined;
    switch (a.type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'image':
        return Icons.image_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _subtitleFor(Attachment a) {
    if (a.isContent) return 'Note';
    if (a.type.isNotEmpty) return a.type.toUpperCase();
    return 'File';
  }

  bool _isPdf(Attachment a) {
    if (a.type.toLowerCase() == 'pdf') return true;
    final clean = a.fileUrl.toLowerCase().split('?').first;
    return clean.endsWith('.pdf');
  }

  void _open(BuildContext context, Attachment a) {
    if (a.isContent && a.richText.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _NoteSheet(title: a.title, html: a.richText),
      );
      return;
    }
    if (a.fileUrl.isNotEmpty) {
      if (_isPdf(a)) {
        context.push('/pdf', extra: {
          'url': a.fileUrl, 'title': a.title, 'allowDownload': a.allowDownload,
        });
      } else if (a.allowDownload) {
        launchUrl(Uri.parse(a.fileUrl), mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This file is view-only.')));
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This attachment has no file.')));
  }
}

class _NoteSheet extends StatelessWidget {
  const _NoteSheet({required this.title, required this.html});
  final String title;
  final String html;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        color: cs.surface,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: cs.onSurface)),
            const SizedBox(height: 12),
            RichContent(html: html, fontSize: 15, color: cs.onSurface),
          ],
        ),
      ),
    );
  }
}
