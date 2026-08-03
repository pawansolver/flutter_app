import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/modules/profile/profile_service.dart';

void main() {
  group('UserProfileModel.fromJson', () {
    test('parses mixed numeric representations and defaults', () {
      final profile = UserProfileModel.fromJson({
        'id': '17',
        'latitude': '30.7333',
        'longitude': 76,
        'isActive': true,
        'hasPassword': true,
        'role': 'provider',
      });

      expect(profile.id, 17);
      expect(profile.fullName, 'smartgali User');
      expect(profile.latitude, 30.7333);
      expect(profile.longitude, 76.0);
      expect(profile.hasPassword, isTrue);
      expect(profile.roleLabel, 'Service Provider Profile');
    });

    test('handles malformed optional values safely', () {
      final profile = UserProfileModel.fromJson({
        'id': null,
        'latitude': 'unknown',
      });

      expect(profile.id, 0);
      expect(profile.latitude, isNull);
      expect(profile.isVerified, isFalse);
      expect(profile.role, 'resident');
    });
  });

  group('AddressModel.fromJson', () {
    test('parses IDs and address fields', () {
      final address = AddressModel.fromJson({
        'id': '5',
        'label': 'Shop',
        'houseNo': 21,
        'city': 'Chandigarh',
        'fullAddress': '21, Chandigarh',
        'isDefault': true,
      });

      expect(address.id, 5);
      expect(address.label, 'Shop');
      expect(address.houseNo, '21');
      expect(address.city, 'Chandigarh');
      expect(address.isDefault, isTrue);
    });

    test('uses stable defaults for sparse payloads', () {
      final address = AddressModel.fromJson({});
      expect(address.id, 0);
      expect(address.label, 'Home');
      expect(address.isDefault, isFalse);
    });
  });
}
