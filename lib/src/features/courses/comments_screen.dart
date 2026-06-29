import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/models.dart';

/// Native lesson discussion: read comments, like, reply, post. Smooth in-app
/// experience (no webview) — the kind of everyday interaction that should feel
/// native.
class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({super.key, required this.lessonUuid, required this.lessonTitle});
  final String lessonUuid;
  final String lessonTitle;

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> {
  final _input = TextEditingController();
  bool _posting = false;
  Comment? _replyingTo;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      await ref.read(contentRepoProvider).postComment(
            widget.lessonUuid, text,
            parentId: _replyingTo?.id,
          );
      _input.clear();
      _replyingTo = null;
      ref.invalidate(lessonCommentsProvider(widget.lessonUuid));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not post. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _toggleLike(Comment c) async {
    try {
      final res = await ref.read(contentRepoProvider)
          .toggleCommentLike(widget.lessonUuid, c.id);
      setState(() => c.likesCount = (res['likes_count'] ?? c.likesCount) as int);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(lessonCommentsProvider(widget.lessonUuid));
    return Scaffold(
      appBar: AppBar(title: const Text('Discussion')),
      body: Column(
        children: [
          Expanded(
            child: comments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _retry(),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No comments yet. Start the discussion!',
                          style: TextStyle(color: Colors.black54)),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(lessonCommentsProvider(widget.lessonUuid));
                    await ref.read(lessonCommentsProvider(widget.lessonUuid).future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (_, i) => _CommentTile(
                      comment: list[i],
                      lessonUuid: widget.lessonUuid,
                      onLike: () => _toggleLike(list[i]),
                      onReply: () => setState(() {
                        _replyingTo = list[i];
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _retry() => Center(
        child: TextButton.icon(
          onPressed: () => ref.invalidate(lessonCommentsProvider(widget.lessonUuid)),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, -1))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null)
              Row(
                children: [
                  Expanded(
                    child: Text('Replying to ${_replyingTo!.author}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment…',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                IconButton(
                  icon: _posting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                  onPressed: _posting ? null : _post,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({
    required this.comment,
    required this.lessonUuid,
    required this.onLike,
    required this.onReply,
  });
  final Comment comment;
  final String lessonUuid;
  final VoidCallback onLike;
  final VoidCallback onReply;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  List<Comment>? _replies;
  bool _loadingReplies = false;

  Future<void> _loadReplies() async {
    if (_replies != null) {
      setState(() => _replies = null); // collapse
      return;
    }
    setState(() => _loadingReplies = true);
    try {
      final r = await ref.read(contentRepoProvider)
          .commentReplies(widget.lessonUuid, widget.comment.id);
      setState(() => _replies = r);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingReplies = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(c),
        Padding(
          padding: const EdgeInsets.only(left: 44, top: 4),
          child: Row(
            children: [
              InkWell(
                onTap: widget.onLike,
                child: Row(children: [
                  const Icon(Icons.favorite_border, size: 16, color: Colors.black45),
                  const SizedBox(width: 3),
                  Text('${c.likesCount}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
              ),
              const SizedBox(width: 18),
              InkWell(
                onTap: widget.onReply,
                child: const Text('Reply', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              if (c.repliesCount > 0) ...[
                const SizedBox(width: 18),
                InkWell(
                  onTap: _loadReplies,
                  child: Text(
                    _replies != null ? 'Hide replies' : 'View ${c.repliesCount} repl${c.repliesCount == 1 ? 'y' : 'ies'}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_loadingReplies)
          const Padding(padding: EdgeInsets.only(left: 44, top: 8), child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        if (_replies != null)
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 8),
            child: Column(children: _replies!.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _row(r),
            )).toList()),
          ),
      ],
    );
  }

  Widget _row(Comment c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          child: Text(c.authorInitials,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(c.author, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  const SizedBox(width: 6),
                  Text(c.relativeTime, style: const TextStyle(fontSize: 11, color: Colors.black38)),
                  if (c.fromLive) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: const Text('live', style: TextStyle(fontSize: 9, color: Colors.red)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(c.text, style: const TextStyle(fontSize: 14, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
