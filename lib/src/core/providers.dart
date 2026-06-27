import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import '../data/models/school_config.dart';
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

final homeProvider = FutureProvider.autoDispose<HomeData>(
    (ref) => ref.watch(contentRepoProvider).home());

final cartProvider = FutureProvider.autoDispose<CartData>(
    (ref) => ref.watch(contentRepoProvider).cart());

// ── Content lists ────────────────────────────────────────────────────────────
final coursesProvider = FutureProvider.autoDispose<List<Course>>(
    (ref) => ref.watch(contentRepoProvider).courses());

final testSeriesProvider = FutureProvider.autoDispose<List<TestSeriesItem>>(
    (ref) => ref.watch(contentRepoProvider).testSeries());

final bundlesProvider = FutureProvider.autoDispose<List<BundleItem>>(
    (ref) => ref.watch(contentRepoProvider).bundles());

final externalExamsProvider = FutureProvider.autoDispose<List<ExternalExam>>(
    (ref) => ref.watch(contentRepoProvider).externalExams());

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

final ordersProvider = FutureProvider.autoDispose<List<Order>>(
    (ref) => ref.watch(contentRepoProvider).orders());

final lessonCommentsProvider =
    FutureProvider.autoDispose.family<List<Comment>, String>(
        (ref, lessonUuid) => ref.watch(contentRepoProvider).lessonComments(lessonUuid));
