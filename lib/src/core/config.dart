import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App configuration, loaded from the bundled `.env` at startup.
///
/// For the white-label native build (Phase E) these values are injected per
/// school via the Flutter flavor; for now they come from `.env`.
class AppConfig {
  static String get apiBase =>
      dotenv.maybeGet('API_BASE') ?? 'https://dev-mse.ecoursale.com';

  static String get schoolCode => dotenv.maybeGet('SCHOOL_CODE') ?? '';

  static String get appName => dotenv.maybeGet('APP_NAME') ?? 'Ecoursale';

  /// Versioned API root. A published app pins this; v2 ships without breaking v1.
  static String get apiV1 => '$apiBase/api/v1';
}
