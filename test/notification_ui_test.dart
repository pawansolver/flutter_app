import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/modules/core/notification_service.dart';
import 'package:my_first_app/modules/core/widgets/notification_card.dart';

void main() {
  group('AppNotification Model & Deep-Link Resolution Tests', () {
    test('parses JSON correctly with createdAt and unread state', () {
      final json = {
        'id': 101,
        'title': 'New Booking Request',
        'message': 'Ramesh requested Home Cleaning at 4:00 PM',
        'type': 'booking_request',
        'isRead': false,
        'createdAt': '2026-09-09T10:30:00.000Z',
        'data': {
          'bookingId': 42,
          'isProvider': true,
        },
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.id, 101);
      expect(notif.title, 'New Booking Request');
      expect(notif.message, 'Ramesh requested Home Cleaning at 4:00 PM');
      expect(notif.type, 'booking_request');
      expect(notif.isRead, isFalse);
      expect(notif.createdAt, isNotNull);
      expect(notif.deepLinkTarget, 'booking');
    });

    test('resolves deepLinkTarget for chat message', () {
      final notif = AppNotification.fromJson({
        'id': 1,
        'title': 'New Message',
        'message': 'Hello there',
        'type': 'chat_message',
        'isRead': true,
        'data': {'chatId': 12, 'chatName': 'Rohan'},
      });

      expect(notif.deepLinkTarget, 'chat');
    });

    test('resolves deepLinkTarget for event reminder', () {
      final notif = AppNotification.fromJson({
        'id': 2,
        'title': 'Event Reminder',
        'message': 'Yoga starts tomorrow',
        'type': 'event_reminder',
        'isRead': true,
        'data': {'eventId': 55},
      });

      expect(notif.deepLinkTarget, 'event');
    });

    test('resolves deepLinkTarget for community update', () {
      final notif = AppNotification.fromJson({
        'id': 3,
        'title': 'Community Announcement',
        'message': 'Maintenance scheduled',
        'type': 'announcement',
        'isRead': false,
        'data': {'communityId': 9},
      });

      expect(notif.deepLinkTarget, 'community');
    });

    test('resolves deepLinkTarget for follow request', () {
      final notif = AppNotification.fromJson({
        'id': 4,
        'title': 'New Follower',
        'message': 'Aarav followed you',
        'type': 'follow',
        'isRead': false,
        'data': {'userId': 77, 'userName': 'aarav'},
      });

      expect(notif.deepLinkTarget, 'profile');
    });

    test('resolves deepLinkTarget for society complaint', () {
      final notif = AppNotification.fromJson({
        'id': 5,
        'title': 'Complaint Status Updated',
        'message': 'Your plumbing complaint is in progress',
        'type': 'society_complaint',
        'isRead': false,
        'data': {'societyId': 3, 'complaintId': 15},
      });

      expect(notif.deepLinkTarget, 'society');
    });

    test('copyWith updates isRead state immutably', () {
      const original = AppNotification(
        id: 99,
        title: 'Title',
        message: 'Msg',
        type: 'info',
        isRead: false,
      );

      final updated = original.copyWith(isRead: true);

      expect(original.isRead, isFalse);
      expect(updated.isRead, isTrue);
      expect(updated.id, 99);
    });
  });

  group('NotificationCard Widget Tests', () {
    testWidgets('renders title, message, and responds to tap', (tester) async {
      bool tapped = false;
      const notif = AppNotification(
        id: 1,
        title: 'Someone liked your post',
        message: 'Priya liked your post in Indiranagar',
        type: 'like',
        isRead: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              notification: notif,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Someone liked your post'), findsOneWidget);
      expect(find.text('Priya liked your post in Indiranagar'), findsOneWidget);

      await tester.tap(find.byType(NotificationCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('renders read notification without unread dot', (tester) async {
      const notif = AppNotification(
        id: 2,
        title: 'New promotion available',
        message: 'Get 20% off on laundry service',
        type: 'promotion',
        isRead: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              notification: notif,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('New promotion available'), findsOneWidget);
      expect(find.text('Get 20% off on laundry service'), findsOneWidget);
    });

    testWidgets('renders community invitation buttons if invitationId exists', (tester) async {
      bool accepted = false;
      bool declined = false;

      final notif = AppNotification.fromJson({
        'id': 3,
        'title': 'Community Invitation',
        'message': 'You have been invited to join Green Valley',
        'type': 'community',
        'isRead': false,
        'data': {
          'communityId': 10,
          'invitationId': 25,
        },
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationCard(
              notification: notif,
              onTap: () {},
              onAcceptInvitation: () => accepted = true,
              onDeclineInvitation: () => declined = true,
            ),
          ),
        ),
      );

      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pump();
      expect(accepted, isTrue);

      await tester.tap(find.text('Decline'));
      await tester.pump();
      expect(declined, isTrue);
    });
  });
}
