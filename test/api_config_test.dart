import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/core/api_config.dart';

void main() {
  test(
    'base URL and endpoint builders contain no trailing slash duplication',
    () {
      expect(ApiConfig.baseUrl, isNot(endsWith('/')));
      expect(ApiConfig.me, '${ApiConfig.baseUrl}/profile/me');
      expect(ApiConfig.address(9), '${ApiConfig.baseUrl}/profile/addresses/9');
      expect(ApiConfig.authSignup, '${ApiConfig.baseUrl}/auth/signup');
      expect(ApiConfig.authSignin, '${ApiConfig.baseUrl}/auth/signin');
      expect(
        ApiConfig.authRefreshToken,
        '${ApiConfig.baseUrl}/auth/refresh-token',
      );
      expect(ApiConfig.authProfile, '${ApiConfig.baseUrl}/auth/profile');
      expect(ApiConfig.authAccount, '${ApiConfig.baseUrl}/auth/account');
    },
  );

  test('media URL normalization handles null, blank, and relative values', () {
    expect(ApiConfig.normalizeMediaUrl(null), isNull);
    expect(ApiConfig.normalizeMediaUrl('   '), isNull);

    final normalized = Uri.parse(
      ApiConfig.normalizeMediaUrl('/uploads/avatars/a.jpg')!,
    );
    final base = Uri.parse(ApiConfig.baseUrl);
    expect(normalized.scheme, base.scheme);
    expect(normalized.host, base.host);
    expect(normalized.port, base.port);
    expect(normalized.path, '/uploads/avatars/a.jpg');
  });

  test('absolute remote media URLs remain unchanged', () {
    const remote = 'https://cdn.example.test/avatar.png?size=2';
    expect(ApiConfig.normalizeMediaUrl(remote), remote);
  });
}
