import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api_config.dart';
import '../../../services/authenticated_dio.dart';

class UploadService {
  final Dio _dio = AuthenticatedDio().dio;
  final _storage = const FlutterSecureStorage();

  Future<Options> _authOptions() async {
    final token = await _storage.read(key: 'jwt_token');
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Web + Mobile compatible media upload using XFile (from image_picker)
  Future<Map<String, dynamic>?> uploadXFile(
    XFile xfile, {
    void Function(int, int)? onProgress,
  }) async {
    try {
      final bytes = await xfile.readAsBytes();
      final fileName = xfile.name.isNotEmpty ? xfile.name : 'upload.jpg';
      final mimeType = xfile.mimeType ?? _guessMime(fileName);

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      final resp = await _dio.post(
        '${ApiConfig.baseUrl}/post/upload',
        data: formData,
        options: await _authOptions(),
        onSendProgress: onProgress,
      );

      if (resp.statusCode == 201 && resp.data['success'] == true) {
        return resp.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _guessMime(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/avi';
      default:
        return 'application/octet-stream';
    }
  }
}
