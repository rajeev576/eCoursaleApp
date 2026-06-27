import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/providers.dart';

/// Opens a web feature (test-window, quiz, result/review) inside the app, already
/// authenticated, via the backend handoff: we POST the target path to /handoff/,
/// get a one-time signed URL, and load it in a WebView. The student stays inside
/// the app while reusing the proven web engine.
class HandoffScreen extends ConsumerStatefulWidget {
  const HandoffScreen({super.key, this.next = '', this.title = '', this.directUrl});

  /// Safe in-site path, e.g. '/attempt/<uuid>/' or '/quiz/<uuid>/' (authenticated
  /// handoff). Ignored when [directUrl] is given.
  final String next;
  final String title;

  /// A public URL to open directly WITHOUT an auth handoff (e.g. the signup page,
  /// which is public and carries its own Turnstile captcha + verification).
  final String? directUrl;

  @override
  ConsumerState<HandoffScreen> createState() => _HandoffScreenState();
}

class _HandoffScreenState extends ConsumerState<HandoffScreen> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      // Public page (signup) → open directly; otherwise mint an authenticated
      // handoff URL for the in-site target.
      final url = widget.directUrl != null && widget.directUrl!.isNotEmpty
          ? widget.directUrl!
          : await ref.read(contentRepoProvider).handoffUrl(widget.next);
      if (url.isEmpty) throw Exception('empty url');
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ))
        ..loadRequest(Uri.parse(url));
      if (!mounted) return;
      setState(() => _controller = c);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_error != null)
            Center(child: Text(_error!, style: const TextStyle(color: Colors.black54))),
          if (_loading && _error == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
