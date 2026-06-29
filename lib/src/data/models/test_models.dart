// Models for the native test engine. Mirror the JSON from
// GET /api/v1/tests/<uuid>/attempt (the existing get_test_details_student shape).

class TestOption {
  TestOption({required this.slNo, required this.text});
  final String slNo; // option label/prompt (A/B/1/2…)
  final String text;
  factory TestOption.fromJson(Map<String, dynamic> j) => TestOption(
        slNo: (j['sl_no'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
      );
}

/// A shared passage / case-study that several questions reference (4–5 questions
/// can share one). `content.languages[code].text` holds the passage HTML per
/// language (falling back to `content.text`), exactly like the web test window.
class QuestionGroup {
  QuestionGroup({this.id, this.title = '', this.type = '', this.langText = const {}, this.fallbackText = ''});
  final int? id;
  final String title;
  final String type; // passage | case_study | comprehension | paragraph
  final Map<String, String> langText; // code -> passage HTML
  final String fallbackText;

  bool get isEmpty => langText.isEmpty && fallbackText.isEmpty;

  /// Passage HTML for [code] (→ en → any → flat content.text).
  String text(String code) {
    if (langText.isEmpty) return fallbackText;
    return langText[code] ?? langText['en'] ?? langText.values.first;
  }

  factory QuestionGroup.fromJson(Map<String, dynamic> j) {
    final content = (j['content'] as Map?) ?? {};
    final langs = (content['languages'] as Map?) ?? {};
    final map = <String, String>{};
    langs.forEach((code, v) {
      final m = (v as Map?) ?? {};
      final t = (m['text'] ?? '').toString();
      if (t.isNotEmpty) map[code.toString()] = t;
    });
    return QuestionGroup(
      id: j['id'] is int ? j['id'] as int : null,
      title: (j['title'] ?? '').toString(),
      type: (j['type'] ?? '').toString(),
      langText: map,
      fallbackText: (content['text'] ?? '').toString(),
    );
  }
}

/// One language variant of a question's renderable content.
class QuestionLang {
  QuestionLang({this.question = '', this.comprehension = '', this.options = const []});
  final String question;
  final String comprehension;
  final List<TestOption> options;
  factory QuestionLang.fromJson(Map<String, dynamic> j) => QuestionLang(
        question: (j['question'] ?? '').toString(),
        comprehension: (j['comp'] ?? '').toString(),
        options: ((j['options'] as List?) ?? [])
            .map((e) => TestOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class TestQuestion {
  TestQuestion({
    required this.uuid,
    required this.id,
    required this.type,
    this.marks = '',
    this.penalty = '',
    this.langs = const {},
    this.availableLanguages = const [],
    this.group,
  });

  final String uuid;
  final int id;
  final String type; // 'mcq' | 'mamcq' | 'numerical' | ...
  final String marks;
  final String penalty;
  // ALL language variants (so the player can switch language live, like the web).
  final Map<String, QuestionLang> langs;
  final List<String> availableLanguages;
  final QuestionGroup? group; // shared passage, when this question belongs to one

  /// Resolve the content for [code], falling back to English, then any language.
  QuestionLang lang(String code) =>
      langs[code] ?? langs['en'] ?? (langs.isNotEmpty ? langs.values.first : QuestionLang());

  factory TestQuestion.fromJson(Map<String, dynamic> j) {
    final raw = (j['languages'] as Map?) ?? {};
    final langs = <String, QuestionLang>{};
    raw.forEach((k, v) {
      langs[k.toString()] = QuestionLang.fromJson(Map<String, dynamic>.from(v as Map));
    });
    final avail = ((j['availableLanguages'] as List?) ?? langs.keys.toList())
        .map((e) => e.toString())
        .toList();
    final qg = j['question_group'];
    return TestQuestion(
      uuid: (j['uuid'] ?? '').toString(),
      id: (j['id'] ?? 0) as int,
      type: (j['questionType'] ?? 'mcq').toString().toLowerCase(),
      marks: (j['marks'] ?? '').toString(),
      penalty: (j['penalty'] ?? '').toString(),
      langs: langs,
      availableLanguages: avail,
      group: (qg is Map) ? QuestionGroup.fromJson(Map<String, dynamic>.from(qg)) : null,
    );
  }

  bool get isMulti => type == 'mamcq' || type == 'msq';
  // NUM / NAT (GATE) → on-screen numeric keypad (web parity: renderNumericInput).
  bool get isNumericKeypad =>
      type == 'num' || type == 'nat' || type == 'numerical' || type == 'integer';
  // FIB / TITA (CAT) → free-text answer (web parity: renderTitaInput).
  bool get isFreeText => type == 'fib' || type == 'tita';
  // Anything without options is an "answer" type (keypad or free text).
  bool get isNumeric => isNumericKeypad || isFreeText;
}

class TestSection {
  TestSection({
    required this.title,
    required this.timeSeconds,
    required this.questions,
    this.lockOnExit = false,
    this.isQualifying = false,
  });
  final String title;
  final int timeSeconds;       // per-section time (used in sectional-submit mode)
  final List<TestQuestion> questions;
  final bool lockOnExit;       // CAT-style: section locks once the student leaves
  final bool isQualifying;
  factory TestSection.fromJson(Map<String, dynamic> j) => TestSection(
        title: (j['title'] ?? '') as String,
        timeSeconds: (j['time'] ?? 0) is int ? (j['time'] ?? 0) as int : 0,
        lockOnExit: (j['lock_on_exit'] ?? false) as bool,
        isQualifying: (j['is_qualifying'] ?? false) as bool,
        questions: ((j['questions'] as List?) ?? [])
            .map((e) => TestQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// Per-question-type template config (from the web test-window template). Drives
/// the app's INPUT UI only — scoring is always done by the backend. Keys mirror
/// the web's `question_types[<type>]`: `mandatory`, `last_opt_is_skip`,
/// `num_options`, `has_negative`, `partial_marking`.
class QuestionTypeConfig {
  QuestionTypeConfig({
    this.mandatory = false,
    this.lastOptIsSkip = false,
    this.numOptions,
    this.hasNegative = true,
    this.partialMarking = false,
  });
  final bool mandatory;        // blank → backend scores as wrong; app warns
  final bool lastOptIsSkip;    // BPSC Option-E: last option = explicit skip
  final int? numOptions;       // option count (the skip option is at this position)
  final bool hasNegative;      // negative marking applies for this type
  final bool partialMarking;   // MSQ partial marks

  static QuestionTypeConfig fromJson(Map<String, dynamic> j) => QuestionTypeConfig(
        mandatory: (j['mandatory'] ?? false) == true,
        lastOptIsSkip: (j['last_opt_is_skip'] ?? false) == true,
        numOptions: j['num_options'] is int
            ? j['num_options'] as int
            : int.tryParse('${j['num_options'] ?? ''}'),
        hasNegative: (j['has_negative'] ?? true) == true,
        partialMarking: (j['partial_marking'] ?? false) == true,
      );

  static const empty = null;
}

class TestPaper {
  TestPaper({
    required this.testName,
    required this.testId,
    required this.durationSeconds,
    required this.sections,
    this.sectionalSubmit = false,
    this.showCalculator = false,
    this.instructions = const [],
    this.languages = const {},
    this.questionTypes = const {},
  });

  final String testName;
  final String testId;
  // SECONDS. The API's `duration` field is stored in seconds (e.g. 2100 = 35 min,
  // 5400 = 90 min) — NOT minutes. Treating it as minutes ×60'd the timer into
  // "many hours". Use this directly as the countdown seconds.
  final int durationSeconds;
  final List<TestSection> sections;
  final bool sectionalSubmit;
  final bool showCalculator; // GATE-style: show the scientific calculator button
  // Instruction blocks ({type, value}) + available languages {code: name} — for
  // the pre-test instruction/language screen and the in-test language switcher.
  final List<Map<String, dynamic>> instructions;
  final Map<String, String> languages;
  // Template config keyed by lower-cased question type (mcq/msq/…).
  final Map<String, QuestionTypeConfig> questionTypes;

  /// Template config for a question's type (empty config when none).
  QuestionTypeConfig configFor(String qtype) =>
      questionTypes[qtype.toLowerCase()] ?? QuestionTypeConfig();

  /// Whole minutes, for DISPLAY only (instructions/meta). The countdown uses
  /// [durationSeconds] directly.
  int get durationMinutes => (durationSeconds / 60).round();

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
    final langs = <String, String>{};
    (data['languages'] as Map?)?.forEach((k, v) => langs[k.toString()] = v.toString());
    final qtypes = <String, QuestionTypeConfig>{};
    (data['questionTypes'] as Map?)?.forEach((k, v) {
      if (v is Map) {
        qtypes[k.toString().toLowerCase()] =
            QuestionTypeConfig.fromJson(Map<String, dynamic>.from(v));
      }
    });
    return TestPaper(
      testName: (data['testName'] ?? 'Test') as String,
      testId: (data['testId'] ?? '') as String,
      durationSeconds: (data['duration'] ?? 0) as int, // API sends SECONDS
      sectionalSubmit: (data['sectionalSubmit'] ?? false) as bool,
      showCalculator: (data['showCalculator'] ?? false) as bool,
      instructions: ((data['instructions'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      languages: langs,
      questionTypes: qtypes,
      sections: sections,
    );
  }

  List<TestQuestion> get allQuestions =>
      [for (final s in sections) ...s.questions];

  /// Total marks = sum of each question's (positive) marks. Returns 0 when no
  /// question carries a parseable marks value (caller can then hide the field).
  double get maxMarks {
    double total = 0;
    for (final q in allQuestions) {
      final m = double.tryParse(q.marks.replaceAll('+', '').trim());
      if (m != null) total += m;
    }
    return total;
  }

  /// Languages actually present across the questions (intersected with the
  /// test-level language list when available). English first, then the rest.
  List<String> get languageCodes {
    final set = <String>{};
    for (final q in allQuestions) {
      set.addAll(q.availableLanguages);
    }
    if (languages.isNotEmpty) {
      set.retainWhere(languages.containsKey);
      set.addAll(languages.keys.where(set.contains));
    }
    final list = set.toList();
    list.sort((a, b) => a == 'en' ? -1 : (b == 'en' ? 1 : a.compareTo(b)));
    return list;
  }

  String languageName(String code) => languages[code] ?? _defaultLangName(code);
}

/// Fallback display names when the test-level map is absent (codes match
/// schools/constants.py LANGUAGE_CODE_MAP; note Hindi = 'hn').
String _defaultLangName(String code) {
  const m = {
    'en': 'English', 'hn': 'Hindi', 'bn': 'Bengali', 'mr': 'Marathi',
    'te': 'Telugu', 'ta': 'Tamil', 'gu': 'Gujarati', 'kn': 'Kannada',
    'ml': 'Malayalam', 'or': 'Odia', 'pa': 'Punjabi', 'ur': 'Urdu',
    'as': 'Assamese', 'sa': 'Sanskrit', 'ne': 'Nepali',
  };
  return m[code] ?? code.toUpperCase();
}

// ─────────────────────────── solution review ───────────────────────────────
/// One option in the solution view, flagged correct/selected so the UI can show
/// green (correct), red (your wrong pick), etc. — like the web solution page.
class SolutionOption {
  SolutionOption({required this.slNo, required this.text, this.isCorrect = false, this.isSelected = false});
  final String slNo;
  final String text;
  final bool isCorrect;
  final bool isSelected;
  factory SolutionOption.fromJson(Map<String, dynamic> j) => SolutionOption(
        slNo: (j['sl_no'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        isCorrect: (j['is_correct'] ?? false) as bool,
        isSelected: (j['is_selected'] ?? false) as bool,
      );
}

/// One language variant of a solution question (its text/options + explanation).
class SolutionLang {
  SolutionLang({
    this.question = '',
    this.comprehension = '',
    this.options = const [],
    this.solutionHtml = '',
  });
  final String question;
  final String comprehension;
  final List<SolutionOption> options;
  final String solutionHtml;
}

class SolutionQuestion {
  SolutionQuestion({
    required this.uuid,
    required this.slNo,
    required this.status,        // Correct | Incorrect | Unattempted
    this.marks = '',
    this.penalty = '',
    this.correctAnswer = '',
    this.yourAnswer = '',
    this.type = '',
    this.langs = const {},
    this.availableLanguages = const [],
    this.group,
  });
  final String uuid;
  final int slNo;
  final String status;
  final String marks;
  final String penalty;
  final String correctAnswer;  // for numeric/range types
  final String yourAnswer;     // for numeric/range types
  final String type;
  final Map<String, SolutionLang> langs;
  final List<String> availableLanguages;
  final QuestionGroup? group; // shared passage

  bool get isCorrect => status == 'Correct';
  bool get isIncorrect => status == 'Incorrect';
  bool get isUnattempted => status == 'Unattempted';

  SolutionLang lang(String code) =>
      langs[code] ?? langs['en'] ?? (langs.isNotEmpty ? langs.values.first : SolutionLang());

  factory SolutionQuestion.fromJson(Map<String, dynamic> j) {
    final rawLangs = (j['languages'] as Map?) ?? {};
    final sol = (j['solution'] as Map?) ?? {};
    final langs = <String, SolutionLang>{};
    rawLangs.forEach((code, v) {
      final lang = Map<String, dynamic>.from(v as Map);
      final solLang = Map<String, dynamic>.from(
          (sol[code] ?? sol['en'] ?? (sol.isNotEmpty ? sol.values.first : {})) as Map);
      langs[code.toString()] = SolutionLang(
        question: (lang['question'] ?? '').toString(),
        comprehension: (lang['comp'] ?? '').toString(),
        options: ((lang['options'] as List?) ?? [])
            .map((e) => SolutionOption.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        solutionHtml: (solLang['text'] ?? '').toString(),
      );
    });
    final ca = j['correct_answer'];
    final qg = j['question_group'];
    return SolutionQuestion(
      uuid: (j['id'] ?? '').toString(),
      slNo: (j['sl_no'] ?? 0) is int ? (j['sl_no'] ?? 0) as int : 0,
      status: (j['status'] ?? j['is_correct'] ?? '').toString(),
      marks: (j['marks'] ?? '').toString(),
      penalty: (j['penalty'] ?? '').toString(),
      correctAnswer: ca == null ? '' : (ca is List ? ca.join(', ') : ca.toString()),
      yourAnswer: (j['answer_text'] ?? '').toString(),
      type: (j['questionType'] ?? '').toString(),
      langs: langs,
      availableLanguages: ((j['availableLanguages'] as List?) ?? rawLangs.keys.toList())
          .map((e) => e.toString())
          .toList(),
      group: (qg is Map) ? QuestionGroup.fromJson(Map<String, dynamic>.from(qg)) : null,
    );
  }
}

class TestSolution {
  TestSolution({
    this.testName = '',
    this.correct = 0,
    this.incorrect = 0,
    this.unattempted = 0,
    this.questions = const [],
  });
  final String testName;
  final int correct;
  final int incorrect;
  final int unattempted;
  final List<SolutionQuestion> questions; // flattened across sections, in order

  /// Languages present across the solution questions (English first).
  List<String> get languageCodes {
    final set = <String>{};
    for (final q in questions) {
      set.addAll(q.availableLanguages);
    }
    final list = set.toList();
    list.sort((a, b) => a == 'en' ? -1 : (b == 'en' ? 1 : a.compareTo(b)));
    return list;
  }

  String languageName(String code) => _defaultLangName(code);

  factory TestSolution.fromJson(Map<String, dynamic> data) {
    final secs = (data['sections'] as Map?) ?? {};
    final qs = <SolutionQuestion>[];
    for (final sec in secs.values) {
      final m = Map<String, dynamic>.from(sec as Map);
      for (final q in (m['questions'] as List?) ?? []) {
        qs.add(SolutionQuestion.fromJson(Map<String, dynamic>.from(q)));
      }
    }
    return TestSolution(
      testName: (data['testName'] ?? 'Test').toString(),
      correct: (data['correct_count'] ?? 0) is int ? data['correct_count'] as int : 0,
      incorrect: (data['incorrect_count'] ?? 0) is int ? data['incorrect_count'] as int : 0,
      unattempted: (data['unattempted_count'] ?? 0) is int ? data['unattempted_count'] as int : 0,
      questions: qs,
    );
  }
}
