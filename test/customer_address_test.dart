import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';

void main() {
  const real =
      'pragathi nagar, 23-138/1, Hmt Sathavahana Nagar, Kukatpally, Hyderabad';

  Map<String, dynamic> base(Map<String, dynamic> extra) => {
        'id': 'o1',
        'order_number': 'NOMO_ORD-1',
        'flow_type': 'delivery',
        'pickup_address': 'Metro Station Miyapur, Hyderabad',
        ...extra,
      };

  test('placeholder drop address falls back to delivery_address_json', () {
    final order = DpOrder.fromJson(base({
      'delivery_address': 'Customer Address',
      'delivery_address_json': '{"full_address": "$real"}',
    }));
    expect(order.dropAddress, real);
  });

  test('placeholder variant with pincode falls back to snapshot', () {
    final order = DpOrder.fromJson(base({
      'delivery_address': 'Customer Address - 500072',
      'delivery_address_snapshot': real,
    }));
    expect(order.dropAddress, real);
  });

  test('falls back to customer saved addresses', () {
    final order = DpOrder.fromJson(base({
      'delivery_address': 'customer_address',
      'customer': {
        'name': 'kphb',
        'addresses': [
          {'address_line1': 'pragathi nagar', 'city': 'Hyderabad'},
        ],
      },
    }));
    expect(order.dropAddress, 'pragathi nagar, Hyderabad');
  });

  test('placeholder parts are dropped from structured address', () {
    final order = DpOrder.fromJson(base({
      'delivery_address': {
        'address': 'Customer Address',
        'buildingNumber': '23-138/1',
        'city': 'Hyderabad',
        'pincode': '500072',
      },
    }));
    expect(order.dropAddress, '23-138/1, Hyderabad - 500072');
  });

  test('placeholder is never shown when no real address exists', () {
    final order = DpOrder.fromJson(base({'delivery_address': 'Customer Address'}));
    expect(order.dropAddress, isNull);
  });

  test('finds address under an unlisted key without picking the hub', () {
    final order = DpOrder.fromJson(base({
      'delivery_address': 'Customer Address',
      'order': {
        'iap_address': 'IAP Hub, Miyapur',
        'customer_delivery_address_text': real,
      },
    }));
    expect(order.dropAddress, real);
  });

  test('real drop address is kept as-is', () {
    final order = DpOrder.fromJson(base({'delivery_address': real}));
    expect(order.dropAddress, real);
  });
}
