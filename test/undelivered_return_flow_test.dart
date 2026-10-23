import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';
import 'package:nomoride/features/home/data/models/order_flow.dart';

void main() {
  group('Undelivered Return to IAP Hub Flow Tests', () {
    test('Forward order with status not_delivered identifies as isUndeliveredReturnToHub', () {
      final json = {
        'id': 'ord-undelivered-1',
        'order_number': 'NOMO_ORD-501',
        'flow_type': 'delivery',
        'status': 'not_delivered',
        'pickup_address': 'IAP Partner Store, Main Street, Hub #1',
        'drop_address': 'Customer House 12, Park Road',
        'pickup_latitude': '12.9716',
        'pickup_longitude': '77.5946',
      };
      final order = DpOrder.fromJson(json);

      expect(order.isReturnFlow, isFalse);
      expect(order.isNotDelivered, isTrue);
      expect(order.isUndeliveredReturnToHub, isTrue);
      expect(order.isVisibleOnHomeAssigned, isTrue);
      expect(order.journey.isRejected, isFalse, reason: 'Return to hub workflow must remain active');
      expect(order.journey.currentPhase, OrderPhase.returnToIap);
      expect(order.journey.statusBadgeLabel, 'Return to IAP Store');
    });

    test('Undelivered return to hub transitions step by step back to IAP store', () {
      // 1. Initial not_delivered state
      var order = DpOrder.fromJson({
        'id': 'ord-undelivered-2',
        'order_number': 'NOMO_ORD-502',
        'flow_type': 'delivery',
        'status': 'not_delivered',
        'pickup_address': 'IAP Store Hub',
        'drop_address': 'Customer Location',
      });
      expect(order.journey.completedTransitionIndex, -1);
      expect(order.journey.nextTransition?.apiStatus, 'start');
      expect(order.journey.nextActionLabel, 'Head to Hub for Drop-off');
      expect(order.journey.statusBadgeLabel, 'Return to IAP Store');

      // 2. In transit to IAP Store
      order = DpOrder.fromJson({
        'id': 'ord-undelivered-2',
        'order_number': 'NOMO_ORD-502',
        'flow_type': 'delivery',
        'status': 'in_transit_to_iap',
        'rejection_reason': 'Customer not responding',
        'pickup_address': 'IAP Store Hub',
        'drop_address': 'Customer Location',
      });
      expect(order.journey.completedTransitionIndex, 0);
      expect(order.journey.nextTransition?.apiStatus, 'arrived');
      expect(order.journey.nextActionLabel, 'Arrived at Hub');
      expect(order.journey.statusBadgeLabel, 'En Route to Hub');

      // 3. Arrived at IAP Store
      order = DpOrder.fromJson({
        'id': 'ord-undelivered-2',
        'order_number': 'NOMO_ORD-502',
        'flow_type': 'delivery',
        'status': 'arrived_at_iap',
        'rejection_reason': 'Customer not responding',
        'pickup_address': 'IAP Store Hub',
        'drop_address': 'Customer Location',
      });
      expect(order.journey.completedTransitionIndex, 1);
      expect(order.journey.nextTransition?.apiStatus, 'confirm_delivery');
      expect(order.journey.nextActionLabel, 'Handover Items to IAP Hub');
      expect(order.journey.statusBadgeLabel, 'At IAP Store');

      // 4. Returned to IAP Store (completed)
      order = DpOrder.fromJson({
        'id': 'ord-undelivered-2',
        'order_number': 'NOMO_ORD-502',
        'flow_type': 'delivery',
        'status': 'returned_to_iap',
        'pickup_address': 'IAP Store Hub',
        'drop_address': 'Customer Location',
      });
      expect(order.isReturnedToIap, isTrue);
      expect(order.isUndeliveredReturnToHub, isFalse);
      expect(order.isVisibleOnHomeAssigned, isFalse);
      expect(order.journey.isCompleted, isTrue);
      // Delivery outcome stays visible after hub handover (My Orders → Not Delivered).
      expect(order.isNotDelivered, isTrue);
      expect(order.journey.statusBadgeLabel, 'Not Delivered');
    });

    test('Return flow orders where pickup failed do NOT enter undelivered return to hub', () {
      final json = {
        'id': 'ret-fail-1',
        'order_number': 'NOMO_ORD-RET-99',
        'flow_type': 'return',
        'status': 'return_failed',
      };
      final order = DpOrder.fromJson(json);

      expect(order.isReturnFlow, isTrue);
      expect(order.isUndeliveredReturnToHub, isFalse);
      expect(order.journey.isRejected, isTrue);
      expect(order.journey.statusBadgeLabel, 'Return Failed');
    });

    test('Delivery RTO completed (returned_to_iap) counts as Not Delivered for My Orders', () {
      final order = DpOrder.fromJson({
        'id': '53f8feb9-31d9-48cf-a84d-d84547c98e9b',
        'order_number': 'NOMO_ORD-489',
        'flow_type': 'delivery',
        'status': 'returned_to_iap',
        'parent_order_status': 'ACCEPTED',
        'orderStatus': 'ACCEPTED',
        'rto_status': 'RTO_COMPLETED',
        'rto_completed_at': '2026-10-21T11:31:04.000Z',
        'returned_to_iap_at': '2026-10-21T11:31:04.000Z',
        'rejection_reason': 'not available',
      });

      expect(order.isReturnFlow, isFalse);
      expect(order.isReturnFailed, isFalse);
      expect(order.isNotDelivered, isTrue);
      expect(order.isRtoCompleted, isTrue);
      expect(order.isVisibleOnHomeAssigned, isFalse);
    });

    test(
      'ORD-492: returned_to_iap + parent RETURN_FAILED → Pickup Failed '
      '(even when flow_type is delivery)',
      () {
        final order = DpOrder.fromJson({
          'id': '78201ff9-74da-4fbd-a24c-c70b8711570a',
          'order_number': 'NOMO_ORD-492',
          'flow_type': 'delivery',
          'status': 'returned_to_iap',
          'parent_order_status': 'RETURN_FAILED',
          'orderStatus': 'RETURN_FAILED',
          'parent_rejection_reason': 'venu not available at the house party',
          'rto_status': 'RTO_COMPLETED',
          'rto_completed_at': '2026-10-22T10:01:29.000Z',
          'returned_to_iap_at': '2026-10-22T10:01:29.000Z',
          'rejection_reason': 'venu',
        });

        expect(order.isReturnFlow, isFalse,
            reason: 'flow_type delivery must not force return-flow journey');
        expect(order.isReturnFailed, isTrue);
        expect(order.isNotDelivered, isTrue,
            reason: 'excluded from Completed; routed via isReturnFailed');
        expect(order.isRtoCompleted, isTrue);
        expect(order.isVisibleOnHomeAssigned, isFalse);
      },
    );

    test('Successful delivery completed stays Completed, not Not Delivered', () {
      final order = DpOrder.fromJson({
        'id': 'ba3cbd1f-2148-4bfa-bf89-55d38d5d0e40',
        'order_number': 'NOMO_ORD-490',
        'flow_type': 'delivery',
        'status': 'completed',
        'rto_status': 'NONE',
        'parent_order_status': 'RETURN_REQUESTED',
      });

      expect(order.isNotDelivered, isFalse);
      expect(order.isReturnFlow, isFalse);
    });
  });
}
