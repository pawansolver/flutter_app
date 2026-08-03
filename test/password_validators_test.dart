import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/modules/settings/password_validators.dart';

void main() {
  group('validateNewPassword', () {
    test('accepts the backend-compatible password policy', () {
      expect(validateNewPassword('Strong123!'), isNull);
    });

    test('reports each missing requirement', () {
      expect(validateNewPassword(''), 'Please enter a new password');
      expect(
        validateNewPassword('Ab1!'),
        'Password must be at least 8 characters',
      );
      expect(
        validateNewPassword('Password!'),
        'Password must include at least one number',
      );
      expect(
        validateNewPassword('Password1'),
        'Password must include a special character',
      );
      expect(
        validateNewPassword('PASSWORD1!'),
        'Password must include a lowercase letter',
      );
      expect(
        validateNewPassword('password1!'),
        'Password must include an uppercase letter',
      );
      expect(
        validateNewPassword(List.filled(19, 'Aa1!').join()),
        'Password must be no more than 72 characters',
      );
    });
  });

  test('password confirmation must be present and match', () {
    expect(
      validatePasswordConfirmation('', 'Strong123!'),
      'Please confirm new password',
    );
    expect(
      validatePasswordConfirmation('Other123!', 'Strong123!'),
      'Passwords do not match',
    );
    expect(validatePasswordConfirmation('Strong123!', 'Strong123!'), isNull);
  });
}
