/// Data models mirroring the /api/v1 student endpoints. Kept lean to match the
/// serializers in api/v1/serializers.py on the backend.

class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.userType,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.bio = '',
    this.address = '',
    this.profileImage = '',
  });
  final int id;
  final String email;
  final String fullName;
  final String userType;
  final String firstName;
  final String lastName;
  final String phone;
  final String bio;
  final String address;
  final String profileImage;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        email: (j['email'] ?? '') as String,
        fullName: (j['full_name'] ?? '') as String,
        userType: (j['user_type'] ?? '') as String,
        firstName: (j['first_name'] ?? '') as String,
        lastName: (j['last_name'] ?? '') as String,
        phone: (j['phone_number'] ?? '') as String,
        bio: (j['bio'] ?? '') as String,
        address: (j['comm_address'] ?? '') as String,
        profileImage: (j['profile_image'] ?? '') as String,
      );
}

class Course {
  Course({
    required this.uuid,
    required this.title,
    this.slug,
    this.author = '',
    this.thumbnail = '',
    this.isFree = false,
    this.isEnrolled = false,
    this.price = '0',
    this.finalPrice = '0',
    this.discountActive = false,
    this.totalLessons = 0,
    this.totalDuration = 0,
    this.averageRating = 0,
    this.description = '',
  });

  final String uuid;
  final String title;
  final String? slug;
  final String author;
  final String thumbnail;
  final bool isFree;
  final bool isEnrolled;
  final String price;          // original (struck through when discounted)
  final String finalPrice;     // discounted price actually paid (web parity)
  final bool discountActive;   // whether a discount is live → show strike-through
  final int totalLessons;
  final int totalDuration;
  final double averageRating;
  final String description;

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        uuid: j['uuid'] as String,
        title: (j['title'] ?? '') as String,
        slug: j['slug']?.toString(),
        author: (j['author'] ?? '') as String,
        thumbnail: (j['thumbnail'] ?? '') as String,
        isFree: (j['is_free'] ?? false) as bool,
        isEnrolled: (j['is_enrolled'] ?? false) as bool,
        price: (j['price'] ?? '0').toString(),
        finalPrice: (j['final_price'] ?? j['price'] ?? '0').toString(),
        discountActive: (j['discount_active'] ?? false) as bool,
        totalLessons: (j['total_lessons'] ?? 0) as int,
        totalDuration: (j['total_duration'] ?? 0) as int,
        averageRating: double.tryParse('${j['average_rating'] ?? 0}') ?? 0,
        description: (j['description'] ?? '') as String,
      );
}

class Attachment {
  Attachment({
    required this.uuid,
    required this.title,
    this.type = 'other',
    this.isContent = false,
    this.richText = '',
    this.fileUrl = '',
    this.allowDownload = false,
  });

  final String uuid;
  final String title;
  final String type;
  final bool isContent;
  final String richText;
  final String fileUrl;
  // Admin opt-in: only when true may the student save/share the file. Default
  // false = view-only (basic content protection).
  final bool allowDownload;

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        uuid: j['uuid'].toString(),
        title: (j['title'] ?? '') as String,
        type: (j['attachment_type'] ?? 'other') as String,
        isContent: (j['is_content'] ?? false) as bool,
        richText: (j['rich_text_content'] ?? '') as String,
        fileUrl: (j['file_url'] ?? '') as String,
        allowDownload: (j['allow_download'] ?? false) as bool,
      );
}

class Lesson {
  Lesson({
    required this.uuid,
    required this.title,
    this.description = '',
    this.lessonType = 'other',
    this.duration = 0,
    this.isFree = false,
    this.playbackUrl = '',
    this.resourceUrl = '',
    this.categoryUuid = '',
    this.attachments = const [],
    this.locked = false,
  });

