import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/services/auth_session.dart';

void main() {
  test('parses backend auth token envelope', () {
    final session = AuthSession.fromEnvelope({
      'success': true,
      'message': 'Signed in successfully.',
      'data': {
        'accessToken': 'access-token',
        'refreshToken': 'refresh-token',
        'tokenType': 'Bearer',
        'expiresIn': '15m',
        'refreshExpiresIn': '30d',
        'user': {
          'id': 42,
          'name': 'Test User',
          'email': 'test@example.com',
          'mobile': '9876543210',
          'role': 'resident',
        },
      },
    });

    expect(session.accessToken, 'access-token');
    expect(session.refreshToken, 'refresh-token');
    expect(session.user.id, 42);
    expect(session.user.role, 'resident');
    expect(session.expiresIn, '15m');
  });

  test('rejects incomplete authentication envelopes', () {
    expect(
      () => AuthSession.fromEnvelope({
        'success': true,
        'data': {'accessToken': 'only-access'},
      }),
      throwsFormatException,
    );
  });
}
