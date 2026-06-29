import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import '../data/models/school_config.dart';
import '../data/models/test_models.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/content_repository.dart';
import 'api_client.dart';
import 'token_store.dart';

// ── Singletons ───────────────────────────────────────────────────────────────
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(tokenStoreProvider)));

final authRepoProvider = Provider<AuthRepository>((ref) =>
    AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)));

final contentRepoProvider = Provider<ContentRepository>(
    (ref) => ContentRepository(ref.watch(apiClientProvider)));

// ── Session ──────────────────────────────────────────────────────────────────
/// True once the app knows the user is logged in. Drives initial routing.
final hasSessionProvider = FutureProvider<bool>(
    (ref) => ref.watch(authRepoProvider).hasSession);

// ── Server-driven config (branding + feature flags) ──────────────────────────
/// The theme + feature flags come from here — change the backend, app re-themes.
final schoolConfigProvider = FutureProvider<SchoolConfig>(
    (ref) => ref.watch(contentRepoProvider).schoolConfig());

// Home (dashboard rails) is a top tab too — keep it cached for the session so
// returning to Home is instant. Refreshes on pull-to-refresh / explicit invalidate.
final homeProvider = FutureProvider<HomeData>(
    (ref) => ref.watch(contentRepoProvider).home());

final cartProvider = FutureProvider.autoDispose<CartData>(
    (ref) => ref.watch(contentRepoProvider).cart());

final coinsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
    (ref) => ref.watch(contentRepoProvider).coins());

final forumProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
    (ref) => ref.watch(contentRepoProvider).forumList());

final complaintsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
    (ref) => ref.watch(contentRepoProvider).complaints());

final forumDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
    (ref, uuid) => ref.watch(contentRepoProvider).forumDetail(uuid));

// ── Content lists ────────────────────────────────────────────────────────────
// NOTE: the top-level TAB lists are intentionally NOT autoDispose. They're the
// browse surfaces the student returns to constantly, so we keep them cached for
// the whole session — switching tabs (and coming back from a detail) reads the
// cache instantly instead of re-fetching + flashing a loader every time. Data
// refreshes only on pull-to-refresh (onRefresh → ref.invalidate) or after an
// action that explicitly invalidates them (enroll/buy). The DETAIL/CONTENTS
// family providers below stay autoDispose so per-uuid caches don't pile up.
final coursesProvider = FutureProvider<List<Course>>(
    (ref) => ref.watch(contentRepoProvider).courses());

final testSeriesProvider = FutureProvider<List<TestSeriesItem>>(
    (ref) => ref.watch(contentRepoProvider).testSeries());

final bundlesProvider = FutureProvider<List<BundleItem>>(
    (ref) => ref.watch(contentRepoProvider).bundles());

// External exams use an infinite-scroll controller instead of a one-shot
// FutureProvider — see features/tests/external_exams_controller.dart.

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>(
        (ref) => ref.watch(contentRepoProvider).notifications());

final courseLessonsProvider =
    FutureProvider.autoDispose.family<CourseLessons, String>(
        (ref, uuid) => ref.watch(contentRepoProvider).courseLessons(uuid));

final courseQuizzesProvider =
    FutureProvider.autoDispose.family<CourseQuizzes, String>(
        (ref, uuid) => ref.watch(contentRepoProvider).courseQuizzes(uuid));

final courseDetailProvider =
    FutureProvider.autoDispose.family<Course, String>(
        (ref, uuid) => ref.watch(contentRepoProvider).course(uuid));

final bundleContentsProvider =
    FutureProvider.autoDispose.family<BundleContents, String>(
        (ref, uuid) => ref.watch(contentRepoProvider).bundleContents(uuid));

final testSeriesContentsProvider =
    FutureProvider.autoDispose.family<TestSeriesContents, String>(
        (ref, uuid) => ref.watch(contentRepoProvider).testSeriesContents(uuid));

// External exams reuse the TestSeriesContents shape (sections→categories).
final externalExamContentsProvider =
    FutureProvider.autoDispose.family<TestSeriesContents, String>(
        (ref, uuid) => ref.watch(contentRepoProvider).externalExamContents(uuid));

final ordersProvider = FutureProvider.autoDispose<List<Order>>(
    (ref) => ref.watch(contentRepoProvider).orders());

final myEnrolledProvider = FutureProvider.autoDispose<MyEnrolled>(
    (ref) => ref.watch(contentRepoProvider).myEnrolled());

final testSolutionProvider = FutureProvider.autoDispose.family<TestSolution, String>(
    (ref, attemptUuid) => ref.watch(contentRepoProvider).testSolution(attemptUuid));

final testLeaderboardProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, attemptUuid) => ref.watch(contentRepoProvider).testLeaderboard(attemptUuid));

final testAttemptsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, attemptUuid) => ref.watch(contentRepoProvider).testAttempts(attemptUuid));

final lessonCommentsProvider =
    FutureProvider.autoDispose.family<List<Comment>, String>(
        (ref, lessonUuid) => ref.watch(contentRepoProvider).lessonComments(lessonUuid));
