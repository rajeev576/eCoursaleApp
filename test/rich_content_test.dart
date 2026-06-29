import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ecoursale_app/src/core/widgets/rich_content.dart';

/// Guards the rule: the app must NEVER show raw HTML/LaTeX tags, no matter how
/// messy the question data is. Renders the exact shapes that leaked before.
void main() {
  Future<void> pump(WidgetTester t, String html) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: RichContent(html: html))),
    ));
    await t.pumpAndSettle();
  }

  bool anyTextContains(String needle) {
    final texts = find.byType(Text).evaluate();
    for (final e in texts) {
      final w = e.widget as Text;
      final s = w.data ?? w.textSpan?.toPlainText() ?? '';
      if (s.contains(needle)) return true;
    }
    return false;
  }

  testWidgets('empty style attr does not leak raw <span> tags', (t) async {
    await pump(t, '<span style=" ">त्रिपिटक</span>');
    expect(anyTextContains('<span'), isFalse, reason: 'raw <span> tag leaked');
    expect(anyTextContains('त्रिपिटक'), isTrue, reason: 'content text missing');
  });

  testWidgets('leading empty blocks are dropped but real content stays', (t) async {
    await pump(t, '<p></p><p><br></p>&nbsp; <p>Real question here</p>');
    expect(anyTextContains('Real question here'), isTrue);
  });

  testWidgets('content that STARTS with real text is untouched', (t) async {
    await pump(t, '<p>Consider the following:</p><p>Statement A</p>');
    expect(anyTextContains('Consider the following:'), isTrue);
    expect(anyTextContains('Statement A'), isTrue);
  });

  testWidgets('a leading <p> WITH attributes/content is NOT stripped', (t) async {
    await pump(t, '<p style="x">Important first line</p>');
    expect(anyTextContains('Important first line'), isTrue);
  });

  testWidgets('entity-encoded html is decoded, not shown literally', (t) async {
    await pump(t, '&lt;span&gt;Buddha&lt;/span&gt;');
    expect(anyTextContains('&lt;'), isFalse);
    expect(anyTextContains('<span'), isFalse);
    expect(anyTextContains('Buddha'), isTrue);
  });

  testWidgets('html + inline latex renders without leaking dollar or tags', (t) async {
    await pump(t, r'<p>A point in $\mathbb{R}^3$</span></p>');
    expect(anyTextContains('<p>'), isFalse);
    expect(anyTextContains(r'$\mathbb'), isFalse);
  });
}