  final String uuid;
  final String title;
  final String description;
  final String lessonType;
  final int duration;
  final bool isFree;
  final String playbackUrl;
  final String resourceUrl;
  final String categoryUuid;
  final List<Attachment> attachments;
  // True when the student can't open the content yet (not enrolled, not free).
  // The lesson still shows in the list (web parity); content URLs are empty.
  final bool locked;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        uuid: j['uuid'] as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        lessonType: (j['lesson_type'] ?? 'other') as String,
        duration: (j['duration'] ?? 0) as int,
        isFree: (j['is_free'] ?? false) as bool,
        playbackUrl: (j['playback_url'] ?? '') as String,
        resourceUrl: (j['resource_url'] ?? '') as String,
        categoryUuid: (j['category_uuid'] ?? '') as String,
        attachments: ((j['attachments'] as List?) ?? [])
            .map((e) => Attachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        locked: (j['locked'] ?? false) as bool,
      );
}

class TestItem {
  TestItem({
    required this.uuid,
    required this.title,
    this.description = '',
    this.isFree = false,
    this.questions = 0,
    this.duration = 0,
    this.isAvailable = true,
  });

  final String uuid;
  final String title;
  final String description;
  final bool isFree;
  final int questions;
  final int duration;
  final bool isAvailable;

  factory TestItem.fromJson(Map<String, dynamic> j) => TestItem(
        uuid: j['uuid'] as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        isFree: (j['is_free'] ?? false) as bool,
        questions: (j['no_of_questions'] ?? 0) as int,
        duration: (j['duration'] ?? 0) as int,
        isAvailable: (j['is_available'] ?? true) as bool,
      );
}

class TestSeriesItem {
  TestSeriesItem({
    required this.uuid,
    required this.title,
    this.slug,
    this.description = '',
    this.thumbnail = '',
    this.isFree = false,
    this.isEnrolled = false,
    this.price = '0',
    this.finalPrice = '0',
    this.discountActive = false,
    this.totalTests = 0,
    this.totalQuestions = 0,
  });

  final String uuid;
  final String title;
  final String? slug;
  final String description;
  final String thumbnail;
  final bool isFree;
  final bool isEnrolled;
  final String price;          // original (struck through when discounted)
  final String finalPrice;     // discounted price actually paid (web parity)
  final bool discountActive;
  final int totalTests;
  final int totalQuestions;

  factory TestSeriesItem.fromJson(Map<String, dynamic> j) => TestSeriesItem(
        uuid: j['uuid'] as String,
        title: (j['title'] ?? '') as String,
        slug: j['slug']?.toString(),
        description: (j['description'] ?? '') as String,
        thumbnail: (j['thumbnail'] ?? '') as String,
        isFree: (j['is_free'] ?? false) as bool,
        isEnrolled: (j['is_enrolled'] ?? false) as bool,
        price: (j['price'] ?? '0').toString(),
        finalPrice: (j['final_price'] ?? j['price'] ?? '0').toString(),
        discountActive: (j['discount_active'] ?? false) as bool,
        totalTests: (j['total_tests'] ?? 0) as int,
        totalQuestions: (j['total_questions'] ?? 0) as int,
      );
}

class BundleItem {
  BundleItem({
    required this.uuid,
    required this.title,
    this.slug,
    this.description = '',
    this.thumbnail = '',
    this.isFree = false,
    this.isEnrolled = false,
    this.price = '0',
    this.finalPrice = '0',
    this.discountActive = false,
    this.totalValue = '0',
    this.savings = '0',
  });

  final String uuid;
  final String title;
  final String? slug;
  final String description;
  final String thumbnail;
  final bool isFree;
  final bool isEnrolled;
  final String price;          // original bundle price (before % discount)
  final String finalPrice;     // discounted bundle price actually paid (web parity)
  final bool discountActive;
  final String totalValue;     // "Worth" = sum of item prices (struck on the web)
  final String savings;        // total_value − final_price (server-computed, web parity)

