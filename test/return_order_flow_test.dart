import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';

void main() {
  group('Return Flow vs Forward Flow Badge Labels', () {
    test('Return order when initially assigned shows Return Accepted', () {
      final json = {
        'id': 'order_1',
        'order_number': 'NOMO_ORD-RET-1',
        'flow_type': 'return',
        'status': 'return_assigned',
      };
      final order = DpOrder.fromJson(json);

      expect(order.isReturnFlow, isTrue);
      expect(order.journey.statusBadgeLabel, 'Return Accepted');
    });

    test('Return order initially in transit before arriving at customer shows En Route to Customer Location', () {
      // Backend may send in_transit_to_iap, start, or in_transit_to_customer for the first transit leg
      for (final status in ['in_transit_to_iap', 'start', 'in_transit', 'in_transit_to_customer']) {
        final json = {
          'id': 'order_2',
          'order_number': 'NOMO_ORD-RET-2',
          'flow_type': 'return',
          'status': status,
        };
        final order = DpOrder.fromJson(json);

        expect(order.isReturnFlow, isTrue);
        expect(
          order.journey.statusBadgeLabel,
          'En Route to Customer Location',
          reason: 'Status $status should show En Route to Customer Location',
        );
      }
    });

    test('Return order on the way to the customer shows En Route to Customer Location', () {
      for (final status in ['arrived', 'arrived_at_customer', 'arrived_at_iap']) {
        final json = {
          'id': 'order_3',
          'order_number': 'NOMO_ORD-RET-3',
          'flow_type': 'return',
          'status': status,
        };
        final order = DpOrder.fromJson(json);

        expect(order.isReturnFlow, isTrue);
        expect(
          order.journey.statusBadgeLabel,
          'En Route to Customer Location',
          reason: 'Status $status should show En Route to Customer Location',
        );
      }
    });

    test('Return order during customer pickup and return trip to Hub shows En Route to Hub', () {
      // confirm_pickup / in_transit_to_delivery / in_transit_to_iap with pickupConfirmedAt
      final pickupJson = {
        'id': 'order_4',
        'order_number': 'NOMO_ORD-RET-4',
        'flow_type': 'return',
        'status': 'pickup_confirmed',
        'pickup_confirmed_at': '2026-10-09T10:00:00Z',
      };
      final pickupOrder = DpOrder.fromJson(pickupJson);
      expect(pickupOrder.journey.statusBadgeLabel, 'En Route to Hub');

      final transitToHubJson = {
        'id': 'order_5',
        'order_number': 'NOMO_ORD-RET-5',
        'flow_type': 'return',
        'status': 'in_transit_to_delivery',
        'pickup_confirmed_at': '2026-10-09T10:00:00Z',
      };
      final transitToHubOrder = DpOrder.fromJson(transitToHubJson);
      expect(transitToHubOrder.journey.statusBadgeLabel, 'En Route to Hub');
    });

    test('Forward delivery flow is NOT affected: in_transit_to_iap shows En Route to Hub', () {
      final json = {
        'id': 'order_forward',
        'order_number': 'NOMO_ORD-FWD-1',
        'flow_type': 'delivery',
        'status': 'in_transit_to_iap',
      };
      final order = DpOrder.fromJson(json);

      expect(order.isReturnFlow, isFalse);
      expect(order.journey.statusBadgeLabel, 'En Route to Hub');
    });

    test('Order with flow_type: delivery and notes is NOT return flow (NOMO_ORD-431)', () {
      final json = {
        'id': '49297798-ecc2-40e8-a747-e532771a9b48',
        'order_number': 'NOMO_ORD-431',
        'flow_type': 'delivery',
        'status': 'assigned',
        'notes': 'bhauuu',
        'order_note': 'bhauuu',
        'delivery_date': '2026-10-11T00:00:00.000Z',
        'delivery_time': '11:12 AM',
      };
      final order = DpOrder.fromJson(json);

      expect(order.isReturnFlow, isFalse);
      expect(order.journey.isReturn, isFalse);
      expect(order.journey.statusBadgeLabel, 'Accepted');
      expect(order.displayNotes, 'bhauuu');
      expect(order.formattedSchedule, contains('11:12 AM'));
    });

    test('Order with flow_type: return is return flow even without RET prefix', () {
      final json = {
        'id': 'return_order_999',
        'order_number': 'NOMO_ORD-432',
        'flow_type': 'return',
        'status': 'assigned',
      };
      final order = DpOrder.fromJson(json);

      expect(order.isReturnFlow, isTrue);
      expect(order.journey.isReturn, isTrue);
      expect(order.journey.statusBadgeLabel, 'Return Accepted');
    });
  });
}
