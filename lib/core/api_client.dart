// lib/core/api_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exceptions.dart';
import 'config.dart';

typedef TokenProvider = String? Function();
typedef RefreshHandler = Future<bool> Function();

/// Собирает Dio с базовыми настройками, интерсепторами логирования,
/// авторизации и повтора.
Dio buildDio({TokenProvider? tokenProvider, RefreshHandler? refreshHandler}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  // Основной интерсептор: лог, авторизация, обработка 4xx.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        if (kDebugMode) {
          debugPrint('[API →] ${options.method} ${options.uri}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        if (kDebugMode) {
          debugPrint('[API ←] $status ${response.requestOptions.uri}');
        }
        if (status >= 400) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) async {
        if (kDebugMode) {
          debugPrint('[API ✗] ${error.requestOptions.uri} — ${error.type}');
        }
        return handler.next(error);
      },
    ),
  );

  // Интерсептор 401 → refresh → повтор запроса.
  dio.interceptors.add(
    _RefreshInterceptor(dio: dio, refreshHandler: refreshHandler),
  );

  // Пункт 14 ПР4: retry для GET при сетевом сбое.
  dio.interceptors.add(RetryInterceptor(dio));

  return dio;
}

class _RefreshInterceptor extends Interceptor {
  final Dio dio;
  final RefreshHandler? refreshHandler;

  _RefreshInterceptor({required this.dio, this.refreshHandler});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Не трогаем сами эндпоинты аутентификации — иначе бесконечный цикл.
    final isAuthCall = path.contains('/auth/');

    if (status == 401 && !isAuthCall && refreshHandler != null) {
      final ok = await refreshHandler!.call();
      if (ok) {
        try {
          final options = err.requestOptions;
          final token = options.headers['Authorization'];
          if (kDebugMode) {
            debugPrint('[API ↻] повтор запроса с токеном: $token');
          }
          final response = await dio.fetch(options);
          return handler.resolve(response);
        } on DioException catch (e) {
          return handler.next(e);
        }
      }
    }
    return handler.next(err);
  }
}

/// Повтор операций чтения при сетевых сбоях (из ПР4).
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxAttempts;

  RetryInterceptor(this.dio, {this.maxAttempts = 3});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    final method = err.requestOptions.method;

    // /auth/* не ретраим: сессия не восстановится повтором,
    // а пользователь просто дольше ждёт. Особенно важно для /auth/me
    // на старте приложения — ретраи там только увеличивают задержку.
    final isAuthCall = path.contains('/auth/');
    final isRead = method == 'GET';
    final isNetwork =
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout;
    final attempt = (err.requestOptions.extra['retryAttempt'] as int?) ?? 0;

    if (isAuthCall || !isRead || !isNetwork || attempt >= maxAttempts) {
      return handler.next(err);
    }

    final delay = Duration(milliseconds: 300 * (1 << attempt));
    await Future.delayed(delay);

    final opts = err.requestOptions;
    opts.extra['retryAttempt'] = attempt + 1;

    try {
      final response = await dio.fetch(opts);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}
