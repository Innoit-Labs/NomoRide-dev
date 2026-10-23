import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/features/orders/data/models/order_broadcast_model.dart';

void main() {
  Map<String, dynamic> base(Map<String, dynamic> extra) => {
        'order_id': 'o1',
        'order_number': 'NOMO_ORD-1',
        ...extra,
      };

  test('reads nested distance.kmd such as 17km', () {
    final nested = OrderBroadcastModel.fromJson(base({
      'distance': {'kmd': '17km'},
    }));
    expect(nested.distanceKm, 17);

    final encoded = OrderBroadcastModel.fromJson(base({
      'distance': '{"kmd":"17km"}',
    }));
    expect(encoded.distanceKm, 17);

    final flat = OrderBroadcastModel.fromJson(base({
      'distance.kmd': '17km',
    }));
    expect(flat.distanceKm, 17);
    expect(flat.formattedDistance, '17.0 km');
  });

  test('reads broadcast_sound_url and playDurationSeconds', () {
    final b = OrderBroadcastModel.fromJson(base({
      'broadcast_sound_url': 'https://cdn.example.com/alert.mp3',
      'playDurationSeconds': 15,
    }));
    expect(b.soundUrl, 'https://cdn.example.com/alert.mp3');
    expect(b.soundDurationSeconds, 15);
  });

  test('reads the FCM data field names', () {
    final b = OrderBroadcastModel.fromJson(base({
      'type': 'BROADCAST_ORDER',
      'sound_url': 'https://cdn.example.com/a.mp3',
      'song_url': 'https://cdn.example.com/a.mp3',
      'play_duration_seconds': '30',
      'duration': '30',
    }));
    expect(b.soundUrl, 'https://cdn.example.com/a.mp3');
    expect(b.soundDurationSeconds, 30);
  });

  test('accepts the duration as a string', () {
    final b = OrderBroadcastModel.fromJson(base({
      'broadcast_sound_url': 'https://cdn.example.com/alert.mp3',
      'playDurationSeconds': '20',
    }));
    expect(b.soundDurationSeconds, 20);
  });

  test('ignores missing, invalid or non-positive values', () {
    final b = OrderBroadcastModel.fromJson(base({
      'broadcast_sound_url': 'not a url',
      'playDurationSeconds': 0,
    }));
    expect(b.soundUrl, isNull);
    expect(b.soundDurationSeconds, isNull);
    expect(OrderBroadcastModel.fromJson(base({})).soundUrl, isNull);
  });
}