  factory BundleItem.fromJson(Map<String, dynamic> j) => BundleItem(
        uuid: j['uuid'] as String,
        title: (j['title'] ?? '') as String,
        slug: j['slug']?.toString(),
        description: (j['description'] ?? '') as String,
        thumbnail: (j['thumbnail'] ?? '') as String,
        isFree: (j['is_free'] ?? false) as bool,
        isEnrolled: (j['is_enrolled'] ?? false) as bool,
        price: (j['price'] ?? '0').toString(),
        finalPrice: (j['final_price'] ?? j['price'] ?? '0').toString(),
        discountActive: (j['discount_active'] ?? false) as bool,
        totalValue: (j['total_value'] ?? '0').toString(),
        savings: (j['savings_amount'] ?? '0').toString(),
      );
}

class ExternalExam {
  ExternalExam({
    required this.uuid,
    required this.title,
    this.slug = '',
    this.description = '',
    this.thumbnail = '',
    this.isFree = false,
    this.totalTests = 0,
    this.totalQuestions = 0,
  });

  final String uuid;
  final String title;
  final String slug;
  final String description;
  final String thumbnail;
  final bool isFree;
  final int totalTests;
  final int totalQuestions;

  factory ExternalExam.fromJson(Map<String, dynamic> j) => ExternalExam(
        uuid: j['uuid'].toString(),
        title: (j['title'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        thumbnail: (j['thumbnail'] ?? '') as String,
        isFree: (j['is_free'] ?? false) as bool,
        totalTests: (j['total_tests'] ?? 0) as int,
        totalQuestions: (j['total_questions'] ?? 0) as int,
      );
}

class CartItemModel {
  CartItemModel({required this.id, required this.title, this.type = '', this.thumbnail = '', this.price = '0'});
  final int id;
  final String title;
  final String type;
  final String thumbnail;
  final String price;
  factory CartItemModel.fromJson(Map<String, dynamic> j) => CartItemModel(
        id: j['id'] as int,
        title: (j['title'] ?? '') as String,
        type: (j['item_type'] ?? '') as String,
        thumbnail: (j['thumbnail'] ?? '') as String,
        price: (j['unit_price'] ?? '0').toString(),
      );
}

class CartData {
  CartData({
    this.items = const [],
    this.total = '0',
    this.count = 0,
    this.couponCode = '',
    this.couponDiscount = '0',
    this.coinsUsed = 0,
    this.coinsDiscount = '0',
    this.finalAmount = '0',
  });
  final List<CartItemModel> items;
  final String total;          // gross sum
  final int count;
  final String couponCode;
  final String couponDiscount;
  final int coinsUsed;
  final String coinsDiscount;
  final String finalAmount;    // payable after coupon + coins

  factory CartData.fromJson(Map<String, dynamic> j) => CartData(
        items: ((j['items'] as List?) ?? [])
            .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (j['total'] ?? '0').toString(),
        count: (j['count'] ?? 0) as int,
        couponCode: (j['coupon_code'] ?? '') as String,
        couponDiscount: (j['coupon_discount'] ?? '0').toString(),
        coinsUsed: (j['coins_used'] ?? 0) as int,
        coinsDiscount: (j['coins_discount'] ?? '0').toString(),
        finalAmount: (j['final'] ?? j['total'] ?? '0').toString(),
      );
}

class LiveNowItem {
  LiveNowItem({
    required this.title,
    this.kind = '',
    this.uuid = '',
    this.authMode = false,
    this.isFree = false,
    this.hasAccess = false,
    this.parentKind = '',
    this.parentUuid = '',
  });
  final String title;
  final String kind; // 'test' or 'lesson' (live lesson)
  final String uuid; // destination uuid for deep-linking into the native screen
  final bool authMode; // external test → attempt with auth_mode=true
  final bool isFree;
  // Can the student open it right now (free / enrolled / holds a PASS)? If not,
  // the home screen routes to the buyable parent below instead of an attempt
  // that the backend would reject with 403.
  final bool hasAccess;
  final String parentKind; // 'test_series' | 'external_exam' | 'course'
  final String parentUuid; // that parent's uuid (for /test-series, /external-exam, /course)
  factory LiveNowItem.fromJson(Map<String, dynamic> j) => LiveNowItem(
        title: (j['title'] ?? '') as String,
        kind: (j['kind'] ?? '') as String,
        uuid: (j['uuid'] ?? '').toString(),
        authMode: (j['auth_mode'] ?? false) as bool,
        isFree: (j['is_free'] ?? false) as bool,
        hasAccess: (j['has_access'] ?? false) as bool,
        parentKind: (j['parent_kind'] ?? '').toString(),
        parentUuid: (j['parent_uuid'] ?? '').toString(),
      );
}

/// A recent completed test/exam attempt, for the personal "Recent activity" row.
class RecentActivity {
  RecentActivity({
    required this.attemptUuid,
    required this.title,
    this.score = '0',
    this.isExternal = false,
    this.date,
  });
  final String attemptUuid;
  final String title;
  final String score;
  final bool isExternal;
  final String? date;
  factory RecentActivity.fromJson(Map<String, dynamic> j) => RecentActivity(
        attemptUuid: (j['attempt_uuid'] ?? '').toString(),
        title: (j['title'] ?? '') as String,
        score: (j['score'] ?? '0').toString(),
        isExternal: (j['is_external'] ?? false) as bool,
        date: j['date'] as String?,
      );
}

class HomeData {
  HomeData({
    this.myCourses = const [],
    this.recentActivity = const [],
    this.featuredCourses = const [],
    this.featuredTestSeries = const [],
    this.featuredBundles = const [],
    this.liveNow = const [],
  });

  final List<Course> myCourses; // "Continue learning" — the student's own courses
  final List<RecentActivity> recentActivity;
  final List<Course> featuredCourses;
  final List<TestSeriesItem> featuredTestSeries;
  final List<BundleItem> featuredBundles;
  final List<LiveNowItem> liveNow;

  factory HomeData.fromJson(Map<String, dynamic> j) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    return HomeData(
      myCourses: parse('my_courses', Course.fromJson),
      recentActivity: parse('recent_activity', RecentActivity.fromJson),
      featuredCourses: parse('featured_courses', Course.fromJson),
      featuredTestSeries: parse('featured_test_series', TestSeriesItem.fromJson),
      featuredBundles: parse('featured_bundles', BundleItem.fromJson),
      liveNow: parse('live_now', LiveNowItem.fromJson),
    );
  }
}

class Comment {
  Comment({
    required this.id,
    required this.text,
    this.author = '',
    this.authorInitials = 'U',
    this.relativeTime = '',
    this.likesCount = 0,
    this.repliesCount = 0,
    this.parentId,
    this.isMine = false,
    this.fromLive = false,
  });

