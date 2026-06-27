/// Lightweight HTML → plain text. Admin content (notifications, notes) is stored
/// as HTML (Quill); the app shows it as clean text without pulling in a full HTML
/// renderer. Handles <br>/<p> as newlines and decodes common entities.
String stripHtml(String html) {
  if (html.isEmpty) return '';
  var s = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  // Collapse 3+ newlines.
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}
