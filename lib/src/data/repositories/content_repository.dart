import '../../core/api_client.dart';
import '../models/models.dart';
import '../models/school_config.dart';

/// Reads the student content endpoints. Every call is tenant-scoped on the
/// SERVER (by the JWT identity), so the app never sends a school id.
class ContentRepository {
  ContentRepository(this._client);
  final ApiClient _client;

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

  Future<List<ExternalExam>> externalExams({int page = 1}) async {
    final res = await _client.raw.get('/external-exams/', queryParameters: {'page': page});
    return _results(res.data).map((e) => ExternalExam.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> passPlans() async {
    final res = await _client.raw.get('/pass/plans/');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> passTrial() async {
    final res = await _client.raw.post('/pass/trial/');
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
