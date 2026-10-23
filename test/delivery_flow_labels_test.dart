import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';

void main() {
  DpOrder order(String flowType, String status) => DpOrder.fromJson({
        'id': 'o1',
        'order_number': 'NOMO_ORD-450',
        'status': status,
        'flow_type': flowType,
        'package_type': 'parcel',
      });

  test('delivery flow stays a delivery during the hub leg', () {
    for (final status in ['assigned', 'accepted', 'in_transit_to_iap']) {
      final o = order('delivery', status);
      expect(o.isReturnFlow, isFalse, reason: status);
      expect(o.isDeliveryOrderCard, isTrue, reason: status);
    }
  });

  test('return flow is never a delivery card', () {
    final o = order('return', 'in_transit_to_iap');
    expect(o.isReturnFlow, isTrue);
    expect(o.isDeliveryOrderCard, isFalse);
  });
}
