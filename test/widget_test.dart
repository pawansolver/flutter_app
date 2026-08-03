import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/modules/profile/profile_service.dart';
import 'package:my_first_app/modules/settings/change_password_screen.dart';

class FakeAccountSecurityService implements AccountSecurityService {
  final ProfileResult<UserProfileModel> profileResult;

  FakeAccountSecurityService(this.profileResult);

  @override
  Future<ProfileResult<UserProfileModel>> getMe() async => profileResult;

  @override
  Future<ProfileResult<bool>> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async => const ProfileResult.success(true);
}

UserProfileModel profile({required bool hasPassword}) => UserProfileModel(
  id: 1,
  fullName: 'Test User',
  role: 'resident',
  isActive: true,
  isVerified: true,
  hasPassword: hasPassword,
  isProfileComplete: true,
);

void main() {
  testWidgets('password screen adapts to OTP-only accounts', (tester) async {
    final service = FakeAccountSecurityService(
      ProfileResult.success(profile(hasPassword: false)),
    );

    await tester.pumpWidget(
      MaterialApp(home: ChangePasswordScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your OTP account does not have a password yet. Create one below.',
      ),
      findsOneWidget,
    );
    expect(find.text('Current Password'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('password screen exposes service failures with retry', (
    tester,
  ) async {
    final service = FakeAccountSecurityService(
      const ProfileResult.failure('Account lookup failed'),
    );

    await tester.pumpWidget(
      MaterialApp(home: ChangePasswordScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account lookup failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
