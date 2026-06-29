// Models for the native QUIZ engine. Mirror GET /api/v1/quizzes/<uuid>/data
// (the existing get_quiz_data shape). Unlike tests, quizzes EMBED the correct
// answers + explanations, so the app scores LOCALLY (web parity) and posts the
// totals to the attempt endpoint.

class QuizOption {
  QuizOption({required this.slNo, required this.text, required this.isCorrect});
  final String slNo;   // 1-based position label
  final String text;
  final bool isCorrect;
  factory QuizOption.fromJson(Map<String, dynamic> j) => QuizOption(
        slNo: (j['sl_no'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        isCorrect: (j['is_correct'] ?? false) == true,
      );
}

class QuizLang {
  QuizLang({this.question = '', this.options = const [], this.explanation = ''});
  final String question;
  final List<QuizOption> options;
  final String explanation;
  factory QuizLang.fromJson(Map<String, dynamic> j) => QuizLang(
        question: (j['question'] ?? '').toString(),
        options: ((j['options'] as List?) ?? [])
            .map((e) => QuizOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        explanation: (j['explanation'] ?? '').toString(),
      );
}

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.type,
    required this.answerType,
    this.marks = 0,
    this.penalty = 0,
    this.correctAnswer,
    this.langs = const {},
  });
  final int id;
  final String type;       // MCQ | MSQ | NUM | FIB
  final String answerType; // single | multiple | range | ...
  final double marks;
  final double penalty;
  final dynamic correctAnswer; // for NUM/FIB (string/number/range map)
  final Map<String, QuizLang> langs;

  bool get isMulti => type.toUpperCase() == 'MSQ' || answerType == 'multiple';
  bool get isNumeric => type.toUpperCase() == 'NUM';
  bool get isFreeText => type.toUpperCase() == 'FIB';
  bool get hasOptions => !isNumeric && !isFreeText;

  QuizLang lang(String code) =>
      langs[code] ?? langs['en'] ?? (langs.isNotEmpty ? langs.values.first : QuizLang());

  List<String> get availableLanguages => langs.keys.toList();

  static double _num(dynamic v) {
    final s = v?.toString().replaceAll('+', '').replaceAll('-', '').trim() ?? '';
    return double.tryParse(s) ?? 0;
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> j) {
    final rawLangs = (j['languages'] as Map?) ?? {};
    final langs = <String, QuizLang>{};
    rawLangs.forEach((k, v) {
      langs[k.toString()] = QuizLang.fromJson(Map<String, dynamic>.from(v as Map));
    });
    return QuizQuestion(
      id: (j['id'] ?? 0) is int ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
      type: (j['questionType'] ?? 'MCQ').toString(),
      answerType: (j['answerType'] ?? 'single').toString(),
      marks: _num(j['marks']),
      penalty: _num(j['penalty']),
      correctAnswer: j['correctAnswer'],
      langs: langs,
    );
  }

  /// Local scoring: is [value] (the student's answer) correct? Mirrors the web's
  /// position-based correctness. For MCQ/MSQ value is the option slNo(s); for
  /// NUM/FIB it's compared to correctAnswer.
  bool isAnswerCorrect(dynamic value) {
    if (hasOptions) {
      final correct = langs.values.isNotEmpty
          ? langs.values.first.options.where((o) => o.isCorrect).map((o) => o.slNo).toSet()
          : <String>{};
      if (correct.isEmpty) return false;
      if (isMulti) {
        final picked = (value is List) ? value.map((e) => e.toString()).toSet() : <String>{};
        return picked.isNotEmpty && picked.length == correct.length && picked.containsAll(correct);
      }
      return value != null && correct.contains(value.toString());
    }
    // NUM range / exact, or FIB text.
    final ans = (value ?? '').toString().trim();
    if (ans.isEmpty) return false;
    final ca = correctAnswer;
    if (ca is Map && ca['start'] != null && ca['end'] != null) {
      final n = double.tryParse(ans);
      final lo = double.tryParse('${ca['start']}');
      final hi = double.tryParse('${ca['end']}');
      if (n == null || lo == null || hi == null) return false;
      return n >= lo && n <= hi;
    }
    return ans.toLowerCase() == (ca ?? '').toString().trim().toLowerCase();
  }
}

class QuizPaper {
  QuizPaper({
    required this.title,
    required this.questions,
    this.languages = const {},
    this.durationMinutes = 0,
  });
  final String title;
  final List<QuizQuestion> questions;
  final Map<String, String> languages; // code -> name
  final int durationMinutes; // quiz time is in MINUTES (payload: duration_minutes)

  double get totalMarks => questions.fold(0.0, (s, q) => s + q.marks);

  List<String> get languageCodes {
    final set = <String>{};
    for (final q in questions) {
      set.addAll(q.availableLanguages);
    }
    final list = set.toList();
    list.sort((a, b) => a == 'en' ? -1 : (b == 'en' ? 1 : a.compareTo(b)));
    return list;
  }

  String languageName(String code) => languages[code] ?? code.toUpperCase();

  factory QuizPaper.fromJson(Map<String, dynamic> data) {
    final secs = (data['sections'] as Map?) ?? {};
    final qs = <QuizQuestion>[];
    for (final sec in secs.values) {
      final m = Map<String, dynamic>.from(sec as Map);
      for (final q in (m['questions'] as List?) ?? []) {
        qs.add(QuizQuestion.fromJson(Map<String, dynamic>.from(q)));
      }
    }
    final langs = <String, String>{};
    (data['available_languages'] as Map?)?.forEach((k, v) => langs[k.toString()] = v.toString());
    return QuizPaper(
      title: (data['testName'] ?? 'Quiz').toString(),
      questions: qs,
      languages: langs,
      durationMinutes: (data['duration_minutes'] is int)
          ? data['duration_minutes'] as int
          : int.tryParse('${data['duration_minutes'] ?? ''}') ?? 0,
    );
  }
}
