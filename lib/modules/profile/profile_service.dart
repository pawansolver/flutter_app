import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_config.dart';
import '../../services/authenticated_dio.dart';

/// Generic result wrapper — separates success payload from error message.
class ProfileResult<T> {
  final T? data;
  final String? error;
  bool get isSuccess => error == null;

  const ProfileResult.success(this.data) : error = null;
  const ProfileResult.failure(this.error) : data = null;
}

/// Domain model for the authenticated user's profile aggregate.
class UserProfileModel {
  final int id;
  final String fullName;
  final String? email;
  final String? phone;
  final String role;
  final bool isActive;
  final bool isVerified;
  final bool hasPassword;
  final String? avatarUrl;
  final String? bio;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final bool isProfileComplete;

  const UserProfileModel({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    required this.isActive,
    required this.isVerified,
    required this.hasPassword,
    this.avatarUrl,
    this.bio,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.isProfileComplete,
  });

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      fullName: (json['fullName'] ?? 'smartgali User').toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      role: (json['role'] ?? 'resident').toString(),
      isActive: json['isActive'] == true,
      isVerified: json['isVerified'] == true,
      hasPassword: json['hasPassword'] == true,
      avatarUrl: ApiConfig.normalizeMediaUrl(json['avatarUrl']?.toString()),
      bio: json['bio']?.toString(),
      locationName: json['locationName']?.toString(),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      isProfileComplete: json['isProfileComplete'] == true,
    );
  }

  String get roleLabel {
    switch (role) {
      case 'shopkeeper':
        return 'Shopkeeper Profile';
      case 'provider':
        return 'Service Provider Profile';
      default:
        return 'Resident Profile';
    }
  }
}

/// Saved address model.
class AddressModel {
  final int id;
  final String label;
  final String? houseNo;
  final String? street;
  final String? landmark;
  final String? city;
  final String? fullAddress;
  final bool isDefault;

  const AddressModel({
    required this.id,
    required this.label,
    this.houseNo,
    this.street,
    this.landmark,
    this.city,
    this.fullAddress,
    required this.isDefault,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      label: (json['label'] ?? 'Home').toString(),
      houseNo: json['houseNo']?.toString(),
      street: json['street']?.toString(),
      landmark: json['landmark']?.toString(),
      city: json['city']?.toString(),
      fullAddress: json['fullAddress']?.toString(),
      isDefault: json['isDefault'] == true,
    );
  }
}

class SocietyModel {
  final int id;
  final String name;
  final String? address;
  final bool isVerified;

  const SocietyModel({
    required this.id,
    required this.name,
    this.address,
    required this.isVerified,
  });

  factory SocietyModel.fromJson(Map<String, dynamic> json) {
    return SocietyModel(
      id: int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: (json['name'] ?? json['societyName'] ?? 'Linked society')
          .toString(),
      address: (json['address'] ?? json['location'])?.toString(),
      isVerified: json['isVerified'] == true || json['verified'] == true,
    );
  }
}

abstract interface class AccountSecurityService {
  Future<ProfileResult<UserProfileModel>> getMe();

  Future<ProfileResult<bool>> changePassword({
    String? currentPassword,
    required String newPassword,
  });
}

