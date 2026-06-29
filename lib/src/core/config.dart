import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App configuration.
///
/// Resolution order (so the SAME codebase serves dev today and per-school
/// white-label flavors later, Phase E):
///   1. compile-time `--dart-define` (what the per-school flavor build injects),
///   2. the bundled `.env` (local dev),
///   3. a hard-coded default.
/// This means the eventual flavor pipeline only has to pass
/// `--dart-define=API_BASE=... --dart-define=SCHOOL_CODE=... --dart-define=APP_NAME=...`
/// (plus the gradle flavor for applicationId/icon/launcher-name) — no code change.
class AppConfig {
  // const-evaluated at build time; empty string when not provided.
  static const String _defApiBase = String.fromEnvironment('API_BASE');
  static const String _defSchoolCode = String.fromEnvironment('SCHOOL_CODE');
  static const String _defAppName = String.fromEnvironment('APP_NAME');
  static const String _defGoogleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  static String get apiBase => _defApiBase.isNotEmpty
      ? _defApiBase
      : (dotenv.maybeGet('API_BASE') ?? 'https://dev-mse.ecoursale.com');

  static String get schoolCode => _defSchoolCode.isNotEmpty
      ? _defSchoolCode
      : (dotenv.maybeGet('SCHOOL_CODE') ?? '');

  static String get appName => _defAppName.isNotEmpty
      ? _defAppName
      : (dotenv.maybeGet('APP_NAME') ?? 'Ecoursale');

  /// The WEB OAuth client id used as `serverClientId` for native Google sign-in,
  /// so the Google ID token's `aud` matches the backend's GOOGLE_OAUTH_CLIENT_ID.
  /// Empty → the "Continue with Google" button is hidden (not configured yet).
  static String get googleServerClientId => _defGoogleServerClientId.isNotEmpty
      ? _defGoogleServerClientId
      : (dotenv.maybeGet('GOOGLE_SERVER_CLIENT_ID') ?? '');

  /// Versioned API root. A published app pins this; v2 ships without breaking v1.
  static String get apiV1 => '$apiBase/api/v1';
}
