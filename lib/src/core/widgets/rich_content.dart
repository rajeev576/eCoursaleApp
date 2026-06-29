import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../data/models/test_models.dart';

/// NATIVE renderer for question / option / solution content — NO webview, so it
/// never feels like a website inside the app.
///
/// The content from the API mixes three things:
///   • HTML tags (`<p>`, `<b>`, `<sup>`, tables) and inline base64 `<img>`,
///   • LaTeX math (`\(...\)`, `$...$`, `\[...\]`, `$$...$$`),
///   • image-only options (a `<img>` of a diagram).
/// We render the HTML with `flutter_html` (real Flutter widgets, native images
/// and tables) and the LaTeX with `flutter_math_fork`. Math embedded anywhere in
/// the HTML is handled by first rewriting the math delimiters into a custom
/// `<tex>` element, then rendering that element via flutter_math.
class RichContent extends StatelessWidget {
  const RichContent({
    super.key,
    required this.html,
    this.fontSize = 16,
    this.color,
  });

  final String html;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = (color ?? const Color(0xFF111827));
    final prepared = _wrapMath(_sanitizeHtml(html));

    return Html(
      data: prepared,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(fontSize),
          lineHeight: const LineHeight(1.45),
          color: text,
        ),
        'p': Style(margin: Margins.only(bottom: 6)),
        // NOTE: <img> is handled by the custom TagExtension below (so tiny embedded
        // width/height attributes are ignored and the image scales sensibly).
        'table': Style(border: Border.all(color: const Color(0xFFCBD5E1))),
        'td': Style(
          border: Border.all(color: const Color(0xFFCBD5E1)),
          padding: HtmlPaddings.all(4),
        ),
        'th': Style(
          border: Border.all(color: const Color(0xFFCBD5E1)),
          padding: HtmlPaddings.all(4),
        ),
      },
      extensions: [
        // Render <tex>…</tex> (and block <tex display="1">…</tex>) as NATIVE math.
        // Wide tables would overflow the card; make them scroll horizontally.
        TagExtension(
          tagsToExtend: {'table'},
          builder: (ctx) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Html(
              data: '<table>${ctx.innerHtml}</table>',
              style: {
                'table': Style(border: Border.all(color: const Color(0xFFCBD5E1))),
                'td': Style(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  padding: HtmlPaddings.all(4),
                ),
                'th': Style(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  padding: HtmlPaddings.all(4),
                ),
              },
            ),
          ),
        ),
        // Custom <img>: ignore the (often tiny) embedded width/height and render
        // the image at a sensible size — full available width but capped so small
        // images aren't blown up pixelated, never overflowing the card. Tap to
        // zoom. Handles base64 data URIs and remote URLs.
        TagExtension(
          tagsToExtend: {'img'},
          builder: (ctx) {
            final src = ctx.attributes['src'] ?? '';
            if (src.isEmpty) return const SizedBox.shrink();
            return _RichImage(src: src);
          },
        ),
        TagExtension(
          tagsToExtend: {'tex'},
          builder: (ctx) {
            final raw = ctx.innerHtml;
            final tex = _unescape(raw);
            // Long inline math can't fit on a narrow card; promote it to block
            // (which is horizontally scrollable) so it scrolls instead of
            // overflowing. Threshold kept conservative so short inline math
            // ($k$, $x^2$) still flows inline with the text.
            final display = ctx.attributes['display'] == '1' || tex.length > 32;
            final widget = Math.tex(
              tex,
              mathStyle: display ? MathStyle.display : MathStyle.text,
              textStyle: TextStyle(fontSize: fontSize, color: text),
              onErrorFallback: (_) => Text(tex,
                  style: TextStyle(fontSize: fontSize, color: text)),
            );
            // Block math on its own line — horizontally scrollable so a wide
            // formula scrolls instead of overflowing the card ("overflowed by N
            // pixels"). Inline math sits in the text run as-is.
            return display
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: widget,
                    ),
                  )
                : widget;
          },
        ),
      ],
    );
  }
}

