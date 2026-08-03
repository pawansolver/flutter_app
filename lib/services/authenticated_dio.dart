import 'dart:async';

import 'package:dio/dio.dart';

import '../core/api_config.dart';
import 'auth_session.dart';
import 'socket_service.dart';

class AuthenticatedDio {
  AuthenticatedDio._();

  static final AuthenticatedDio _instance = AuthenticatedDio._();
  factory AuthenticatedDio() => _instance;

  final AuthSessionStore _store = AuthSessionStore();
  late final Dio dio = _createClient();
  Future<bool>? _refreshInFlight;

  Dio _createClient() {
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _store.readAccessToken();
          if (token != null && token.trim().isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${token.trim()}';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final options = error.requestOptions;
          final isUnauthorized = error.response?.statusCode == 401;
          final alreadyRetried = options.extra['authRetried'] == true;
          final isRefresh =
              options.uri.toString() == ApiConfig.authRefreshToken;
          if (!isUnauthorized || alreadyRetried || isRefresh) {
            handler.next(error);
            return;
          }

          if (await _refreshSingleFlight()) {
            final token = await _store.readAccessToken();
            options.extra['authRetried'] = true;
            options.headers['Authorization'] = 'Bearer $token';
            try {
              handler.resolve(await client.fetch<dynamic>(options));
            } on DioException catch (retryError) {
              handler.next(retryError);
            }
            return;
          }

          await clearLocalSession();
          handler.next(error);
        },
      ),
    );
    return client;
  }

  Future<bool> _refreshSingleFlight() {
    final active = _refreshInFlight;
    if (active != null) return active;
    final future = _performRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _store.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final rawClient = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final response = await rawClient.post<Map<String, dynamic>>(
        ApiConfig.authRefreshToken,
        data: {'refreshToken': refreshToken},
      );
      final session = AuthSession.fromEnvelope(response.data ?? const {});
      await _store.save(session);
      await SocketService().reconnectWithLatestToken();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> refreshSession() => _refreshSingleFlight();

  Future<void> clearLocalSession() async {
    await _store.clearSession();
    SocketService().disconnect();
  }
}