  final int id;
  final String text;
  final String author;
  final String authorInitials;
  final String relativeTime;
  int likesCount;
  final int repliesCount;
  final int? parentId;
  final bool isMine;
  final bool fromLive;

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: j['id'] as int,
        text: (j['text'] ?? '') as String,
        author: (j['author'] ?? 'Student') as String,
        authorInitials: (j['author_initials'] ?? 'U') as String,
        relativeTime: (j['relative_time'] ?? '') as String,
        likesCount: (j['likes_count'] ?? 0) as int,
        repliesCount: (j['replies_count'] ?? 0) as int,
        parentId: j['parent_id'] as int?,
        isMine: (j['is_mine'] ?? false) as bool,
        fromLive: (j['from_live'] ?? false) as bool,
      );
}

class Quiz {
  Quiz({
    required this.uuid,
    required this.title,
    this.description = '',
    this.time = 0,
    this.passScore = 0,
    this.questions = 0,
  });

  final String uuid;
  final String title;
  final String description;
  final int time;
  final int passScore;
  final int questions;

  factory Quiz.fromJson(Map<String, dynamic> j) => Quiz(
        uuid: j['uuid'] as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        time: (j['time'] ?? 0) as int,
        passScore: (j['pass_score'] ?? 0) as int,
        questions: (j['no_of_questions'] ?? 0) as int,
      );
}

class Invoice {
  Invoice(this.data);
  final Map<String, dynamic> data;
  String s(String k) => (data[k] ?? '').toString();
  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(j);
}

