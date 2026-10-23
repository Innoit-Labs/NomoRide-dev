import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';

void main() {
  DpOrder order(Map<String, dynamic> extra) => DpOrder.fromJson({
        'id': 'o1',
        'order_number': 'NOMO_ORD-500',
        'flow_type': 'delivery',
        ...extra,
      });

  test('not_delivered order is an active RTO task, not completed', () {
    final o = order({'status': 'not_delivered', 'rejection_reason': 'Door locked'});
    expect(o.isUndeliveredReturnToHub, isTrue);
    expect(o.isVisibleOnHomeAssigned, isTrue);
    expect(o.journey.isCompleted, isFalse);
  });

  test('rto_status RTO_INITIATED triggers the RTO task', () {
    final o = order({'status': 'in_transit_to_iap', 'rto_status': 'RTO_INITIATED'});
    expect(o.rtoStatus, 'RTO_INITIATED');
    expect(o.isRtoInitiated, isTrue);
    expect(o.isUndeliveredReturnToHub, isTrue);
  });

  test('rto_returned closes the task', () {
    final o = order({'status': 'rto_returned', 'rto_status': 'RTO_RETURNED'});
    expect(o.isReturnedToIap, isTrue);
    expect(o.isUndeliveredReturnToHub, isFalse);
    expect(o.isVisibleOnHomeAssigned, isFalse);
  });

  test('not_delivered with RTO_COMPLETED leaves home and stays Not Delivered', () {
    final o = order({
      'status': 'not_delivered',
      'rto_status': 'RTO_COMPLETED',
      'rejection_reason': 'customer unavailable',
      'completed_at': '2026-10-16T07:01:17.000Z',
      'returned_to_iap_at': '2026-10-16T07:01:17.000Z',
    });
    expect(o.isRtoCompleted, isTrue);
    expect(o.isReturnedToIap, isTrue);
    expect(o.isUndeliveredReturnToHub, isFalse);
    expect(o.isVisibleOnHomeAssigned, isFalse);
    expect(o.journey.isCompleted, isTrue);
    expect(o.journey.statusBadgeLabel, 'Not Delivered');
  });

  test('not_delivered with only completed_at stays active until RTO confirmation', () {
    final o = order({
      'status': 'not_delivered',
      'rto_status': 'RTO_INITIATED',
      'rejection_reason': 'customer unavailable',
      'completed_at': '2026-10-16T07:01:17.000Z',
    });
    expect(o.isRtoInitiated, isTrue);
    expect(o.hasCompletedRtoHandover, isFalse);
    expect(o.isVisibleOnHomeAssigned, isTrue);
    expect(o.journey.isCompleted, isFalse);
  });

  test('failed delivery keeps the customer note, not the failure reason', () {
    final o = order({
      'status': 'not_delivered',
      'notes': 'unnnnnn',
      'instructions': 'unnnnnn',
      'rejection_reason': 'unnnnnn',
      'failure_reason': 'unnnnnn',
      'order_note': 'be some late',
    });
    expect(o.notes, 'be some late');
    expect(o.instructions, isNull);
    expect(o.rejectionReason, 'unnnnnn');
  });

  test('delivery order shows customer note when nothing failed', () {
    final o = order({
      'status': 'in_transit_to_iap',
      'notes': 'forward flow 1',
      'instructions': 'forward flow 1',
      'order_note': 'forward flow 1',
    });
    expect(o.notes, 'forward flow 1');
    expect(o.instructions, 'forward flow 1');
  });

  test('return flow orders never become RTO tasks', () {
    final o = order({'flow_type': 'return', 'status': 'return_failed'});
    expect(o.isUndeliveredReturnToHub, isFalse);
  });
}
