import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.role,
    this.name,
    this.email,
    this.mobile,
  });

  final int? id;
  final String role;
  final String? name;
  final String? email;
  final String? mobile;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: int.tryParse(json['id']?.toString() ?? ''),
    role: json['role']?.toString() ?? 'resident',
    name: json['name']?.toString(),
    email: json['email']?.toString(),
    mobile: (json['mobile'] ?? json['phone'])?.toString(),
  );
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.tokenType = 'Bearer',
    this.expiresIn,
    this.refreshExpiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final String tokenType;
  final String? expiresIn;
  final String? refreshExpiresIn;

  factory AuthSession.fromEnvelope(Map<String, dynamic> envelope) {
    if (envelope['success'] != true || envelope['data'] is! Map) {
      throw const FormatException('Invalid authentication response.');
    }
    final data = Map<String, dynamic>.from(envelope['data'] as Map);
    final accessToken = data['accessToken']?.toString() ?? '';
    final refreshToken = data['refreshToken']?.toString() ?? '';
    if (accessToken.isEmpty || refreshToken.isEmpty || data['user'] is! Map) {
      throw const FormatException('Authentication session is incomplete.');
    }
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: AuthUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
      tokenType: data['tokenType']?.toString() ?? 'Bearer',
      expiresIn: data['expiresIn']?.toString(),
      refreshExpiresIn: data['refreshExpiresIn']?.toString(),
    );
  }
}

class AuthSessionStore {
  AuthSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const accessTokenKey = 'jwt_token';
  static const refreshTokenKey = 'refresh_token';
  static const userRoleKey = 'user_role';
  static const userIdKey = 'user_id';

  final FlutterSecureStorage _storage;

  Future<void> save(AuthSession session) async {
    await Future.wait([
      _storage.write(key: accessTokenKey, value: session.accessToken),
      _storage.write(key: refreshTokenKey, value: session.refreshToken),
      _storage.write(key: userRoleKey, value: session.user.role),
      _storage.write(key: userIdKey, value: session.user.id?.toString() ?? ''),
    ]);
  }

  Future<void> saveLegacy({
    required String accessToken,
    required String role,
    required String userId,
  }) async {
    await Future.wait([
      _storage.write(key: accessTokenKey, value: accessToken),
      _storage.delete(key: refreshTokenKey),
      _storage.write(key: userRoleKey, value: role),
      _storage.write(key: userIdKey, value: userId),
    ]);
  }

  Future<String?> readAccessToken() => _storage.read(key: accessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: refreshTokenKey);

  Future<String?> readUserRole() => _storage.read(key: userRoleKey);

  Future<int?> readUserId() async {
    final value = await _storage.read(key: userIdKey);
    return int.tryParse(value ?? '');
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: accessTokenKey),
      _storage.delete(key: refreshTokenKey),
      _storage.delete(key: userRoleKey),
      _storage.delete(key: userIdKey),
    ]);
  }
}
