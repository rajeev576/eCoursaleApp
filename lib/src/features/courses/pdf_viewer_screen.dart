import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

/// In-app PDF viewer for lesson attachments (study material). Downloads the signed
/// URL to a temp file and renders it with the platform PDF engine — the student
/// never leaves the app, and the signed S3 URL is not exposed to any external
/// viewer. Matches the web's "view PDF in place" experience.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({
    super.key,
    required this.url,
    this.title = 'Document',
    this.allowDownload = false,
  });
  final String url;
  final String title;
  // When false (default) the document is view-only: no save/share, and the temp
  // render file is wiped on exit. Basic content protection.
  final bool allowDownload;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _path;
  String? _error;
  int _pages = 0;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _download();
  }

  @override
  void dispose() {
    // Content protection: when downloads aren't allowed, don't leave the file
    // sitting in temp where it could be pulled off the device.
    if (!widget.allowDownload && _path != null) {
      try {
        final f = File(_path!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _download() async {
    try {
      final dir = await getTemporaryDirectory();
      // Non-guessable temp name; wiped on exit when view-only.
      final name = 'doc_${DateTime.now().microsecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$name');
      final res = await Dio().get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      await file.writeAsBytes(res.data ?? const []);
      if (mounted) setState(() => _path = file.path);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open this document.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: _pages > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${_current + 1} / $_pages',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
                          fontSize: 12)),
                ),
              )
            : null,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _path == null
              ? const Center(child: CircularProgressIndicator())
              : PDFView(
                  filePath: _path!,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  onRender: (pages) => setState(() => _pages = pages ?? 0),
                  onPageChanged: (page, _) => setState(() => _current = page ?? 0),
                  onError: (_) => setState(() => _error = 'Could not render this document.'),
                ),
    );
  }
}