/// One line item within a grouped order.
class OrderLine {
  OrderLine({required this.title, this.itemType = '', this.pricePaid = '0'});
  final String title;
  final String itemType;
  final String pricePaid;
  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        title: (j['item_title'] ?? 'Item') as String,
        itemType: (j['item_type'] ?? '') as String,
        pricePaid: (j['price_paid'] ?? '0').toString(),
      );
}

/// A grouped order (one payment) with N line items + one combined invoice.
class Order {
  Order({
    required this.orderId,
    this.date,
    this.itemCount = 1,
    this.totalPaid = '0',
    this.items = const [],
    this.invoice,
  });

  final String orderId;
  final String? date;
  final int itemCount;
  final String totalPaid;
  final List<OrderLine> items;
  final Invoice? invoice;

  /// Headline title: the first item, "+N more" if grouped.
  String get title {
    if (items.isEmpty) return 'Order';
    if (items.length == 1) return items.first.title;
    return '${items.first.title} + ${items.length - 1} more';
  }

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        orderId: (j['order_id'] ?? '') as String,
        date: j['date']?.toString(),
        itemCount: (j['item_count'] ?? 1) as int,
        totalPaid: (j['total_paid'] ?? '0').toString(),
        items: ((j['items'] as List?) ?? [])
            .map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        invoice: j['invoice'] is Map
            ? Invoice.fromJson(Map<String, dynamic>.from(j['invoice'] as Map))
            : null,
      );
}

/// A test within a category (native test-series browsing).
class SeriesTest {
  SeriesTest({
    required this.uuid,
    required this.title,
    this.questions = 0,
    this.duration = 0,
    this.totalScore = '0',
    this.isFree = false,
    this.isAvailable = true,
    this.locked = false,
    this.availabilityStatus = 'available',
    this.availFrom,
    this.allowReattempt = true,
    this.hasCompleted = false,
    this.hasIncomplete = false,
    this.canResume = false,
    this.canStartFresh = true,
    this.canViewResult = false,
    this.completedAttemptId,
    this.incompleteAttemptId,
  });
  final String uuid;
  final String title;
  final int questions;
  final int duration; // seconds
  final String totalScore;
  final bool isFree;
  final bool isAvailable;
  final bool locked;
  final String availabilityStatus; // available | upcoming | expired | inactive
  final String? availFrom; // ISO datetime when 'upcoming' (scheduled)
  final bool allowReattempt;
  final bool hasCompleted;
  final bool hasIncomplete;
  final bool canResume;
  final bool canStartFresh;
  final bool canViewResult;
  final String? completedAttemptId;
  final String? incompleteAttemptId;

  /// Duration shown in minutes (backend stores seconds for these endpoints).
  int get durationMinutes => duration >= 60 ? (duration / 60).round() : duration;

  factory SeriesTest.fromJson(Map<String, dynamic> j) => SeriesTest(
        uuid: j['uuid'].toString(),
        title: (j['title'] ?? '') as String,
        questions: (j['no_of_questions'] ?? 0) as int,
        duration: (j['duration'] ?? 0) as int,
        totalScore: (j['total_score'] ?? '0').toString(),
        isFree: (j['is_free'] ?? false) as bool,
        isAvailable: (j['is_available'] ?? true) as bool,
        locked: (j['locked'] ?? false) as bool,
        availabilityStatus: (j['availability_status'] ?? 'available') as String,
        availFrom: j['avail_from'] as String?,
        allowReattempt: (j['allow_reattempt'] ?? true) as bool,
        hasCompleted: (j['has_completed'] ?? false) as bool,
        hasIncomplete: (j['has_incomplete'] ?? false) as bool,
        canResume: (j['can_resume'] ?? false) as bool,
        canStartFresh: (j['can_start_fresh'] ?? true) as bool,
        canViewResult: (j['can_view_result'] ?? false) as bool,
        completedAttemptId: j['completed_attempt_id'] as String?,
        incompleteAttemptId: j['incomplete_attempt_id'] as String?,
      );
}

