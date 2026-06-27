/// Data models mirroring the /api/v1 student endpoints. Kept lean to match the
/// serializers in api/v1/serializers.py on the backend.

class AppUser {
  AppUser({required this.id, required this.email, required this.fullName, required this.userType});
  final int id;
  final String email;
  final String fullName;
  final String userType;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        email: (j['email'] ?? '') as String,
        fullName: (j['full_name'] ?? '') as String,
        userType: (j['user_type'] ?? '') as String,
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
  final String price;
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
  });

  final String uuid;
  final String title;
  final String type;
  final bool isContent;
  final String richText;
  final String fileUrl;

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        uuid: j['uuid'].toString(),
        title: (j['title'] ?? '') as String,
        type: (j['attachment_type'] ?? 'other') as String,
        isContent: (j['is_content'] ?? false) as bool,
        richText: (j['rich_text_content'] ?? '') as String,
        fileUrl: (j['file_url'] ?? '') as String,
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
  final String price;
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
    this.savings = '0',
  });

  final String uuid;
  final String title;
  final String? slug;
  final String description;
  final String thumbnail;
  final bool isFree;
  final bool isEnrolled;
  final String price;
  final String savings;

  factory BundleItem.fromJson(Map<String, dynamic> j) => BundleItem(
        uuid: j['uuid'] as String,
        title: (j['title'] ?? '') as String,
        slug: j['slug']?.toString(),
        description: (j['description'] ?? '') as String,
        thumbnail: (j['thumbnail'] ?? '') as String,
        isFree: (j['is_free'] ?? false) as bool,
        isEnrolled: (j['is_enrolled'] ?? false) as bool,
        price: (j['price'] ?? '0').toString(),
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
  CartData({this.items = const [], this.total = '0', this.count = 0});
  final List<CartItemModel> items;
  final String total;
  final int count;
  factory CartData.fromJson(Map<String, dynamic> j) => CartData(
        items: ((j['items'] as List?) ?? [])
            .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (j['total'] ?? '0').toString(),
        count: (j['count'] ?? 0) as int,
      );
}

class LiveNowItem {
  LiveNowItem({required this.title, this.kind = '', this.isFree = false});
  final String title;
  final String kind;
  final bool isFree;
  factory LiveNowItem.fromJson(Map<String, dynamic> j) => LiveNowItem(
        title: (j['title'] ?? '') as String,
        kind: (j['kind'] ?? '') as String,
        isFree: (j['is_free'] ?? false) as bool,
      );
}

class HomeData {
  HomeData({
    this.featuredCourses = const [],
    this.featuredTestSeries = const [],
    this.featuredBundles = const [],
    this.liveNow = const [],
  });

  final List<Course> featuredCourses;
  final List<TestSeriesItem> featuredTestSeries;
  final List<BundleItem> featuredBundles;
  final List<LiveNowItem> liveNow;

  factory HomeData.fromJson(Map<String, dynamic> j) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) f) =>
        ((j[key] as List?) ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    return HomeData(
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

class Order {
  Order({
    required this.uuid,
    required this.itemTitle,
    this.itemType = 'other',
    this.status = '',
    this.paymentStatus = false,
    this.pricePaid,
    this.paymentDate,
    this.enrollmentDate,
    this.validTill,
    this.invoice,
    this.payUrl = '',
  });

  final String uuid;
  final String itemTitle;
  final String itemType;
  final String status;
  final bool paymentStatus;
  final String? pricePaid;
  final String? paymentDate;
  final String? enrollmentDate;
  final String? validTill;
  final Invoice? invoice;
  final String payUrl;

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        uuid: j['uuid'] as String,
        itemTitle: (j['item_title'] ?? 'Purchase') as String,
        itemType: (j['item_type'] ?? 'other') as String,
        status: (j['status'] ?? '') as String,
        paymentStatus: (j['payment_status'] ?? false) as bool,
        pricePaid: j['price_paid']?.toString(),
        paymentDate: j['payment_date']?.toString(),
        enrollmentDate: j['enrollment_date']?.toString(),
        validTill: j['valid_till']?.toString(),
        invoice: j['invoice'] is Map
            ? Invoice.fromJson(Map<String, dynamic>.from(j['invoice'] as Map))
            : null,
        payUrl: (j['pay_url'] ?? '') as String,
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
  });
  final String uuid;
  final String title;
  final int questions;
  final int duration;
  final String totalScore;
  final bool isFree;
  final bool isAvailable;
  final bool locked;
  factory SeriesTest.fromJson(Map<String, dynamic> j) => SeriesTest(
        uuid: j['uuid'].toString(),
        title: (j['title'] ?? '') as String,
        questions: (j['no_of_questions'] ?? 0) as int,
        duration: (j['duration'] ?? 0) as int,
        totalScore: (j['total_score'] ?? '0').toString(),
        isFree: (j['is_free'] ?? false) as bool,
        isAvailable: (j['is_available'] ?? true) as bool,
        locked: (j['locked'] ?? false) as bool,
      );
}

class SeriesCategory {
  SeriesCategory({required this.uuid, required this.title, this.isFree = false, this.tests = const []});
  final String uuid;
  final String title;
  final bool isFree;
  final List<SeriesTest> tests;
  factory SeriesCategory.fromJson(Map<String, dynamic> j) => SeriesCategory(
        uuid: j['uuid'].toString(),
        title: (j['title'] ?? '') as String,
        isFree: (j['is_free'] ?? false) as bool,
        tests: ((j['tests'] as List?) ?? [])
            .map((e) => SeriesTest.fromJson(e as Map<String, dynamic>))
            .toList(),
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
    this.categories = const [],
  });
  final String uuid;
  final String title;
  final String slug;
  final bool isEnrolled;
  final bool isFree;
  final String price;
  final List<SeriesCategory> categories;
  factory TestSeriesContents.fromJson(Map<String, dynamic> j) => TestSeriesContents(
        uuid: j['uuid'].toString(),
        title: (j['title'] ?? '') as String,
        slug: (j['slug'] ?? '') as String,
        isEnrolled: (j['is_enrolled'] ?? false) as bool,
        isFree: (j['is_free'] ?? false) as bool,
        price: (j['price'] ?? '0').toString(),
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
