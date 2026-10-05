import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/features/home/data/models/delivery_fee.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';

void main() {
  test('title follows flow_type for delivery and return', () {
    final delivery = DpOrder(
      orderNumber: 'NOMO_ORD-1',
      status: 'assigned',
      flowType: 'delivery',
      orderType: 'pickup',
    );
    final returns = DpOrder(
      orderNumber: 'NOMO_ORD-2',
      status: 'return_assigned',
      flowType: 'return',
      orderType: 'delivery',
    );
    final pickup = DpOrder(
      orderNumber: 'NOMO_ORD-3',
      status: 'assigned',
      flowType: 'pickup',
    );

    expect(delivery.displayTitle, 'Order Delivery');
    expect(delivery.usesDeliveryIcon, isTrue);
    expect(returns.displayTitle, 'Order Return');
    expect(returns.usesDeliveryIcon, isFalse);
    expect(pickup.displayTitle, 'Order Pickup');
  });

  test('fee uses per-km pricing instead of a flat amount', () {
    final formatted = DeliveryFee.formatFromJson({
      'amount': '36.00',
      'distance_km': 8,
      'base_fee': 20,
      'included_km': 2,
      'per_km': 8,
    });

    expect(formatted, '68.00');
  });

  test('fee prefers delivery charge over a generic amount', () {
    final formatted = DeliveryFee.formatFromJson({
      'amount': '36.00',
      'delivery_charge': 96,
    });

    expect(formatted, '96.00');
  });

  test('fee is calculated from pickup and drop coordinates', () {
    final formatted = DeliveryFee.formatFromJson(
      {
        'amount': '36.00',
        'base_fee': 30,
        'per_km': 10,
      },
      pickupLatitude: 17.4948,
      pickupLongitude: 78.3996,
      deliveryLatitude: 17.4458,
      deliveryLongitude: 78.3980,
    );

    expect(formatted, isNot('36.00'));
    expect(double.parse(formatted!), greaterThan(30));
  });
}
