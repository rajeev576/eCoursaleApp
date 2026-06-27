import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Push notifications (FCM) — registration wiring.
///
/// ⚠️ FIREBASE NOT YET WIRED IN THE BUILD. To activate (owner, when ready):
///   1. Create a Firebase project; add an Android app with applicationId
///      `com.ecoursale.ecoursale_app`; download `google-services.json` into
///      `android/app/`.
///   2. Add deps to pubspec.yaml:  firebase_core, firebase_messaging
///   3. Add the Google services Gradle plugin (firebase setup docs / `flutterfire
///      configure` does this automatically).
///   4. Uncomment the firebase code below and call `PushService(ref).init()` after
///      login (e.g. in the dashboard initState).
///   5. Backend: set FCM_SERVICE_ACCOUNT_FILE + FCM_PROJECT_ID in .env.
///
/// The registration endpoint (`POST /api/v1/device/register`) is already live, so
/// once a token is obtained it's stored server-side and notifications flow.
class PushService {
  PushService(this.ref);
  final WidgetRef ref;

  /// Obtain the FCM token and register it with the backend. Safe no-op until
  /// Firebase is wired in (see header).
  Future<void> init() async {
    // --- Uncomment after adding firebase_messaging ---
    // import 'package:firebase_messaging/firebase_messaging.dart';
    // final messaging = FirebaseMessaging.instance;
    // await messaging.requestPermission();
    // final token = await messaging.getToken();
    // if (token != null) await _register(token);
    // messaging.onTokenRefresh.listen(_register);
    // FirebaseMessaging.onMessage.listen((m) { /* in-app banner if desired */ });
  }

  Future<void> register(String token) async {
    try {
      await ref.read(apiClientProvider).raw.post('/device/register/', data: {
        'token': token,
        'platform': 'android',
      });
    } catch (_) {/* ignore; will retry on next launch */}
  }
}
