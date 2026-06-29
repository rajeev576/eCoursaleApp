import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/token_store.dart';
import '../models/models.dart';

/// Auth against /api/v1/auth/token/. Identity-first: the school is returned by
/// the backend from WHO the user is, never chosen by the client.
class AuthRepository {
  AuthRepository(this._client, this._tokens);

  final ApiClient _client;
  final TokenStore _tokens;

  /// Logs in, stores the JWT pair, returns the user + school summary from the
  /// login response. Throws [AuthException] with a friendly message on failure.
  Future<LoginResult> login(String email, String password) async {
    try {
      // Use a clean Dio (auth path) — the access header isn't needed here.
      final res = await Dio(BaseOptions(baseUrl: AppConfig.apiV1)).post(
        '/auth/token/',
        data: {'email': email, 'password': password},
      );
      final data = res.data as Map<String, dynamic>;
      await _tokens.save(
        access: data['access'] as String,
        refresh: data['refresh'] as String,
      );
      return LoginResult(
        user: data['user'] != null
            ? AppUser.fromJson(data['user'] as Map<String, dynamic>)
            : null,
        schoolName: (data['school']?['name'] ?? '') as String,
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) {
        throw AuthException('Incorrect email or password.');
      }
      throw AuthException('Could not sign in. Please check your connection.');
    }
  }

  /// Exchange a Google ID token (from the native google_sign_in flow) for the
  /// app's JWT pair. The backend verifies the token with Google, then logs in
  /// (or creates) the matching student. Same result shape as password login.
  Future<LoginResult> loginWithGoogle(String idToken) async {
    try {
      final res = await Dio(BaseOptions(baseUrl: AppConfig.apiV1)).post(
        '/auth/google/',
        data: {'id_token': idToken},
      );
      final data = res.data as Map<String, dynamic>;
      await _tokens.save(access: data['access'] as String, refresh: data['refresh'] as String);
      return LoginResult(
        user: data['user'] != null ? AppUser.fromJson(data['user'] as Map<String, dynamic>) : null,
        schoolName: (data['school']?['name'] ?? '') as String,
      );
    } on DioException catch (e) {
      throw AuthException((e.response?.data is Map ? e.response?.data['detail'] : null) ??
          'Google sign-in failed. Please try again.');
    }
  }

  /// Whether phone-OTP signup is available (SMS configured). When false the app
  /// shows the direct email/password signup form.
  Future<bool> signupOtpEnabled() async {
    try {
      final res = await Dio(BaseOptions(baseUrl: AppConfig.apiV1)).get('/auth/signup/config/');
      return (res.data is Map) && (res.data['otp_enabled'] == true);
    } catch (_) {
      return false;
    }
  }

  /// Direct email/password signup (no captcha) → JWT. The "normal way" that works
  /// even before OTP is configured.
  Future<LoginResult> signupDirect({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final res = await Dio(BaseOptions(baseUrl: AppConfig.apiV1)).post(
        '/auth/signup/',
        data: {
          'first_name': firstName, 'last_name': lastName, 'email': email,
          'phone': phone, 'password': password,
        },
      );
      final data = res.data as Map<String, dynamic>;
      await _tokens.save(access: data['access'] as String, refresh: data['refresh'] as String);
      return LoginResult(
        user: data['user'] != null ? AppUser.fromJson(data['user'] as Map<String, dynamic>) : null,
        schoolName: (data['school']?['name'] ?? '') as String,
      );
    } on DioException catch (e) {
      throw AuthException((e.response?.data is Map ? e.response?.data['detail'] : null) ??
          'Could not create account. Please try again.');
    }
  }

  /// Request a signup OTP. Returns true if an OTP was sent; throws AuthException
  /// with a message on validation errors; returns false if phone signup is not
  /// enabled (caller falls back to web signup).
  Future<bool> signupRequestOtp({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final res = await Dio(BaseOptions(baseUrl: AppConfig.apiV1)).post(
        '/auth/signup/request-otp/',
        data: {
          'first_name': firstName, 'last_name': lastName, 'phone': phone,
          'email': email, 'password': password,
        },
      );
      final data = res.data as Map<String, dynamic>;
      if (data['enabled'] == false) return false; // not configured → web fallback
      return data['sent'] == true;
    } on DioException catch (e) {
      throw AuthException((e.response?.data is Map ? e.response?.data['detail'] : null) ??
          'Could not send OTP. Please try again.');
    }
  }

  /// Verify the signup OTP → creates the account, stores JWT, returns the result.
  Future<LoginResult> signupVerifyOtp(String phone, String code) async {
    try {
      final res = await Dio(BaseOptions(baseUrl: AppConfig.apiV1)).post(
        '/auth/signup/verify-otp/',
        data: {'phone': phone, 'code': code},
      );
      final data = res.data as Map<String, dynamic>;
      await _tokens.save(access: data['access'] as String, refresh: data['refresh'] as String);
      return LoginResult(
        user: data['user'] != null ? AppUser.fromJson(data['user'] as Map<String, dynamic>) : null,
        schoolName: (data['school']?['name'] ?? '') as String,
      );
    } on DioException catch (e) {
      throw AuthException((e.response?.data is Map ? e.response?.data['detail'] : null) ??
          'Invalid or expired OTP.');
    }
  }

  Future<void> logout() => _tokens.clear();

  Future<bool> get hasSession => _tokens.hasSession;

  /// Current user (validates the session). Null if unauthenticated.
  Future<AppUser?> me() async {
    try {
      final res = await _client.raw.get('/me/');
      return AppUser.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

class LoginResult {
  LoginResult({this.user, this.schoolName = ''});
  final AppUser? user;
  final String schoolName;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