class SeriesCategory {
  SeriesCategory({
    required this.uuid,
    required this.title,
    this.isFree = false,
    this.tests = const [],
    this.hasMore = false,
    this.totalTests = 0,
  });
  final String uuid;
  final String title;
  final bool isFree;
  final List<SeriesTest> tests;
  final bool hasMore;     // more tests beyond the first page (lazy-load)
  final int totalTests;
  factory SeriesCategory.fromJson(Map<String, dynamic> j) => SeriesCategory(
        uuid: j['uuid'].toString(),
        title: (j['title'] ?? '') as String,
        isFree: (j['is_free'] ?? false) as bool,
        tests: ((j['tests'] as List?) ?? [])
            .map((e) => SeriesTest.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasMore: (j['has_more'] ?? false) as bool,
        totalTests: (j['total_tests'] ?? 0) as int,
      );
}

class TestSeriesContents {
  TestSeriesContents({
    required this.uuid,
    required this.title,
    this.slug = '',
    this.isEnrolled = false,
    this.isFree = false,
    this.price = '0',
    this.finalPrice = '0',
    this.discountActive = false,
    this.categories = const [],
  });
  final String uuid;
  final String title;
  final String slug;
  final bool isEnrolled;
  final bool isFree;
  final String price;
  final String finalPrice;
  final bool discountActive;
  final List<SeriesCategory> categories;
  factory TestSeriesContents.fromJson(Map<String, dynamic> j) => TestSeriesContents(
        uuid: j['uuid'].toString(),
        title: (j['title'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
        isEnrolled: (j['is_enrolled'] ?? false) as bool,
        isFree: (j['is_free'] ?? false) as bool,
        price: (j['price'] ?? '0').toString(),
        finalPrice: (j['final_price'] ?? j['price'] ?? '0').toString(),
        discountActive: (j['discount_active'] ?? false) as bool,
        categories: ((j['categories'] as List?) ?? [])
            .map((e) => SeriesCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class BundleContents {
  BundleContents({
    required this.bundle,
    this.isEnrolled = false,
    this.courses = const [],
    this.testSeries = const [],
  });
  final BundleItem bundle;
  final bool isEnrolled;
  final List<Course> courses;
  final List<TestSeriesItem> testSeries;
  factory BundleContents.fromJson(Map<String, dynamic> j) => BundleContents(
        bundle: BundleItem.fromJson(Map<String, dynamic>.from(j['bundle'] as Map)),
        isEnrolled: (j['is_enrolled'] ?? false) as bool,
        courses: ((j['courses'] as List?) ?? [])
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList(),
        testSeries: ((j['test_series'] as List?) ?? [])
            .map((e) => TestSeriesItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// What the student currently owns (live access), for Profile → My learning.
class MyEnrolled {
  MyEnrolled({
    this.courses = const [],
    this.testSeries = const [],
    this.bundles = const [],
    this.hasPass = false,
    this.isPlatform = false,
  });
  final List<Course> courses;
  final List<TestSeriesItem> testSeries;
  final List<BundleItem> bundles;
  final bool hasPass;
  final bool isPlatform;

  bool get isEmpty => courses.isEmpty && testSeries.isEmpty && bundles.isEmpty && !hasPass;

  factory MyEnrolled.fromJson(Map<String, dynamic> j) => MyEnrolled(
        courses: ((j['courses'] as List?) ?? [])
            .map((e) => Course.fromJson(e as Map<String, dynamic>))
            .toList(),
        testSeries: ((j['test_series'] as List?) ?? [])
            .map((e) => TestSeriesItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        bundles: ((j['bundles'] as List?) ?? [])
            .map((e) => BundleItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasPass: (j['has_pass'] ?? false) as bool,
        isPlatform: (j['is_platform'] ?? false) as bool,
      );
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.title,
    this.text = '',
    this.type = 'announcement',
    this.isImportant = false,
    this.createdAt = '',
  });

  final int id;
  final String title;
  final String text;
  final String type;
  final bool isImportant;
  final String createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as int,
        title: (j['title'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        type: (j['notification_type'] ?? 'announcement') as String,
        isImportant: (j['is_important'] ?? false) as bool,
        createdAt: (j['created_at'] ?? '') as String,
      );
}