/// Rewrite LaTeX delimiters in [src] into `<tex>` elements so flutter_html can
/// hand them to the native math renderer. Order matters: handle the longer block
/// delimiters (`$$`, `\[ \]`) before the inline ones (`$`, `\( \)`).
/// Make the incoming content safe for flutter_html so RAW TAGS NEVER show up in
/// the app, no matter how messy the question data is. Handles the three things
/// that made literal `<span style=" ">…</span>` appear on screen:
///   1. content that arrived HTML-ENTITY-ENCODED (`&lt;span&gt;…`) — decode it
///      so the tags are real tags, not text;
///   2. EMPTY / whitespace-only `style=""` (or `style=" "`) attributes, which
///      flutter_html's CSS parser can choke on → strip them;
///   3. stray/orphan tags are left to flutter_html (it's lenient), but we make
///      sure nothing upstream double-escapes them.
String _sanitizeHtml(String src) {
  var s = src;

  // (1) If it looks entity-encoded (has &lt;…&gt; but no real '<' tag), decode.
  final looksEncoded = s.contains('&lt;') && !RegExp(r'<[a-zA-Z/]').hasMatch(s);
  if (looksEncoded) {
    s = s
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  // (2) Remove empty / whitespace-only style attributes:  style=" "  style=''
  s = s.replaceAll(RegExp(r'''\s*style\s*=\s*(""|'')'''), '');
  s = s.replaceAll(RegExp(r'''\s*style\s*=\s*"\s*"'''), '');
  s = s.replaceAll(RegExp(r"""\s*style\s*=\s*'\s*'"""), '');

  // (3) Strip LEADING EMPTY blocks so questions/options that start with blank
  // <p></p> / <p><br></p> / &nbsp; / whitespace don't render an ugly empty gap
  // at the top. Repeats until the content starts with real text/markup.
  s = _stripLeadingEmptyBlocks(s);

  return s;
}

/// Remove leading whitespace, <br>, and empty/whitespace-only block tags
/// (<p>, <div>, <span>) from the start of the HTML.
String _stripLeadingEmptyBlocks(String input) {
  var s = input;
  final leading = RegExp(
    r'^\s*(?:<br\s*/?>|&nbsp;|<p>(?:\s|&nbsp;|<br\s*/?>)*</p>|<div>(?:\s|&nbsp;|<br\s*/?>)*</div>|<span>(?:\s|&nbsp;|<br\s*/?>)*</span>)',
    caseSensitive: false,
  );
  // Loop: peel one empty leading block at a time (bounded).
  for (var i = 0; i < 12; i++) {
    final m = leading.firstMatch(s);
    if (m == null) break;
    s = s.substring(m.end);
  }
  return s.trimLeft();
}

String _wrapMath(String src) {
  var s = src;

  // \[ ... \]  and  $$ ... $$  → block math
  s = _replaceDelim(s, r'\[', r'\]', display: true);
  s = _replaceDelimPair(s, r'$$', display: true);

  // \( ... \)  and  $ ... $    → inline math
  s = _replaceDelim(s, r'\(', r'\)', display: false);
  s = _replaceDelimPair(s, r'$', display: false);

  return s;
}

/// Replace `open … close` (distinct delimiters) with a <tex> element.
String _replaceDelim(String s, String open, String close, {required bool display}) {
  final buf = StringBuffer();
  int i = 0;
  while (i < s.length) {
    final start = s.indexOf(open, i);
    if (start < 0) {
      buf.write(s.substring(i));
      break;
    }
    final end = s.indexOf(close, start + open.length);
    if (end < 0) {
      buf.write(s.substring(i));
      break;
    }
    buf.write(s.substring(i, start));
    final body = s.substring(start + open.length, end);
    buf.write('<tex${display ? ' display="1"' : ''}>${_escape(body)}</tex>');
    i = end + close.length;
  }
  return buf.toString();
}

/// Replace `delim … delim` (same delimiter on both sides, e.g. `$ … $`).
String _replaceDelimPair(String s, String delim, {required bool display}) {
  final buf = StringBuffer();
  int i = 0;
  while (i < s.length) {
    final start = s.indexOf(delim, i);
    if (start < 0) {
      buf.write(s.substring(i));
      break;
    }
    final end = s.indexOf(delim, start + delim.length);
    if (end < 0) {
      buf.write(s.substring(i));
      break;
    }
    buf.write(s.substring(i, start));
    final body = s.substring(start + delim.length, end);
    buf.write('<tex${display ? ' display="1"' : ''}>${_escape(body)}</tex>');
    i = end + delim.length;
  }
  return buf.toString();
}

// The LaTeX body must survive as the <tex> element's text. Escape HTML-special
// chars so flutter_html keeps it intact; reverse on the way out.
String _escape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _unescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

/// A shared passage / case-study block (the same passage several questions
/// reference). Collapsible — expanded by default — with its title, so a long
/// passage doesn't push the question off-screen. Renders natively (HTML+LaTeX).
class PassageBlock extends StatefulWidget {
  const PassageBlock({super.key, required this.group, required this.lang});
  final QuestionGroup group;
  final String lang;
  @override
  State<PassageBlock> createState() => _PassageBlockState();
}

class _PassageBlockState extends State<PassageBlock> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final passage = widget.group.text(widget.lang);
    final title = widget.group.title.isNotEmpty
        ? widget.group.title
        : _label(widget.group.type);
    return Container(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(children: [
                Icon(Icons.menu_book_outlined, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary, fontSize: 13)),
                ),
                Icon(_open ? Icons.expand_less : Icons.expand_more, color: cs.primary),
              ]),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: RichContent(html: passage, fontSize: 14),
            ),
        ],
      ),
    );
  }

  String _label(String type) {
    switch (type) {
      case 'case_study': return 'Case study';
      case 'paragraph': return 'Paragraph';
      case 'comprehension': return 'Comprehension';
      default: return 'Passage';
    }
  }
}

/// An image inside rich content. Renders at the FULL available width but never
/// upscales a small image past ~2x (so a tiny diagram stays crisp, not blurry),
/// and never overflows the card. Tap to open a zoomable full-screen view.
/// Handles base64 data URIs and remote URLs.
class _RichImage extends StatelessWidget {
  const _RichImage({required this.src});
  final String src;

  bool get _isData => src.startsWith('data:');

  ImageProvider? get _provider {
    try {
      if (_isData) {
        final comma = src.indexOf(',');
        if (comma < 0) return null;
        return MemoryImage(base64Decode(src.substring(comma + 1)));
      }
      return NetworkImage(src);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.of(context).size.width;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: GestureDetector(
          onTap: () => _openFullScreen(context, provider),
          child: ConstrainedBox(
            // Cap height so a very tall image doesn't dominate; width fills the card.
            constraints: BoxConstraints(maxWidth: maxW, maxHeight: 420),
            child: Image(
              image: provider,
              width: maxW,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          ),
        ),
      );
    });
  }

  void _openFullScreen(BuildContext context, ImageProvider provider) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, elevation: 0),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Image(image: provider, fit: BoxFit.contain),
          ),
        ),
      ),
    ));
  }
}
