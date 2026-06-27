import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/courses/bundle_detail_screen.dart';
import '../features/courses/bundles_screen.dart';
import '../features/courses/comments_screen.dart';
import '../features/courses/course_detail_screen.dart';
import '../features/courses/quizzes_screen.dart';
import '../features/courses/video_player_screen.dart';
import '../features/forum/forum_screen.dart';
import '../features/home/home_shell.dart';
import '../features/live/live_room_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/coins_screen.dart';
import '../features/profile/orders_screen.dart';
import '../features/profile/profile_edit_screen.dart';
import '../features/tests/pass_screen.dart';
import '../features/tests/test_player_screen.dart';
import '../features/tests/test_result_screen.dart';
import '../features/tests/test_series_detail_screen.dart';
import '../features/webview/handoff_screen.dart';
import 'providers.dart';

/// Bridges the Riverpod session FutureProvider to GoRouter's refreshListenable so
/// the redirect re-runs when the cold-start session check resolves (or on
/// login/logout). Fixes "asked to log in every launch despite a saved token".
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    ref.listen(hasSessionProvider, (_, __) => notifyListeners());
  }
}

/// Shown while the saved session is being read from secure storage on launch.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// App router. Guards routes by session: unauthenticated users are sent to
/// /login; authenticated users skip it. Deep-link ready (Android App Links now,
/// iOS Universal Links later) — paths map 1:1 to screens.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    // Re-run redirect whenever the session result changes (resolves on cold start,
    // flips on login/logout). Without this, the cold-start check hasn't resolved yet
    // and the user gets bounced to /login despite a saved token.
    refreshListenable: _SessionRefresh(ref),
    redirect: (context, state) {
      final session = ref.read(hasSessionProvider);
      final loc = state.matchedLocation;

      // Session still loading (secure-storage read in flight) → stay on splash.
      if (session.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }
      final loggedIn = session.maybeWhen(data: (v) => v, orElse: () => false);
      final isPublic = loc == '/login' || loc == '/signup';

      if (!loggedIn) {
        // Logged out: allow public routes; everything else (incl. /splash) → login.
        return isPublic ? null : '/login';
      }
      // Logged in: leave splash/login for home.
      if (loc == '/splash' || loc == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
      GoRoute(
        path: '/course/:uuid',
        builder: (_, s) => CourseDetailScreen(uuid: s.pathParameters['uuid']!),
      ),
      GoRoute(
        path: '/course/:uuid/quizzes',
        builder: (_, s) => QuizzesScreen(courseUuid: s.pathParameters['uuid']!),
      ),
      GoRoute(
        path: '/orders',
        builder: (_, __) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/cart',
        builder: (_, __) => const CartScreen(),
      ),
      GoRoute(
        path: '/pass',
        builder: (_, __) => const PassScreen(),
      ),
      GoRoute(
        path: '/test/:uuid/attempt',
        builder: (_, s) => TestPlayerScreen(
          testUuid: s.pathParameters['uuid']!,
          authMode: s.uri.queryParameters['auth_mode'] == 'true',
        ),
      ),
      GoRoute(
        path: '/test-result/:uuid',
        builder: (_, s) => TestResultScreen(attemptUuid: s.pathParameters['uuid']!),
      ),
      GoRoute(
        path: '/live/:uuid',
        builder: (_, s) => LiveRoomScreen(
          lessonUuid: s.pathParameters['uuid']!,
          title: (s.extra as Map?)?['title'] as String? ?? 'Live class',
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: '/coins',
        builder: (_, __) => const CoinsScreen(),
      ),
      GoRoute(
        path: '/forum',
        builder: (_, __) => const ForumScreen(),
      ),
      GoRoute(
        path: '/forum/:uuid',
        builder: (_, s) => ForumDetailScreen(uuid: s.pathParameters['uuid']!),
      ),
      GoRoute(
        path: '/bundles',
        builder: (_, __) => const BundlesScreen(),
      ),
      GoRoute(
        path: '/test-series/:uuid',
        builder: (_, s) => TestSeriesDetailScreen(uuid: s.pathParameters['uuid']!),
      ),
      GoRoute(
        path: '/bundle/:uuid',
        builder: (_, s) => BundleDetailScreen(uuid: s.pathParameters['uuid']!),
      ),
      GoRoute(
        path: '/comments',
        builder: (_, s) {
          final m = (s.extra as Map?) ?? const {};
          return CommentsScreen(
            lessonUuid: (m['lessonUuid'] ?? '') as String,
            lessonTitle: (m['title'] ?? 'Discussion') as String,
          );
        },
      ),
      GoRoute(
        path: '/video',
        builder: (_, s) {
          final m = (s.extra as Map?) ?? const {};
          return VideoPlayerScreen(
            url: (m['url'] ?? '') as String,
            title: (m['title'] ?? 'Video') as String,
          );
        },
      ),
      GoRoute(
        path: '/handoff',
        builder: (_, s) {
          final m = (s.extra as Map?) ?? const {};
          return HandoffScreen(
            next: (m['next'] ?? '') as String,
            title: (m['title'] ?? '') as String,
            directUrl: m['url'] as String?,
          );
        },
      ),
    ],
  );
});
