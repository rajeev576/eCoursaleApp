import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config.dart';

/// Plays a Bunny video the SAME way the website does — via Bunny's embed iframe
/// (iframe.mediadelivery.net/embed/...), loaded in a WebView. This is what makes
/// token-auth/DRM playback work (a raw .m3u8 gets 403'd). The API returns the
/// fully-formed embed URL (with token+expires when security is enabled).
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key, required this.url, required this.title});
  final String url; // Bunny embed URL (or an external video page)
  final String title;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      // Send a Referer matching an allowed Bunny "allowed referrers" host. Bunny
      // hotlink protection blocks playback when the referer isn't whitelisted; the
      // browser sends the school host, but a bare WebView sends none → 403. Setting
      // it to the school origin makes the app behave like the website.
      ..loadRequest(Uri.parse(widget.url), headers: {'Referer': '${AppConfig.apiBase}/'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}
