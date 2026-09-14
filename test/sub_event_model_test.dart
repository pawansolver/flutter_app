import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/event_model.dart';

void main() {
  group('Enterprise Sub-Event Model Tests', () {
    test('SubEventModel parses all enterprise fields properly', () {
      final json = {
        'id': 'sub_101',
        'title': 'Badminton Singles Quarter-Finals',
        'description': '3 sets, 21 points standard tournament rules',
        'date': '2026-10-15',
        'start_time': '09:00 AM',
        'end_time': '10:30 AM',
        'venue': 'Indoor Court 2',
        'location': 'Sports Complex Indoor Court 2',
        'address': 'Wing B, Sector 4',
        'event_type': 'offline',
        'speaker_or_host': 'Chief Referee Ramesh',
        'activity_type': 'sports',
        'capacity': 32,
        'is_registration_required': true,
        'status': 'scheduled',
      };

      final sub = SubEventModel.fromJson(json);

      expect(sub.id, 'sub_101');
      expect(sub.title, 'Badminton Singles Quarter-Finals');
      expect(sub.activityType, 'sports');
      expect(sub.startTime, '09:00 AM');
      expect(sub.endTime, '10:30 AM');
      expect(sub.venue, 'Indoor Court 2');
      expect(sub.location, 'Sports Complex Indoor Court 2');
      expect(sub.address, 'Wing B, Sector 4');
      expect(sub.speakerOrHost, 'Chief Referee Ramesh');
      expect(sub.capacity, 32);
      expect(sub.isRegistrationRequired, true);
      expect(sub.status, 'scheduled');

      // Test toJson
      final outputJson = sub.toJson();
      expect(outputJson['title'], 'Badminton Singles Quarter-Finals');
      expect(outputJson['activity_type'], 'sports');
      expect(outputJson['capacity'], 32);
      expect(outputJson['is_registration_required'], true);
    });

    test('EventModel parses MySQL raw stringified JSON sub_events', () {
      final mysqlRowJson = {
        'id': 133,
        'title': 'test1',
        'event_type': 'online',
        'sub_events': jsonEncode([
          {
            'id': 'sub_1',
            'title': 'Opening Keynote',
            'activity_type': 'ceremony',
            'start_time': '06:00 PM',
            'end_time': '06:45 PM',
            'venue': 'Auditorium',
            'speaker_or_host': 'President',
            'capacity': 100,
            'is_registration_required': false,
          },
          {
            'id': 'sub_2',
            'title': 'Dance Competition',
            'activity_type': 'competition',
            'start_time': '07:00 PM',
            'end_time': '08:30 PM',
            'capacity': 50,
            'is_registration_required': true,
          }
        ]),
      };

      final event = EventModel.fromJson(mysqlRowJson);

      expect(event.id, 133);
      expect(event.title, 'test1');
      expect(event.subEvents.length, 2);
      expect(event.subEvents[0].title, 'Opening Keynote');
      expect(event.subEvents[0].activityType, 'ceremony');
      expect(event.subEvents[1].title, 'Dance Competition');
      expect(event.subEvents[1].isRegistrationRequired, true);
    });

    test('EventModel parses parsed List sub_events', () {
      final apiJson = {
        'id': 134,
        'title': 'Annual Fest',
        'sub_events': [
          {
            'id': 'sub_fe_1',
            'title': 'Coding Marathon',
            'activity_type': 'workshop',
            'start_time': '10:00 AM',
            'end_time': '02:00 PM',
            'capacity': 60,
            'is_registration_required': true,
          }
        ],
      };

      final event = EventModel.fromJson(apiJson);

      expect(event.id, 134);
      expect(event.subEvents.length, 1);
      expect(event.subEvents[0].title, 'Coding Marathon');
      expect(event.subEvents[0].capacity, 60);
    });

    test('SubEventModel parses and retains coverImage and localImagePath', () {
      final json = {
        'id': 'sub_banner_1',
        'title': 'Battle of the Bands',
        'activity_type': 'cultural',
        'cover_image': '/uploads/event/banner_sample.jpg',
        'local_image_path': '/storage/emulated/0/DCIM/poster.jpg',
      };

      final sub = SubEventModel.fromJson(json);

      expect(sub.id, 'sub_banner_1');
      expect(sub.title, 'Battle of the Bands');
      expect(sub.coverImage, isNotNull);
      expect(sub.coverImage, contains('banner_sample.jpg'));
      expect(sub.localImagePath, '/storage/emulated/0/DCIM/poster.jpg');

      final copied = sub.copyWith(coverImage: 'https://cdn.example.com/custom_poster.png');
      expect(copied.coverImage, 'https://cdn.example.com/custom_poster.png');
      expect(copied.localImagePath, '/storage/emulated/0/DCIM/poster.jpg');

      final outputJson = sub.toJson();
      expect(outputJson['cover_image'], sub.coverImage);
    });
  });
}

