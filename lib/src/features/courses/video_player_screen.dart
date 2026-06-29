import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config.dart';

/// Plays a Bunny video the SAME way the website does — via Bunny's embed iframe
/// (iframe.mediadelivery.net/embed/...). The API returns the fully-formed embed
/// URL (with token+expires when security is enabled).
///
/// Why an HTML wrapper (not loadRequest): Bunny's hotlink protection checks the
/// HTTP `Referer` on the VIDEO sub-requests, not just the top page. Setting a
/// Referer header on `loadRequest` only covers the first request, so in a release
/// build the stream requests arrive with the wrong/empty referer → 403 / black
/// screen. Loading a tiny HTML document hosted on a `baseUrl` of the school origin
/// makes the WebView treat that origin as the page, so EVERY request the embedded
/// iframe makes carries the allowed referer — exactly like the website.
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
  bool _error = false;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      // The HTML posts 'fs:1' / 'fs:0' on fullscreenchange so we can rotate the
      // DEVICE to landscape when the player goes fullscreen (and back on exit).
      ..addJavaScriptChannel('FSChannel', onMessageReceived: (msg) {
        if (msg.message == 'fs:1') {
          _enterFullscreen();
        } else if (msg.message == 'fs:0') {
          _exitFullscreen();
        }
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (err) {
          // Only the MAIN document failing should surface an error; sub-resource
          // hiccups (analytics, etc.) are ignored so they don't black out a
          // playing video.
          if (err.isForMainFrame == true && mounted) {
            setState(() { _error = true; _loading = false; });
          }
        },
      ));
    _load();
  }

  void _enterFullscreen() {
    if (_fullscreen) return;
    _fullscreen = true;
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (mounted) setState(() {});
  }

  void _exitFullscreen() {
    if (!_fullscreen) return;
    _fullscreen = false;
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Always restore portrait-friendly orientation + UI on leaving the player.
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _load() {
    setState(() { _loading = true; _error = false; });
    final origin = AppConfig.apiBase; // e.g. https://dev-mse.ecoursale.com
    // A full-bleed iframe of the Bunny embed, with referrerpolicy set so the
    // video requests carry our origin as the referer (Bunny allowed-referrer).
    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<meta name="referrer" content="origin">
<style>html,body{margin:0;padding:0;height:100%;background:#000;overflow:hidden}
.wrap{position:fixed;inset:0}iframe{border:0;width:100%;height:100%}</style>
</head>
<body>
<div class="wrap">
<iframe src="${_escape(widget.url)}"
        referrerpolicy="origin"
        allow="accelerometer;gyroscope;autoplay;encrypted-media;picture-in-picture;fullscreen"
        allowfullscreen="true"></iframe>
</div>
<script>
  // Tell Flutter when the player enters/leaves fullscreen so the device can
  // rotate to landscape (and back). Covers vendor-prefixed events too.
  function fsState(){
    var el = document.fullscreenElement || document.webkitFullscreenElement || document.mozFullScreenElement;
    try { FSChannel.postMessage(el ? 'fs:1' : 'fs:0'); } catch(e){}
  }
  document.addEventListener('fullscreenchange', fsState);
  document.addEventListener('webkitfullscreenchange', fsState);
  document.addEventListener('mozfullscreenchange', fsState);
</script>
</body>
</html>''';
    // baseUrl = the school origin → the document's referer for sub-requests.
    _controller.loadHtmlString(html, baseUrl: '$origin/');
  }

  String _escape(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // In fullscreen the device is landscape + immersive → drop the app bar and
      // SafeArea so the video fills the whole screen.
      appBar: _fullscreen
          ? null
          : AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        top: !_fullscreen, bottom: !_fullscreen, left: !_fullscreen, right: !_fullscreen,
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading && !_error)
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            if (_error)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Couldn’t play this video.\nCheck your connection and try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
