import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../core/providers.dart';

/// Native live-class room (LiveKit). Joins the SAME room as the web (token minted
/// by the existing gated backend). Students watch the host's video + screen share
/// and chat. Native — no webview.
class LiveRoomScreen extends ConsumerStatefulWidget {
  const LiveRoomScreen({super.key, required this.lessonUuid, this.title = 'Live class'});
  final String lessonUuid;
  final String title;

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  String? _error;
  bool _connecting = true;
  bool _showChat = false;
  final List<Map<String, dynamic>> _chat = [];
  final _chatCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _listener?.dispose();
    _room?.disconnect();
    _room?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      final repo = ref.read(contentRepoProvider);
      final data = await repo.liveToken(widget.lessonUuid);
      if (data['status'] != 'success' && data['token'] == null) {
        throw Exception(data['message'] ?? data['error'] ?? 'Could not join.');
      }
      final wsUrl = data['ws_url'] as String;
      final token = data['token'] as String;

      final room = Room();
      await room.connect(wsUrl, token);
      final listener = room.createListener();
      listener
        ..on<TrackSubscribedEvent>((_) => setState(() {}))
        ..on<TrackUnsubscribedEvent>((_) => setState(() {}))
        ..on<ParticipantConnectedEvent>((_) => setState(() {}))
        ..on<ParticipantDisconnectedEvent>((_) => setState(() {}))
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted) setState(() => _error = 'Disconnected from the live class.');
        });

      if (!mounted) return;
      setState(() {
        _room = room;
        _listener = listener;
        _connecting = false;
      });
      _loadChat();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _connecting = false;
        });
      }
    }
  }

  Future<void> _loadChat() async {
    try {
      final msgs = await ref.read(contentRepoProvider).liveChatHistory(widget.lessonUuid);
      if (mounted) setState(() { _chat..clear()..addAll(msgs); });
    } catch (_) {}
  }

  Future<void> _sendChat() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _chatCtrl.clear();
    try {
      await ref.read(contentRepoProvider).liveChatSend(widget.lessonUuid, text);
      _loadChat();
    } catch (_) {}
  }

  /// Collect remote video tracks (host camera + screen share).
  List<Widget> _videoViews() {
    final views = <Widget>[];
    final room = _room;
    if (room == null) return views;
    for (final p in room.remoteParticipants.values) {
      for (final pub in p.videoTrackPublications) {
        final track = pub.track;
        if (track != null) {
          views.add(VideoTrackRenderer(track));
        }
      }
    }
    return views;
  }

  @override
  Widget build(BuildContext context) {
    if (_connecting) {
      return Scaffold(appBar: AppBar(title: Text(widget.title)),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center))),
      );
    }
    final videos = _videoViews();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(_showChat ? Icons.videocam : Icons.chat_bubble_outline),
            onPressed: () => setState(() => _showChat = !_showChat),
          ),
        ],
      ),
      body: _showChat ? _chatPanel() : _videoArea(videos),
    );
  }

  Widget _videoArea(List<Widget> videos) {
    if (videos.isEmpty) {
      return const Center(
        child: Text('Waiting for the host to start the video…',
            style: TextStyle(color: Colors.white70)),
      );
    }
    // Show the first (host) prominently; others stacked.
    return Column(children: [
      Expanded(child: Container(color: Colors.black, child: videos.first)),
      if (videos.length > 1)
        SizedBox(
          height: 100,
          child: ListView(scrollDirection: Axis.horizontal,
              children: videos.skip(1).map((v) => SizedBox(width: 140, child: v)).toList()),
        ),
    ]);
  }

  Widget _chatPanel() {
    return Container(
      color: Colors.white,
      child: Column(children: [
        Expanded(
          child: _chat.isEmpty
              ? const Center(child: Text('No messages yet.', style: TextStyle(color: Colors.black54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _chat.length,
                  itemBuilder: (_, i) {
                    final m = _chat[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black87), children: [
                        TextSpan(text: '${m['author'] ?? m['user'] ?? 'User'}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '${m['message'] ?? m['text'] ?? ''}'),
                      ])),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _chatCtrl,
                decoration: const InputDecoration(hintText: 'Message…', border: OutlineInputBorder(), isDense: true),
              )),
              IconButton(icon: const Icon(Icons.send), onPressed: _sendChat),
            ]),
          ),
        ),
      ]),
    );
  }
}
