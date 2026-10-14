// Unit tests for the offline-aware submission model + helpers.
//
// These cover the pure logic that underpins the history/queue UI without
// touching the network: the status-tag mapping, the shared number formatter and
// the pending-submission serialization round-trip.

import 'package:flutter_test/flutter_test.dart';

import 'package:moali.itlens/features/home/submission_card.dart';
import 'package:moali.itlens/features/home/submission_repository.dart';

void main() {
  group('statusTag', () {
    test('maps the backend collection states to the three user-facing tags', () {
      expect(SubmissionRepository.statusTag('approved'), 'live');
      expect(SubmissionRepository.statusTag('Approved'), 'live');
      expect(SubmissionRepository.statusTag('submitted'), 'synced');
      expect(SubmissionRepository.statusTag('under_review'), 'synced');
      expect(SubmissionRepository.statusTag('under review'), 'synced');
      expect(SubmissionRepository.statusTag('returned'), 'synced');
      expect(SubmissionRepository.statusTag('reopened'), 'synced');
      expect(SubmissionRepository.statusTag('pending'), 'pending');
      expect(SubmissionRepository.statusTag(''), 'synced');
    });
  });

  group('formatInt', () {
    test('groups thousands and handles ints, strings and junk', () {
      expect(formatInt(0), '0');
      expect(formatInt(7), '7');
      expect(formatInt(1234), '1,234');
      expect(formatInt(1234567), '1,234,567');
      expect(formatInt(-9876), '-9,876');
      expect(formatInt('4200'), '4,200');
      expect(formatInt(null), '0');
      expect(formatInt('not a number'), '0');
    });
  });

  group('PendingSubmission', () {
    test('survives a JSON round-trip and renders as a pending row', () {
      final original = PendingSubmission(
        localId: 'local-1',
        payload: const {'household_no': 'HH-001', 'interview_date': '2026-01-02'},
        householdNo: 'HH-001',
        createdAt: DateTime.parse('2026-01-02T09:30:00Z'),
        allowDuplicate: true,
      );

      final restored = PendingSubmission.fromJson(original.toJson());

      expect(restored.localId, 'local-1');
      expect(restored.householdNo, 'HH-001');
      expect(restored.allowDuplicate, isTrue);
      expect(restored.payload['interview_date'], '2026-01-02');
      expect(restored.createdAt, original.createdAt);

      final row = restored.toRow();
      expect(row['id'], 'local-1');
      expect(row['collection_status'], 'pending');
      expect(row['_local'], isTrue);
    });
  });
}
