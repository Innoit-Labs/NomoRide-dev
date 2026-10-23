import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/features/orders/data/models/my_orders_data.dart';

void main() {
  test('failedOrders join the existing My Orders buckets', () {
    final data = MyOrdersData.fromJson({
      'intransist_orders': [
        {
          'id': 'dp-1',
          'order_number': 'ORD-1001',
          'status': 'in_transit',
          'flow_type': 'delivery',
        },
      ],
      'completedOrders': [
        {
          'id': 'dp-2',
          'order_number': 'ORD-998',
          'status': 'delivered',
          'flow_type': 'delivery',
        },
        {
          'id': 'dp-rto',
          'order_number': 'ORD-997',
          'status': 'returned_to_iap',
          'flow_type': 'delivery',
          'orderStatus': 'NOT_DELIVERED',
        },
      ],
      'failedOrders': [
        {
          'id': 'dp-3',
          'order_number': 'ORD-1005',
          'status': 'not_delivered',
          'orderStatus': 'RETURN_FAILED',
          'flow_type': 'delivery',
          'is_pickup_failed': true,
          'failure_type': 'PICKUP_FAILED',
        },
        {
          'id': 'dp-4',
          'order_number': 'ORD-1004',
          'status': 'not_delivered',
          'orderStatus': 'NOT_DELIVERED',
          'flow_type': 'delivery',
          'is_delivery_failed': true,
          'failure_type': 'DELIVERY_FAILED',
        },
      ],
    });

    expect(data.allOrders.map((order) => order.orderNumber), [
      'ORD-1001',
      'ORD-998',
      'ORD-997',
      'ORD-1005',
      'ORD-1004',
    ]);

    final pickup = data.failedOrders.first;
    expect(pickup.isReturnFailed, isTrue);

    final deliveryFailed = data.failedOrders.last;
    expect(deliveryFailed.isNotDelivered, isTrue);
    expect(deliveryFailed.isReturnFailed, isFalse);

    final rtoDone = data.completedOrders.last;
    expect(rtoDone.isNotDelivered, isTrue);
    expect(rtoDone.isReturnFailed, isFalse);
  });
}
