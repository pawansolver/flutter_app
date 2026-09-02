import 'package:dio/dio.dart';

import '../core/api_config.dart';
import 'auth_session.dart';
import 'authenticated_dio.dart';
import 'notification_service.dart';
import 'socket_service.dart';

class AuthService {
  // 120-second timeout handles Render free tier cold starts
  // (server sleeps after 15 min inactivity → takes up to 2 mins to wake up)
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 120),
    ),
  );
  final AuthSessionStore _sessionStore = AuthSessionStore();

  String _handleDioError(DioException de, String fallback) {
    if (de.type == DioExceptionType.connectionTimeout ||
        de.type == DioExceptionType.receiveTimeout ||
        de.type == DioExceptionType.sendTimeout) {
      return 'Server is starting up, please try again in a moment.';
    }
    if (de.type == DioExceptionType.connectionError) {
      return 'No internet connection or server is unreachable. Please check your network.';
    }
    final body = de.response?.data;
    if (body is Map && body['message'] != null) {
      return body['message'].toString();
    }
    return fallback;
  }

  Never _throwDio(DioException error, String fallback) {
    throw Exception(_handleDioError(error, fallback));
  }

  Map<String, dynamic> _data(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map || body['success'] != true) {
      throw const FormatException('Invalid server response.');
    }
    final data = body['data'];
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> signup({
    required String name,
    required String mobile,
    required String email,
  }) async {
    try {
      await _dio.post(
        ApiConfig.authSignup,
        data: {'name': name, 'mobile': mobile, 'email': email},
      );
    } on DioException catch (error) {
      _throwDio(error, 'Could not start signup.');
    }
  }

  Future<String> verifySignupOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.authVerifyEmailOtp,
        data: {'email': email, 'otp': otp},
      );
      return _data(response)['signupSessionToken']?.toString() ?? '';
    } on DioException catch (error) {
      _throwDio(error, 'Verification failed.');
    }
  }

  Future<void> createPassword({
    required String signupSessionToken,
    required String password,
  }) async {
    try {
      await _dio.post(
        ApiConfig.authCreatePassword,
        data: {'signupSessionToken': signupSessionToken, 'password': password},
      );
      // Product flow requires a fresh explicit sign-in, even though the
      // backend currently returns a token pair from account creation.
      await AuthenticatedDio().clearLocalSession();
    } on DioException catch (error) {
      _throwDio(error, 'Could not create account.');
    }
  }

  Future<AuthSession> signin({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConfig.authSignin,
        data: {'identifier': identifier, 'password': password},
      );
      final session = AuthSession.fromEnvelope(response.data ?? const {});
      await _sessionStore.save(session);
      await NotificationService().registerDevice();
      return session;
    } on DioException catch (error) {
      _throwDio(error, 'Sign in failed.');
    }
  }

  Future<void> forgotPassword(String identifier) async {
    try {
      await _dio.post(
        ApiConfig.authForgotPassword,
        data: {'identifier': identifier},
      );
    } on DioException catch (error) {
      _throwDio(error, 'Could not send a verification code.');
    }
  }

  Future<String> verifyResetOtp({
    required String identifier,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.authVerifyResetOtp,
        data: {'identifier': identifier, 'otp': otp},
      );
      return _data(response)['resetToken']?.toString() ?? '';
    } on DioException catch (error) {
      _throwDio(error, 'Verification failed.');
    }
  }

  Future<void> resetPassword({
    required String resetToken,
    required String password,
  }) async {
    try {
      await _dio.post(
        ApiConfig.authResetPassword,
        data: {'resetToken': resetToken, 'password': password},
      );
      await AuthenticatedDio().clearLocalSession();
    } on DioException catch (error) {
      _throwDio(error, 'Could not reset password.');
    }
  }

  Future<Map<String, dynamic>> getAuthProfile() async {
    final response = await AuthenticatedDio().dio.get(ApiConfig.authProfile);
    return _data(response);
  }

  Future<bool> bootstrapSession() async {
    final accessToken = await _sessionStore.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return AuthenticatedDio().refreshSession();
    }
    try {
      await getAuthProfile();
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      return AuthenticatedDio().refreshSession();
    }
  }

  // 1. Dispatch OTP Request — accepts phone number AND email
  Future<bool> sendOtp({
    required String phoneNumber,
    required String email,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.sendOtp,
        data: {"phoneNumber": phoneNumber, "email": email},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } on DioException catch (de) {
      throw Exception(
        _handleDioError(de, 'Failed to connect to authentication server.'),
      );
    } catch (e) {
      throw Exception('An unexpected connection error occurred.');
    }
  }

  // 1.5 Resend OTP Request — Enterprise level endpoint
  Future<bool> resendOtp({required String email}) async {
    try {
      final response = await _dio.post(
        ApiConfig.resendOtp,
        data: {"email": email},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } on DioException catch (de) {
      throw Exception(_handleDioError(de, 'Failed to resend OTP.'));
    } catch (e) {
      throw Exception('An unexpected connection error occurred.');
    }
  }

  // 2. Validate OTP & Write Encrypted JWT Tokens
  Future<Map<String, dynamic>?> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _dio.post(
        ApiConfig.verifyOtp,
        data: {"email": email, "otp": otp},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final token = response.data['data']['accessToken'];
        final user = response.data['data']['user'];
        final role = user['role'];
        final userId = user['id']?.toString() ?? '';

        // High security: writes directly to Android Keystore / iOS Keychain
        await _sessionStore.saveLegacy(
          accessToken: token,
          role: role,
          userId: userId,
        );

        await NotificationService().registerDevice();

        return {"token": token, "role": role, "userId": userId};
      }
      return null;
    } on DioException catch (de) {
      throw Exception(
        _handleDioError(de, 'Verification failed due to data mismatch.'),
      );
    } catch (e) {
      throw Exception('Authentication logic failure.');
    }
  }

  // Helper: dynamically access JWT for authenticated API headers
  Future<String?> getToken() async {
    return _sessionStore.readAccessToken();
  }

  // Helper: get saved user ID (needed for chat API calls)
  Future<int?> getUserId() async {
    return _sessionStore.readUserId();
  }

  Future<String?> getUserRole() async {
    return _sessionStore.readUserRole();
  }

  Future<bool> isGlobalAdmin() async {
    final role = await getUserRole();
    if (role == null) return false;
    final normalized = role.toLowerCase().trim();
    return normalized == 'admin' || normalized == 'super_admin' || normalized == 'superadmin';
  }

  /// Clears every locally persisted authentication value.
  Future<void> logout() async {
    final refreshToken = await _sessionStore.readRefreshToken();
    try {
      await NotificationService().deactivateDevice();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _dio.post(
          ApiConfig.authLogout,
          data: {'refreshToken': refreshToken},
        );
      }
    } finally {
      await _sessionStore.clearSession();
      SocketService().disconnect();
    }
  }
}