/// Enterprise service — all profile-related API calls in ONE place (singleton).
class ProfileService implements AccountSecurityService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final Dio _dio = AuthenticatedDio().dio;
  final _storage = const FlutterSecureStorage();

  Future<Options> _authOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(
      headers: token == null || token.trim().isEmpty
          ? const <String, String>{}
          : {'Authorization': 'Bearer $token'},
    );
  }

  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? fallback;
  }

  // ── Profile aggregate ──────────────────────────────────────
  @override
  Future<ProfileResult<UserProfileModel>> getMe() async {
    try {
      final resp = await _dio.get(
        ApiConfig.authProfile,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return ProfileResult.success(
          UserProfileModel.fromJson(
            Map<String, dynamic>.from(resp.data['data']),
          ),
        );
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to load profile',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  Future<ProfileResult<UserProfileModel>> updateProfile({
    String? fullName,
    String? email,
    String? bio,
    String? avatarUrl,
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['fullName'] = fullName;
      if (email != null) body['email'] = email;
      if (bio != null) body['bio'] = bio;
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
      if (locationName != null) body['locationName'] = locationName;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;

      final resp = await _dio.put(
        ApiConfig.authProfile,
        data: body,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return ProfileResult.success(
          UserProfileModel.fromJson(
            Map<String, dynamic>.from(resp.data['data']),
          ),
        );
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to update profile',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  Future<ProfileResult<String>> uploadAvatar(
    Object image, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final MultipartFile avatar;
      if (image is XFile) {
        avatar = kIsWeb
            ? MultipartFile.fromBytes(
                await image.readAsBytes(),
                filename: image.name,
              )
            : await MultipartFile.fromFile(image.path, filename: image.name);
      } else if (image is String && image.trim().isNotEmpty) {
        avatar = await MultipartFile.fromFile(
          image,
          filename: image.split(RegExp(r'[/\\]')).last,
        );
      } else {
        return const ProfileResult.failure(
          'Avatar must be provided as an image path or XFile.',
        );
      }

      final response = await _dio.post(
        ApiConfig.avatar,
        data: FormData.fromMap({'avatar': avatar}),
        options: await _authOptions(),
        onSendProgress: onSendProgress,
      );
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          response.data is Map &&
          response.data['success'] == true) {
        final data = response.data['data'];
        String? avatarUrl;
        if (data is Map) {
          avatarUrl = data['avatarUrl']?.toString();
          final profile = data['profile'];
          if (avatarUrl == null && profile is Map) {
            avatarUrl = profile['avatarUrl']?.toString();
          }
        } else if (data is String) {
          avatarUrl = data;
        }

        final normalizedUrl = ApiConfig.normalizeMediaUrl(avatarUrl);
        if (normalizedUrl != null) {
          return ProfileResult.success(normalizedUrl);
        }

        final refreshedProfile = await getMe();
        if (refreshedProfile.isSuccess &&
            refreshedProfile.data?.avatarUrl != null) {
          return ProfileResult.success(refreshedProfile.data!.avatarUrl!);
        }
        return const ProfileResult.failure(
          'Avatar uploaded, but the server did not return its URL.',
        );
      }
      final message = response.data is Map
          ? response.data['message']?.toString()
          : null;
      return ProfileResult.failure(message ?? 'Failed to upload avatar');
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Avatar upload failed'));
    } catch (_) {
      return const ProfileResult.failure('Could not read the selected image');
    }
  }

  // ── Addresses ──────────────────────────────────────────────
  Future<ProfileResult<List<AddressModel>>> getAddresses() async {
    try {
      final resp = await _dio.get(
        ApiConfig.addresses,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        final list = (resp.data['data'] as List?) ?? [];
        return ProfileResult.success(
          list
              .map((e) => AddressModel.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to load addresses',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  Future<ProfileResult<AddressModel>> addAddress({
    required String label,
    String? houseNo,
    String? street,
    String? landmark,
    String? city,
  }) async {
    try {
      final resp = await _dio.post(
        ApiConfig.addresses,
        data: {
          'label': label,
          'houseNo': ?houseNo,
          'street': ?street,
          'landmark': ?landmark,
          'city': ?city,
        },
        options: await _authOptions(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) &&
          resp.data['success'] == true) {
        return ProfileResult.success(
          AddressModel.fromJson(Map<String, dynamic>.from(resp.data['data'])),
        );
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to add address',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  Future<ProfileResult<AddressModel>> updateAddress({
    required int id,
    required String label,
    String? houseNo,
    String? street,
    String? landmark,
    String? city,
  }) async {
    try {
      final resp = await _dio.put(
        ApiConfig.address(id),
        data: {
          'label': label,
          'houseNo': ?houseNo,
          'street': ?street,
          'landmark': ?landmark,
          'city': ?city,
        },
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return ProfileResult.success(
          AddressModel.fromJson(Map<String, dynamic>.from(resp.data['data'])),
        );
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to update address',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  Future<ProfileResult<bool>> setDefaultAddress(int id) async {
    try {
      final resp = await _dio.patch(
        ApiConfig.defaultAddress(id),
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const ProfileResult.success(true);
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to set default address',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  Future<ProfileResult<bool>> deleteAddress(int id) async {
    try {
      final resp = await _dio.delete(
        ApiConfig.address(id),
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const ProfileResult.success(true);
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to delete address',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  Future<ProfileResult<SocietyModel?>> getSociety() async {
    try {
      final resp = await _dio.get(
        ApiConfig.society,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        final data = resp.data['data'];
        if (data == null) return const ProfileResult.success(null);
        return ProfileResult.success(
          SocietyModel.fromJson(Map<String, dynamic>.from(data)),
        );
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to load society',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  Future<ProfileResult<bool>> createSupportTicket({
    required String category,
    required String description,
  }) async {
    try {
      final resp = await _dio.post(
        ApiConfig.supportTickets,
        data: {'category': category, 'description': description},
        options: await _authOptions(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) &&
          resp.data['success'] == true) {
        return const ProfileResult.success(true);
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to submit support ticket',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  Future<ProfileResult<bool>> requestDataExport() async {
    try {
      final resp = await _dio.post(
        ApiConfig.dataExportRequests,
        options: await _authOptions(),
      );
      if ((resp.statusCode == 200 || resp.statusCode == 201) &&
          resp.data['success'] == true) {
        return const ProfileResult.success(true);
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to request data export',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  // ── Notification preferences ───────────────────────────────
  Future<ProfileResult<Map<String, dynamic>>>
  getNotificationPreferences() async {
    try {
      final resp = await _dio.get(
        ApiConfig.notificationPreferences,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return ProfileResult.success(
          Map<String, dynamic>.from(resp.data['data']),
        );
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to load preferences',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  Future<ProfileResult<Map<String, dynamic>>> updateNotificationPreferences(
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await _dio.put(
        ApiConfig.notificationPreferences,
        data: body,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return ProfileResult.success(
          Map<String, dynamic>.from(resp.data['data']),
        );
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to save preferences',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  // ── Privacy settings ───────────────────────────────────────
  Future<ProfileResult<Map<String, dynamic>>> getPrivacySettings() async {
    try {
      final resp = await _dio.get(
        ApiConfig.privacySettings,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return ProfileResult.success(
          Map<String, dynamic>.from(resp.data['data']),
        );
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to load privacy settings',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  Future<ProfileResult<Map<String, dynamic>>> updatePrivacySettings({
    String? profileVisibility,
    bool? showActivityStatus,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (profileVisibility != null) {
        body['profileVisibility'] = profileVisibility;
      }
      if (showActivityStatus != null) {
        body['showActivityStatus'] = showActivityStatus;
      }

      final resp = await _dio.put(
        ApiConfig.privacySettings,
        data: body,
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return ProfileResult.success(
          Map<String, dynamic>.from(resp.data['data']),
        );
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to save privacy settings',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  // ── Change password ────────────────────────────────────────
  @override
  Future<ProfileResult<bool>> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {
    try {
      final resp = await _dio.put(
        ApiConfig.changePassword,
        data: {
          if (currentPassword != null && currentPassword.isNotEmpty)
            'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        return const ProfileResult.success(true);
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to update password',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }

  // ── Delete account ─────────────────────────────────────────
  Future<ProfileResult<bool>> deleteAccount({
    String? password,
    String? reason,
  }) async {
    try {
      final resp = await _dio.delete(
        ApiConfig.authAccount,
        data: {
          'confirm': true,
          if (password != null && password.isNotEmpty) 'password': password,
          'reason': ?reason,
        },
        options: await _authOptions(),
      );
      if (resp.statusCode == 200 && resp.data['success'] == true) {
        await AuthenticatedDio().clearLocalSession();
        return const ProfileResult.success(true);
      }
      return ProfileResult.failure(
        resp.data['message'] ?? 'Failed to delete account',
      );
    } on DioException catch (e) {
      return ProfileResult.failure(_extractError(e, 'Network error'));
    }
  }
}
