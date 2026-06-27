import 'dart:async';

import 'package:dio/dio.dart';

import 'config.dart';
import 'token_store.dart';

/// Thrown when the session is gone (refresh failed) — the UI routes to login.
class SessionExpired implements Exception {}

/// Single Dio instance for the whole app.
///
/// Interceptor responsibilities:
///  - attach `Authorization: Bearer <access>` to every request,
///  - on a 401, transparently refresh the access token using the stored refresh
///    token (ONCE, serialized so concurrent 401s don't stampede the refresh
///    endpoint), then replay the original request,
///  - if refresh fails, clear the session and surface [SessionExpired].
///
/// This is what lets a student stay logged in for weeks without re-entering a
/// password (long refresh token), while access tokens stay short-lived.
class ApiClient {
  ApiClient(this._tokens) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiV1,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  late final Dio _dio;
  final TokenStore _tokens;

  // Ensures only one refresh runs at a time.
  Future<bool>? _refreshing;

  Dio get raw => _dio;

  Future<void> _onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Don't attach a (stale) token to the auth endpoints themselves.
    final isAuthPath = options.path.startsWith('/auth/');
    if (!isAuthPath) {
      final access = await _tokens.accessToken;
      if (access != null) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final alreadyRetried = err.requestOptions.extra['__retried'] == true;

    if (status == 401 && !path.startsWith('/auth/') && !alreadyRetried) {
      final ok = await _refreshOnce();
      if (ok) {
        try {
          final access = await _tokens.accessToken;
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $access';
          opts.extra['__retried'] = true;
          final response = await _dio.fetch(opts);
          return handler.resolve(response);
        } catch (_) {
          // fall through to reject
        }
      } else {
        await _tokens.clear();
        return handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: SessionExpired(),
        ));
      }
    }
    handler.next(err);
  }

  /// Refresh the access token (serialized). Returns true on success.
  Future<bool> _refreshOnce() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null) return false;
    try {
      // Fresh Dio (no interceptor) to avoid recursion.
      final res = await Dio(BaseOptions(baseUrl: AppConfig.apiV1)).post(
        '/auth/token/refresh/',
        data: {'refresh': refresh},
      );
      final newAccess = res.data['access'] as String?;
      final newRefresh = res.data['refresh'] as String?; // present when rotation on
      if (newAccess == null) return false;
      if (newRefresh != null) {
        await _tokens.save(access: newAccess, refresh: newRefresh);
      } else {
        await _tokens.saveAccess(newAccess);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
