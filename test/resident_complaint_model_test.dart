import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/society_models.dart';

void main() {
  group('SocietyComplaintModel - Resident Phase 1 Tests', () {
    test('ticketNumber formats correctly with 4-digit zero padding', () {
      const complaint1 = SocietyComplaintModel(
        id: 7,
        societyId: 1,
        userId: 10,
        title: 'Water leak',
        description: 'Bathroom pipe leaking',
        category: 'plumbing',
        priority: 'high',
        status: 'open',
      );
      expect(complaint1.ticketNumber, equals('#CMP-0007'));

      const complaint2 = SocietyComplaintModel(
        id: 42,
        societyId: 1,
        userId: 10,
        title: 'Lift stuck',
        description: 'Lift B stopped at 3rd floor',
        category: 'lift',
        priority: 'urgent',
        status: 'in_progress',
      );
      expect(complaint2.ticketNumber, equals('#CMP-0042'));

      const complaint3 = SocietyComplaintModel(
        id: 1054,
        societyId: 1,
        userId: 10,
        title: 'Main gate bulb fused',
        description: 'Needs bulb replacement',
        category: 'electrical',
        priority: 'low',
        status: 'resolved',
      );
      expect(complaint3.ticketNumber, equals('#CMP-1054'));
    });

    test('Status lifecycle getters work accurately', () {
      const openComplaint = SocietyComplaintModel(
        id: 1,
        societyId: 1,
        userId: 10,
        title: 'Test',
        description: 'Test',
        category: 'general',
        priority: 'medium',
        status: 'open',
      );
      expect(openComplaint.isOpen, isTrue);
      expect(openComplaint.isInProgress, isFalse);
      expect(openComplaint.isResolved, isFalse);
      expect(openComplaint.isClosed, isFalse);
      expect(openComplaint.canClose, isFalse);
      expect(openComplaint.canReopen, isFalse);

      const progressComplaint = SocietyComplaintModel(
        id: 2,
        societyId: 1,
        userId: 10,
        title: 'Test',
        description: 'Test',
        category: 'general',
        priority: 'medium',
        status: 'in_progress',
      );
      expect(progressComplaint.isOpen, isFalse);
      expect(progressComplaint.isInProgress, isTrue);
      expect(progressComplaint.isResolved, isFalse);
      expect(progressComplaint.isClosed, isFalse);

      const resolvedComplaint = SocietyComplaintModel(
        id: 3,
        societyId: 1,
        userId: 10,
        title: 'Test',
        description: 'Test',
        category: 'general',
        priority: 'medium',
        status: 'resolved',
      );
      expect(resolvedComplaint.isResolved, isTrue);
      expect(resolvedComplaint.canClose, isTrue);
      expect(resolvedComplaint.canReopen, isTrue);

      const closedComplaint = SocietyComplaintModel(
        id: 4,
        societyId: 1,
        userId: 10,
        title: 'Test',
        description: 'Test',
        category: 'general',
        priority: 'medium',
        status: 'closed',
      );
      expect(closedComplaint.isClosed, isTrue);
      expect(closedComplaint.canClose, isFalse);
      expect(closedComplaint.canReopen, isTrue);
    });

    test('Assignee display and resolution helpers behave properly', () {
      const unassigned = SocietyComplaintModel(
        id: 1,
        societyId: 1,
        userId: 10,
        title: 'Test',
        description: 'Test',
        category: 'general',
        priority: 'medium',
        status: 'open',
      );
      expect(unassigned.hasAssignee, isFalse);
      expect(unassigned.assigneeDisplay, equals('Unassigned'));
      expect(unassigned.hasResolution, isFalse);

      const assignedWithUser = SocietyComplaintModel(
        id: 2,
        societyId: 1,
        userId: 10,
        title: 'Test',
        description: 'Test',
        category: 'electrical',
        priority: 'medium',
        status: 'assigned',
        assignedTo: 88,
        assignee: {
          'userName': 'Ramesh Electrician',
          'phone': '9876543210',
        },
      );
      expect(assignedWithUser.hasAssignee, isTrue);
      expect(assignedWithUser.assigneeDisplay, equals('Ramesh Electrician'));
      expect(assignedWithUser.assigneePhone, equals('9876543210'));

      final now = DateTime.now();
      final resolved = SocietyComplaintModel(
        id: 3,
        societyId: 1,
        userId: 10,
        title: 'Test',
        description: 'Test',
        category: 'plumbing',
        priority: 'high',
        status: 'resolved',
        resolvedAt: now,
        remark: 'Pipe fixed with Teflon seal',
      );
      expect(resolved.hasResolution, isTrue);
      expect(resolved.remark, equals('Pipe fixed with Teflon seal'));
    });

    test('fromJson deserializes all fields accurately', () {
      final json = {
        'id': 55,
        'society_id': 12,
        'user_id': 99,
        'title': 'Power fluctuation',
        'description': 'Voltage dropping in evening',
        'category': 'electrical',
        'priority': 'urgent',
        'status': 'resolved',
        'assigned_to': 44,
        'resolved_at': '2026-09-14T10:30:00.000Z',
        'closed_at': null,
        'remark': 'Transformer tap changed by BESCOM',
        'created_at': '2026-09-14T08:00:00.000Z',
        'user': {'userName': 'Suresh Resident', 'phone': '9111222333'},
        'assignee': {'userName': 'Kiran Electrical Lead', 'phone': '9998887776'},
      };

      final model = SocietyComplaintModel.fromJson(json);
      expect(model.id, equals(55));
      expect(model.ticketNumber, equals('#CMP-0055'));
      expect(model.societyId, equals(12));
      expect(model.userId, equals(99));
      expect(model.title, equals('Power fluctuation'));
      expect(model.category, equals('electrical'));
      expect(model.priority, equals('urgent'));
      expect(model.status, equals('resolved'));
      expect(model.isResolved, isTrue);
      expect(model.canClose, isTrue);
      expect(model.canReopen, isTrue);
      expect(model.assigneeDisplay, equals('Kiran Electrical Lead'));
      expect(model.assigneePhone, equals('9998887776'));
      expect(model.complainantName, equals('Suresh Resident'));
      expect(model.remark, equals('Transformer tap changed by BESCOM'));
    });

    test('Structured sub-category and location fields parse and format correctly', () {
      final json = {
        'id': 101,
        'society_id': 1,
        'user_id': 27,
        'title': 'Water leakage in bathroom',
        'description': 'Continuous dripping from concealed pipe behind shower',
        'category': 'plumbing',
        'sub_category': 'Water Leakage',
        'location_type': 'my_flat',
        'flat_no': '402-A',
        'exact_location': 'Master bathroom shower wall',
        'priority': 'high',
        'status': 'open',
      };

      final model = SocietyComplaintModel.fromJson(json);
      expect(model.subCategory, equals('Water Leakage'));
      expect(model.locationType, equals('my_flat'));
      expect(model.flatNo, equals('402-A'));
      expect(model.exactLocation, equals('Master bathroom shower wall'));
      expect(model.hasStructuredLocation, isTrue);
      expect(model.locationTypeDisplay, equals('My Flat'));
      expect(
        model.locationDisplay,
        equals('My Flat • Flat: 402-A • Master bathroom shower wall'),
      );

      final exportedJson = model.toJson();
      expect(exportedJson['sub_category'], equals('Water Leakage'));
      expect(exportedJson['location_type'], equals('my_flat'));
      expect(exportedJson['flat_no'], equals('402-A'));
      expect(exportedJson['exact_location'], equals('Master bathroom shower wall'));
    });

    test('Common area location display formats accurately without flat number', () {
      const model = SocietyComplaintModel(
        id: 102,
        societyId: 1,
        userId: 27,
        title: 'Lift button jammed',
        description: '3rd floor up button stuck',
        category: 'lift',
        subCategory: 'Display / Button Fault',
        locationType: 'lift',
        exactLocation: 'Tower 2, Passenger Lift #1',
        priority: 'urgent',
        status: 'open',
      );

      expect(model.subCategory, equals('Display / Button Fault'));
      expect(model.locationType, equals('lift'));
      expect(model.flatNo, isNull);
      expect(model.hasStructuredLocation, isTrue);
      expect(model.locationTypeDisplay, equals('Lift'));
      expect(model.locationDisplay, equals('Lift • Tower 2, Passenger Lift #1'));
    });
  });
}
