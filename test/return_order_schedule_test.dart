import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';

void main() {
  group('Return Order Schedule and Notes', () {
    test('Return order displays actual return requested date & time instead of garment delivery date & time', () {
      final json = {
        'id': 'order_123',
        'order_number': 'NOMO_ORD-279',
        'flow_type': 'return',
        'status': 'return_assigned',
        'items': [
          {
            'product_name': 'Formal Shirt',
            'kitDetails': {
              'delivery_date': '2026-09-30',
              'delivery_time': '10:45 PM',
              'return_date': '2026-10-06',
              'return_time': '04:00 PM',
            }
          }
        ],
      };

      final order = DpOrder.fromJson(json);

      expect(order.isReturnFlow, isTrue);
      // deliveryDate is the old garment delivery date (2026-09-30)
      expect(order.deliveryDate, '2026-09-30');
      expect(order.deliveryTime, '10:45 PM');
      // returnDate and returnTime must be the return requested schedule (2026-10-06 04:00 PM)
      expect(order.returnDate, '2026-10-06');
      expect(order.returnTime, '04:00 PM');
      // formattedDeliverySchedule MUST show the return schedule, NOT the garment delivery schedule!
      expect(order.formattedDeliverySchedule, contains('Tuesday, 6th Oct 04:00 PM'));
    });

    test('Return order reads return schedule from return_request map', () {
      final json = {
        'id': 'order_456',
        'order_number': 'NOMO_ORD-280',
        'flow_type': 'return',
        'status': 'return_assigned',
        'return_request': {
          'requested_date': '2026-10-07',
          'requested_time': '11:00 AM',
          'notes': 'Please pick up after 11 AM as I will be available then.',
        },
        'items': [
          {
            'kitDetails': {
              'delivery_date': '2026-09-30',
              'delivery_time': '10:45 PM',
            }
          }
        ],
      };

      final order = DpOrder.fromJson(json);

      expect(order.isReturnFlow, isTrue);
      expect(order.returnDate, '2026-10-07');
      expect(order.returnTime, '11:00 AM');
      expect(order.returnNotes, 'Please pick up after 11 AM as I will be available then.');
      expect(order.displayNotes, 'Please pick up after 11 AM as I will be available then.');
      expect(order.formattedDeliverySchedule, contains('Wednesday, 7th Oct 11:00 AM'));
    });

    test('Return order reads direct return_date, return_time, and return_notes', () {
      final json = {
        'id': 'order_789',
        'order_number': 'NOMO_ORD-281',
        'flow_type': 'return',
        'status': 'return_assigned',
        'return_date': '2026-10-08',
        'return_time': '14:30',
        'return_notes': 'Defective zipper on jacket.',
        'items': [
          {
            'kitDetails': {
              'delivery_date': '2026-09-30',
              'delivery_time': '10:45 PM',
            }
          }
        ],
      };

      final order = DpOrder.fromJson(json);

      expect(order.isReturnFlow, isTrue);
      expect(order.returnDate, '2026-10-08');
      expect(order.returnTime, '2:30 PM');
      expect(order.returnNotes, 'Defective zipper on jacket.');
      expect(order.displayNotes, 'Defective zipper on jacket.');
      expect(order.formattedDeliverySchedule, contains('Thursday, 8th Oct 2:30 PM'));
    });

    test('Delivery order continues to display garment delivery schedule', () {
      final json = {
        'id': 'order_101',
        'order_number': 'NOMO_ORD-101',
        'flow_type': 'delivery',
        'status': 'assigned',
        'items': [
          {
            'kitDetails': {
              'delivery_date': '2026-09-30',
              'delivery_time': '10:45 PM',
            }
          }
        ],
      };

      final order = DpOrder.fromJson(json);

      expect(order.isReturnFlow, isFalse);
      expect(order.formattedDeliverySchedule, contains('Wednesday, 30th Sep 10:45 PM'));
    });

    test('Return order with pickup_details (NOMO_ORD-285) displays return pickup slot instead of garment delivery slot', () {
      final json = {
        'id': 'order_285',
        'order_number': 'NOMO_ORD-285',
        'flow_type': 'return',
        'status': 'return_assigned',
        'pickup_details': {
          'pickup_date': '10 Oct 2026',
          'pickup_time': '07:30 AM',
          'name': 'kphb',
          'mobile': '6969696969',
          'note': 'schedule before the date',
        },
        'items': [
          {
            'kitDetails': {
              'delivery_date': '2026-10-22',
              'delivery_time': '12:00 PM - 03:00 PM',
            }
          }
        ],
      };

      final order = DpOrder.fromJson(json);

      expect(order.isReturnFlow, isTrue);
      // Garment delivery slot from original forward delivery
      expect(order.deliveryDate, '2026-10-22');
      expect(order.deliveryTime, '12:00 PM - 03:00 PM');
      // Return pickup slot requested by customer
      expect(order.returnDate, '2026-10-10');
      expect(order.returnTime, '07:30 AM');
      expect(order.customerName, 'kphb');
      expect(order.customerPhone, '6969696969');
      expect(order.displayNotes, 'schedule before the date');
      // Crucial: Must display Saturday, 10th Oct 07:30 AM, NOT Thursday, 22nd Oct 12:00 PM - 03:00 PM!
      expect(order.formattedDeliverySchedule, 'Saturday, 10th Oct 07:30 AM');
      expect(order.formattedDeliverySchedule, isNot(contains('22nd Oct')));
    });

    test('Return order ignores the forward customer, schedule, and notes', () {
      final json = {
        'id': 'order_return_forward',
        'order_number': 'NOMO_ORD-500',
        'flow_type': 'return',
        'status': 'in_transit_to_iap',
        'pickup_confirmed_at': '2026-10-01T10:00:00Z',
        'customer_name': 'Forward Customer',
        'customer_mobile': '9000000000',
        'order_note': 'forward delivery note',
        'notes': 'forward delivery note',
        'instructions': 'Leave at the door',
        'delivery_date': '2026-10-22',
        'delivery_time': '12:00 PM - 03:00 PM',
        'pickup_details': {
          'name': 'Return Customer',
          'mobile': '8888888888',
          'pickup_date': '2026-10-15',
          'pickup_time': '09:00 AM',
          'note': 'pick up the return kit',
        },
      };

      final order = DpOrder.fromJson(json);

      expect(order.customerName, 'Return Customer');
      expect(order.customerPhone, '8888888888');
      expect(order.displayNotes, 'pick up the return kit');
      expect(order.formattedDeliverySchedule, contains('15th Oct'));
      expect(order.formattedDeliverySchedule, isNot(contains('22nd Oct')));
      expect(order.journey.statusBadgeLabel, 'En Route to Customer Location');
    });
  });
}
