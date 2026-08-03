import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_config.dart';

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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String _handleDioError(DioException de, String fallback) {
    if (de.type == DioExceptionType.connectionTimeout ||
        de.type == DioExceptionType.receiveTimeout ||
        de.type == DioExceptionType.sendTimeout) {
      return 'Server is starting up, please try again in a moment.';
    }
    if (de.type == DioExceptionType.connectionError) {
      return 'No internet connection or server is unreachable. Please check your network.';
    }
    return de.response?.data?['message'] as String? ?? fallback;
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
      throw Exception(_handleDioError(de, 'Failed to connect to authentication server.'));
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
        await _secureStorage.write(key: 'jwt_token', value: token);
        await _secureStorage.write(key: 'user_role', value: role);
        await _secureStorage.write(key: 'user_id', value: userId);

        return {"token": token, "role": role, "userId": userId};
      }
      return null;
    } on DioException catch (de) {
      throw Exception(_handleDioError(de, 'Verification failed due to data mismatch.'));
    } catch (e) {
      throw Exception('Authentication logic failure.');
    }
  }

  // Helper: dynamically access JWT for authenticated API headers
  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  // Helper: get saved user ID (needed for chat API calls)
  Future<int?> getUserId() async {
    final val = await _secureStorage.read(key: 'user_id');
    if (val == null || val.isEmpty) return null;
    return int.tryParse(val);
  }

  /// Clears every locally persisted authentication value.
  Future<void> logout() async {
    await _secureStorage.deleteAll();
  }
}
