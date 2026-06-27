/// Models for the native test engine. Mirror the JSON from
/// GET /api/v1/tests/<uuid>/attempt (the existing get_test_details_student shape).

class TestOption {
  TestOption({required this.slNo, required this.text});
  final String slNo; // option label/prompt (A/B/1/2…)
  final String text;
  factory TestOption.fromJson(Map<String, dynamic> j) => TestOption(
        slNo: (j['sl_no'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
      );
}

class TestQuestion {
  TestQuestion({
    required this.uuid,
    required this.id,
    required this.type,
    this.marks = '',
    this.penalty = '',
    this.question = '',
    this.comprehension = '',
    this.options = const [],
  });

  final String uuid;
  final int id;
  final String type; // 'mcq' | 'mamcq' | 'numerical' | ...
  final String marks;
  final String penalty;
  final String question;
  final String comprehension;
  final List<TestOption> options;

  /// Build from the API question, picking a language (first available).
  factory TestQuestion.fromJson(Map<String, dynamic> j) {
    final langs = (j['languages'] as Map?) ?? {};
    Map<String, dynamic> lang = {};
    if (langs.isNotEmpty) {
      // Prefer English, else first.
      lang = Map<String, dynamic>.from(langs['en'] ?? langs.values.first);
    }
    return TestQuestion(
      uuid: (j['uuid'] ?? '').toString(),
      id: (j['id'] ?? 0) as int,
      type: (j['questionType'] ?? 'mcq').toString().toLowerCase(),
      marks: (j['marks'] ?? '').toString(),
      penalty: (j['penalty'] ?? '').toString(),
      question: (lang['question'] ?? '').toString(),
      comprehension: (lang['comp'] ?? '').toString(),
      options: ((lang['options'] as List?) ?? [])
          .map((e) => TestOption.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  bool get isMulti => type == 'mamcq' || type == 'msq';
  bool get isNumeric => type == 'numerical' || type == 'nat' || type == 'integer';
}

class TestSection {
  TestSection({required this.title, required this.timeSeconds, required this.questions});
  final String title;
  final int timeSeconds;
  final List<TestQuestion> questions;
  factory TestSection.fromJson(Map<String, dynamic> j) => TestSection(
        title: (j['title'] ?? '') as String,
        timeSeconds: (j['time'] ?? 0) is int ? (j['time'] ?? 0) as int : 0,
        questions: ((j['questions'] as List?) ?? [])
            .map((e) => TestQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class TestPaper {
  TestPaper({
    required this.testName,
    required this.testId,
    required this.durationMinutes,
    required this.sections,
    this.sectionalSubmit = false,
  });

  final String testName;
  final String testId;
  final int durationMinutes;
  final List<TestSection> sections;
  final bool sectionalSubmit;

  factory TestPaper.fromJson(Map<String, dynamic> data) {
    final secsRaw = data['sections'];
    final List<TestSection> sections = [];
    if (secsRaw is Map) {
      // keyed by index "0","1"… — keep order by numeric key
      final keys = secsRaw.keys.map((k) => int.tryParse(k.toString()) ?? 0).toList()..sort();
      for (final k in keys) {
        sections.add(TestSection.fromJson(Map<String, dynamic>.from(secsRaw['$k'] ?? secsRaw[k])));
      }
    } else if (secsRaw is List) {
      for (final s in secsRaw) {
        sections.add(TestSection.fromJson(Map<String, dynamic>.from(s)));
      }
    }
    return TestPaper(
      testName: (data['testName'] ?? 'Test') as String,
      testId: (data['testId'] ?? '') as String,
      durationMinutes: (data['duration'] ?? 0) as int,
      sectionalSubmit: (data['sectionalSubmit'] ?? false) as bool,
      sections: sections,
    );
  }

  List<TestQuestion> get allQuestions =>
      [for (final s in sections) ...s.questions];
}
