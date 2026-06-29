import '../../core/api_client.dart';
import '../models/models.dart';
import '../models/quiz_models.dart';
import '../models/school_config.dart';
import '../models/test_models.dart';

/// One page of a paginated list + whether more pages follow (for infinite scroll).
class PagedResult<T> {
  PagedResult({required this.items, required this.hasMore, required this.page});
  final List<T> items;
  final bool hasMore;
  final int page;
}

/// Reads the student content endpoints. Every call is tenant-scoped on the
/// SERVER (by the JWT identity), so the app never sends a school id.
class ContentRepository {
  ContentRepository(this._client);
  final ApiClient _client;

  Future<AppUser> me() async {
    final res = await _client.raw.get('/me/');
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AppUser> updateProfile(Map<String, dynamic> fields) async {
    final res = await _client.raw.patch('/me/', data: fields);
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<SchoolConfig> schoolConfig() async {
    final res = await _client.raw.get('/school/config/');
    return SchoolConfig.fromJson(res.data as Map<String, dynamic>);
  }

  Future<HomeData> home() async {
    final res = await _client.raw.get('/home/');
    return HomeData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Course>> courses({int page = 1}) async {
    final res = await _client.raw.get('/courses/', queryParameters: {'page': page});
    return _results(res.data).map((e) => Course.fromJson(e)).toList();
  }


  Future<Course> course(String uuid) async {
    final res = await _client.raw.get('/courses/$uuid/');
    return Course.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CourseLessons> courseLessons(String uuid) async {
    final res = await _client.raw.get('/courses/$uuid/lessons/');
    final data = res.data as Map<String, dynamic>;
    return CourseLessons(
      isEnrolled: (data['is_enrolled'] ?? false) as bool,
      lessons: ((data['lessons'] as List?) ?? [])
          .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<TestSeriesItem>> testSeries({int page = 1}) async {
    final res = await _client.raw.get('/test-series/', queryParameters: {'page': page});
    return _results(res.data).map((e) => TestSeriesItem.fromJson(e)).toList();
  }

  /// Load MORE tests for a category (test series) or section (external exam) —
  /// the contents endpoint returns the first 20 per group; this pages in the rest.
  /// Returns (tests, hasMore).
  Future<({List<SeriesTest> tests, bool hasMore})> moreCategoryTests({
    required String parentUuid,
    required String groupUuid,
    required int page,
    required bool external,
  }) async {
    final path = external
        ? '/external-exams/$parentUuid/sections/$groupUuid/tests/'
        : '/test-series/$parentUuid/categories/$groupUuid/tests/';
    final res = await _client.raw.get(path, queryParameters: {'page': page});
    final data = res.data as Map;
    final tests = ((data['tests'] as List?) ?? [])
        .map((e) => SeriesTest.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return (tests: tests, hasMore: (data['has_more'] ?? false) as bool);
  }

  Future<List<BundleItem>> bundles({int page = 1}) async {
    final res = await _client.raw.get('/bundles/', queryParameters: {'page': page});
    return _results(res.data).map((e) => BundleItem.fromJson(e)).toList();
  }

  Future<BundleContents> bundleContents(String uuid) async {
    final res = await _client.raw.get('/bundles/$uuid/contents/');
    return BundleContents.fromJson(res.data as Map<String, dynamic>);
  }

  Future<TestSeriesContents> testSeriesContents(String uuid) async {
    final res = await _client.raw.get('/test-series/$uuid/contents/');
    return TestSeriesContents.fromJson(res.data as Map<String, dynamic>);
  }

  /// External-exam contents. The backend returns the SAME shape as a test series
  /// (sections→`categories`, external tests→`tests`), so we reuse the model and
  /// the test-series detail screen. `is_enrolled` here means "holds a PASS".
  Future<TestSeriesContents> externalExamContents(String uuid) async {
    final res = await _client.raw.get('/external-exams/$uuid/contents/');
    return TestSeriesContents.fromJson(res.data as Map<String, dynamic>);
  }

  /// ONE page of external exams + whether more pages follow. The Tests tab loads
  /// page 1 fast and pages in the rest on scroll (lazy / infinite scroll), so a
  /// school with MANY exams still feels instant and no exam past page 1 is lost
  /// (the earlier bug: app fetched only page 1, hiding low-priority exams that
  /// were on page 2 while the web explore page still showed them).
  Future<PagedResult<ExternalExam>> externalExamsPage({int page = 1}) async {
    final res = await _client.raw.get('/external-exams/', queryParameters: {'page': page});
    final data = res.data;
    final hasMore = data is Map && data['next'] != null && '${data['next']}'.isNotEmpty;
    final items = _results(data).map((e) => ExternalExam.fromJson(e)).toList();
    return PagedResult(items: items, hasMore: hasMore, page: page);
  }

  Future<Map<String, dynamic>> passPlans() async {
    final res = await _client.raw.get('/pass/plans/');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> passTrial() async {
    final res = await _client.raw.post('/pass/trial/');
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── Native live class ──
  Future<Map<String, dynamic>> liveToken(String lessonUuid) async {
    final res = await _client.raw.post('/live/token/', data: {'lesson_uuid': lessonUuid});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<Map<String, dynamic>>> liveChatHistory(String lessonUuid) async {
    final res = await _client.raw.get('/live/$lessonUuid/chat/');
    final data = res.data;
    final list = (data is Map ? (data['messages'] ?? data['results'] ?? []) : data) as List? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> liveChatSend(String lessonUuid, String message) async {
    await _client.raw.post('/live/$lessonUuid/chat/save/', data: {'message': message});
  }

  // ── Native test engine ──
  Future<Map<String, dynamic>> testPaper(String uuid, {bool authMode = false}) async {
    final res = await _client.raw.get('/tests/$uuid/attempt/',
        queryParameters: {'auth_mode': authMode ? 'true' : 'false'});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<String?> createAttempt(String testUuid, {bool authMode = false, bool fresh = false}) async {
    final res = await _client.raw.post('/tests/attempt/create/', data: {
      'test_id': testUuid, 'auth_mode': authMode ? 'true' : 'false',
      'fresh_start': fresh ? 'true' : 'false',
    });
    final d = Map<String, dynamic>.from(res.data as Map);
    return (d['attempt_id'] ?? d['attempt'] ?? d['attempt_uuid'])?.toString();
  }

  Future<void> saveAnswers(String attemptId, Map<String, dynamic> answers, {bool authMode = false}) async {
    await _client.raw.post('/tests/attempt/save/', data: {
      'attempt_id': attemptId, 'answers': answers, 'auth_mode': authMode ? 'true' : 'false',
    });
  }

  Future<Map<String, dynamic>> submitTest(String attemptId, {bool authMode = false}) async {
    final res = await _client.raw.post('/tests/attempt/submit/', data: {
      'attempt_id': attemptId, 'auth_mode': authMode ? 'true' : 'false',
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> testResult(String attemptUuid) async {
    final res = await _client.raw.get('/tests/result/$attemptUuid/');
    return Map<String, dynamic>.from(res.data as Map);
  }

  // ── Native quiz engine (quiz embeds answers → scored locally → attempt recorded) ──
  Future<QuizPaper> quizData(String quizUuid) async {
    final res = await _client.raw.get('/quizzes/$quizUuid/data/');
    return QuizPaper.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// Record a finished quiz attempt + get gamification (xp/coins/badges/leaderboard).
  Future<Map<String, dynamic>> recordQuizAttempt(
      String quizUuid, double marks, double total, int timeSeconds) async {
    final pct = total > 0 ? (marks / total) * 100 : 0;
    final res = await _client.raw.post('/quizzes/$quizUuid/attempt/', data: {
      'marks_obtained': marks, 'total_marks': total,
      'percentage': pct, 'time_taken_seconds': timeSeconds,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Test leaderboard (rank/percentile/total + top performers). Same numbers as
  /// the web result page (shared backend builder, synthetic-fill aware).
  Future<Map<String, dynamic>> testLeaderboard(String attemptUuid) async {
    final res = await _client.raw.get('/tests/leaderboard/$attemptUuid/');
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// The student's last 3 completed attempts of the SAME test (for the result
  /// page's attempt switcher). Most recent first; each {attempt_uuid, attempt_number,
  /// date, score, is_current}.
  Future<List<Map<String, dynamic>>> testAttempts(String attemptUuid) async {
    final res = await _client.raw.get('/tests/$attemptUuid/attempts/');
    final list = (res.data is Map ? (res.data['attempts'] ?? []) : []) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Submit a post-test rating (0–5) + optional review for the test's parent
  /// series/exam (→ the existing Review model). Returns the server message.
  Future<Map<String, dynamic>> submitTestReview(
      String attemptUuid, double rating, String reviewText) async {
    final res = await _client.raw.post('/tests/$attemptUuid/review/',
        data: {'rating': rating, 'review_text': reviewText});
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// The student's complaints/feedback (recent first) — reuses the web Complaint
  /// model, so admins see app-raised issues in the same place.
  Future<List<Map<String, dynamic>>> complaints() async {
    final res = await _client.raw.get('/complaints/');
    final list = (res.data is Map ? (res.data['results'] ?? []) : []) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Raise a new complaint or feedback entry (admin-visible).
  Future<void> submitComplaint({
    required String subject,
    required String description,
    required String entryType, // 'complaint' | 'feedback'
    String category = 'other',
    String? feedbackType,
  }) async {
    await _client.raw.post('/complaints/', data: {
      'subject': subject, 'description': description, 'entry_type': entryType,
      'category': category, if (feedbackType != null) 'feedback_type': feedbackType,
    });
  }

  /// Detailed per-question solution for a completed attempt (your answer vs
  /// correct + explanation). Same data the web solution page shows.
  Future<TestSolution> testSolution(String attemptUuid) async {
    final res = await _client.raw.get('/tests/solution/$attemptUuid/');
    final data = Map<String, dynamic>.from((res.data as Map)['data'] ?? {});
    return TestSolution.fromJson(data);
  }

  // ── Forum ──
  Future<Map<String, dynamic>> forumList({int page = 1}) async {
    final res = await _client.raw.get('/forum/', queryParameters: {'page': page});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> forumDetail(String uuid) async {
    final res = await _client.raw.get('/forum/$uuid/');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> forumAsk(String title, String body, String tags) async {
    await _client.raw.post('/forum/', data: {'title': title, 'body': body, 'tags': tags});
  }

  Future<void> forumAnswer(String questionUuid, String body) async {
    await _client.raw.post('/forum/$questionUuid/', data: {'body': body});
  }

  Future<int> forumVote(String target, String uuid, int value) async {
    final res = await _client.raw.post('/forum/vote/', data: {'target': target, 'uuid': uuid, 'value': value});
    return (res.data['votes'] ?? 0) as int;
  }

  Future<Map<String, dynamic>> coins({int page = 1}) async {
    final res = await _client.raw.get('/coins/', queryParameters: {'page': page});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<AppNotification>> notifications({int page = 1}) async {
    final res = await _client.raw.get('/notifications/', queryParameters: {'page': page});
    return _results(res.data).map((e) => AppNotification.fromJson(e)).toList();
  }

  Future<List<Order>> orders({int page = 1}) async {
    final res = await _client.raw.get('/orders/', queryParameters: {'page': page});
    return _results(res.data).map((e) => Order.fromJson(e)).toList();
  }

  /// Everything the student currently OWNS (live access): courses, test series,
  /// bundles, and whether they hold a PASS. Powers Profile → My learning.
  Future<MyEnrolled> myEnrolled() async {
    final res = await _client.raw.get('/my-enrolled/');
    return MyEnrolled.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CourseQuizzes> courseQuizzes(String uuid) async {
    final res = await _client.raw.get('/courses/$uuid/quizzes/');
    final data = res.data as Map<String, dynamic>;
    return CourseQuizzes(
      isEnrolled: (data['is_enrolled'] ?? false) as bool,
      quizzes: ((data['quizzes'] as List?) ?? [])
          .map((e) => Quiz.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<List<Comment>> lessonComments(String lessonUuid, {int page = 1}) async {
    final res = await _client.raw.get('/lessons/$lessonUuid/comments/',
        queryParameters: {'page': page});
    return _results(res.data).map((e) => Comment.fromJson(e)).toList();
  }

  Future<Comment> postComment(String lessonUuid, String text, {int? parentId}) async {
    final res = await _client.raw.post('/lessons/$lessonUuid/comments/',
        data: {'text': text, if (parentId != null) 'parent_id': parentId});
    return Comment.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Comment>> commentReplies(String lessonUuid, int commentId) async {
    final res = await _client.raw.get('/lessons/$lessonUuid/comments/$commentId/replies/');
    return ((res.data['replies'] as List?) ?? [])
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> toggleCommentLike(String lessonUuid, int commentId) async {
    final res = await _client.raw.post('/lessons/$lessonUuid/comments/$commentId/like/');
    return res.data as Map<String, dynamic>;
  }

  // ── Cart ──
  Future<CartData> cart() async {
    final res = await _client.raw.get('/cart/');
    return CartData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CartData> cartAdd(String itemType, String uuid) async {
    final res = await _client.raw.post('/cart/add/', data: {'item_type': itemType, 'uuid': uuid});
    return CartData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CartData> cartRemove(int id) async {
    final res = await _client.raw.post('/cart/remove/', data: {'id': id});
    return CartData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CartData> cartCoupon(String code) async {
    final res = await _client.raw.post('/cart/coupon/', data: {'code': code});
    return CartData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<CartData> cartCoins(bool use) async {
    final res = await _client.raw.post('/cart/coins/', data: {'use': use});
    return CartData.fromJson(res.data as Map<String, dynamic>);
  }

  /// Ask the backend for a one-time authenticated URL to open a web feature
  /// (test-window, quiz, etc.) inside an in-app browser. [next] is a safe
  /// in-site path like '/attempt/<uuid>/'.
  Future<String> handoffUrl(String next) async {
    final res = await _client.raw.post('/handoff/', data: {'next': next});
    return (res.data['url'] ?? '') as String;
  }

  /// DRF paginated responses wrap rows in `results`; tolerate a bare list too.
  List<Map<String, dynamic>> _results(dynamic data) {
    if (data is Map && data['results'] is List) {
      return (data['results'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const [];
  }

}

class CourseLessons {
  CourseLessons({required this.isEnrolled, required this.lessons});
  final bool isEnrolled;
  final List<Lesson> lessons;
}

class CourseQuizzes {
  CourseQuizzes({required this.isEnrolled, required this.quizzes});
  final bool isEnrolled;
  final List<Quiz> quizzes;
}
