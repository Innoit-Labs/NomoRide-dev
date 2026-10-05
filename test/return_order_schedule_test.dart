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
  });
}
