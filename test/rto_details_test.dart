import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';

void main() {
  DpOrder order(Map<String, dynamic> extra) => DpOrder.fromJson({
        'id': 'o1',
        'order_number': 'NOMO_ORD-468',
        'flow_type': 'delivery',
        ...extra,
      });

  final rtoPayload = {
    'status': 'not_delivered',
    'rejection_reason': 'Customer unavailable',
    'rto_status': 'RTO_INITIATED',
    'rto_amount': 100.0,
    'rto_details': {
      'amount': 100.0,
      'total_amount': 100.0,
      'forward_amount': 50.0,
      'return_amount': 50.0,
      'base_amount': 50.0,
      'drop_location': {
        'hub_name': 'IAP Hub Koramangala',
        'address': '12th Main',
        'full_address': '12th Main, Koramangala, Bengaluru',
        'city': 'Bengaluru',
        'latitude': 12.9352,
        'longitude': 77.6245,
        'contact_person': 'Hub Manager',
        'contact_mobile': '9876543210',
      },
      'drop_address': '12th Main, Koramangala, Bengaluru',
      'status': 'RTO_INITIATED',
      'rto_otp': '4821',
      'rto_notes': 'Customer unavailable',
    },
  };

  test('parses rto_details destination, otp, contact and earnings', () {
    final o = order(rtoPayload);

    expect(o.isRtoInitiated, isTrue);
    expect(o.isUndeliveredReturnToHub, isTrue);
    expect(o.isVisibleOnHomeAssigned, isTrue);
    expect(o.journey.isCompleted, isFalse);

    expect(o.rtoHubName, 'IAP Hub Koramangala');
    expect(o.rtoReturnAddress, contains('IAP Hub Koramangala'));
    expect(o.rtoReturnAddress, contains('Koramangala, Bengaluru'));
    expect(o.rtoReturnLatitude, 12.9352);
    expect(o.rtoReturnLongitude, 77.6245);
    expect(o.rtoHubContactPerson, 'Hub Manager');
    expect(o.rtoHubContactMobile, '9876543210');
    expect(o.rtoDisplayNotes, 'Customer unavailable');
    expect(o.rtoPartnerEarningDisplay, '100.00');
    expect(o.rtoDetails?.formattedForwardAmount, '50.00');
    expect(o.rtoDetails?.formattedReturnAmount, '50.00');
  });

  test('falls back to rto_drop_location when drop_location is empty', () {
    final o = order({
      'status': 'not_delivered',
      'rto_status': 'RTO_INITIATED',
      'rto_details': {
        'total_amount': 120.0,
        'forward_amount': 60.0,
        'return_amount': 60.0,
        'status': 'RTO_INITIATED',
        'rto_otp': '1111',
      },
      'rto_drop_location': {
        'hub_name': 'IAP Hub Miyapur',
        'full_address': 'Metro Station Miyapur',
        'latitude': 17.49,
        'longitude': 78.37,
      },
    });

    expect(o.rtoHubName, 'IAP Hub Miyapur');
    expect(o.rtoReturnAddress, contains('Miyapur'));
    expect(o.rtoReturnLatitude, 17.49);
    expect(o.rtoPartnerEarningDisplay, '120.00');
  });

  test('Delivery Failed with RTO_INITIATED is not treated as completed', () {
    final o = order({
      ...rtoPayload,
      'completed_at': '2026-10-16T07:01:17.000Z',
    });

    expect(o.isRtoInitiated, isTrue);
    expect(o.hasCompletedRtoHandover, isFalse);
    expect(o.isReturnedToIap, isFalse);
    expect(o.isVisibleOnHomeAssigned, isTrue);
  });

  test('RTO_COMPLETED after hub confirmation leaves home', () {
    final o = order({
      'status': 'not_delivered',
      'rto_status': 'RTO_COMPLETED',
      'rto_completed_at': '2026-10-16T07:01:17.000Z',
      'returned_to_iap_at': '2026-10-16T07:01:17.000Z',
      'rto_details': {
        'status': 'RTO_COMPLETED',
        'total_amount': 100.0,
      },
    });

    expect(o.isRtoCompleted, isTrue);
    expect(o.isReturnedToIap, isTrue);
    expect(o.isUndeliveredReturnToHub, isFalse);
    expect(o.isVisibleOnHomeAssigned, isFalse);
  });
}
