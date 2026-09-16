import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/society_models.dart';

void main() {
  group('Admin Complaint Models Test Suite', () {
    test('SocietyComplaintSummaryModel parses correctly from backend JSON', () {
      final json = {
        'total': 15,
        'open': 4,
        'assigned': 3,
        'in_progress': 5,
        'resolved': 2,
        'closed': 1,
      };

      final summary = SocietyComplaintSummaryModel.fromJson(json);

      expect(summary.total, 15);
      expect(summary.open, 4);
      expect(summary.assigned, 3);
      expect(summary.inProgress, 5);
      expect(summary.resolved, 2);
      expect(summary.closed, 1);
    });

    test('SocietyComplaintHistoryItemModel parses correctly from backend JSON', () {
      final json = {
        'id': 101,
        'society_id': 70,
        'actor_user_id': 27,
        'action': 'society.complaint_status_changed',
        'target_user_id': 38,
        'old_value': {'status': 'assigned'},
        'new_value': {'status': 'in_progress'},
        'reason': 'Technician dispatched to motor room.',
        'created_at': '2026-09-14T09:44:00.000Z',
        'actor': {'userId': 27, 'userName': 'Pawan Admin'},
        'targetUser': {'userId': 38, 'userName': 'Rameez Staff'},
      };

      final item = SocietyComplaintHistoryItemModel.fromJson(json);

      expect(item.id, 101);
      expect(item.actorName, 'Pawan Admin');
      expect(item.formattedTitle, 'Work Started (In Progress)');
      expect(item.reason, 'Technician dispatched to motor room.');
      expect(item.createdAt?.year, 2026);
    });

    test('SocietyComplaintModel handles reopened state and helpers correctly', () {
      final reopenedJson = {
        'id': 42,
        'society_id': 70,
        'user_id': 35,
        'title': 'Leaking Tap',
        'description': 'Water leak',
        'category': 'plumbing',
        'priority': 'high',
        'status': 'open',
        'flat_no': 'B-204',
        'resolved_at': '2026-09-14T08:00:00.000Z',
        'user': {'userId': 35, 'userName': 'Gajendra Resident', 'phone': '9876543210'},
      };

      final model = SocietyComplaintModel.fromJson(reopenedJson);

      expect(model.id, 42);
      expect(model.ticketNumber, '#CMP-0042');
      expect(model.isReopened, true);
      expect(model.statusBadgeLabel, 'REOPENED');
      expect(model.residentFlatDisplay, 'B-204');
      expect(model.complainantName, 'Gajendra Resident');
      expect(model.residentPhone, '9876543210');
    });
  });
}
