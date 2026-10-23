import 'dart:convert';
import 'dart:math' as math;
import 'package:nomoride/features/home/data/models/delivery_fee.dart';

class OrderBroadcastModel {
  final String broadcastId;
  final String orderId;
  final String orderNumber;
  final String flowType;
  final String packageType;
  final double earningAmount;
  final String formattedEarning;
  final String pickupAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String deliveryAddress;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String customerName;
  final String customerMobile;
  final int timerSeconds;
  final DateTime? expiresAt;
  final double? distanceKm;
  final int? itemCount;
  final String? kitDetails;
  final String? soundUrl;
  final int? soundDurationSeconds;

  const OrderBroadcastModel({
    String? broadcastId,
    required this.orderId,
    required this.orderNumber,
    required this.flowType,
    required this.packageType,
    required this.earningAmount,
    required this.formattedEarning,
    required this.pickupAddress,
    this.pickupLatitude,
    this.pickupLongitude,
    required this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    required this.customerName,
    required this.customerMobile,
    this.timerSeconds = 30,
    this.expiresAt,
    this.distanceKm,
    this.itemCount,
    this.kitDetails,
    this.soundUrl,
    this.soundDurationSeconds,
  }) : broadcastId = (broadcastId != null && broadcastId != '') ? broadcastId : orderId;

  String get uniqueId => broadcastId.isNotEmpty ? broadcastId : orderId;

  String? get formattedDistance {
    if (distanceKm == null || distanceKm! <= 0) return null;
    return '${distanceKm!.toStringAsFixed(1)} km';
  }

  String? get itemsCountLabel {
    if (itemCount != null && itemCount! > 0) {
      return '$itemCount ${itemCount == 1 ? "Item" : "Items"}';
    }
    return null;
  }

  String? get kitDetailsLabel {
    if (kitDetails != null && kitDetails!.trim().isNotEmpty && kitDetails!.toLowerCase() != 'standard') {
      return kitDetails!.trim();
    }
    return null;
  }

  static double calculateDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthKm = 6371.0;
    double rad(double deg) => deg * math.pi / 180.0;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthKm * c;
  }

  factory OrderBroadcastModel.fromJson(Map<String, dynamic> json) {
    final nested = json['broadcast'];
    if (nested is Map &&
        (json['order_id'] ?? json['orderId']) == null) {
      json = nested.map((key, value) => MapEntry(key.toString(), value));
    }

    double? parseCoord(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    final pickupLatitude = parseCoord(json['pickup_latitude'] ?? json['pickupLatitude']);
    final pickupLongitude = parseCoord(json['pickup_longitude'] ?? json['pickupLongitude']);
    final deliveryLatitude = parseCoord(json['delivery_latitude'] ?? json['deliveryLatitude']);
    final deliveryLongitude = parseCoord(json['delivery_longitude'] ?? json['deliveryLongitude']);

    final resolvedFee = DeliveryFee.formatFromJson(
      json,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
    );
    final parsedEarning = double.tryParse(resolvedFee ?? '') ?? 0.0;
    final formatted = resolvedFee == null ? '₹0.00' : '₹$resolvedFee';

    // Parse distance
    double? parseDistance(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return _kilometers(val);
      if (val is Map) return _readNestedDistance(val);
      return null;
    }
    double? parsedDistance = parseDistance(
      json['distance_km'] ??
          json['distanceKm'] ??
          json['delivery_distance'] ??
          json['deliveryDistance'] ??
          json['distance_in_km'] ??
          json['total_distance_km'] ??
          json['route_distance_km'] ??
          json['kmd'] ??
          json['distance.kmd'],
    );
    parsedDistance ??= _readNestedDistance(json['distance']);
    if ((parsedDistance == null || parsedDistance <= 0) &&
        pickupLatitude != null &&
        pickupLongitude != null &&
        deliveryLatitude != null &&
        deliveryLongitude != null) {
      parsedDistance = calculateDistanceKm(
        lat1: pickupLatitude,
        lon1: pickupLongitude,
        lat2: deliveryLatitude,
        lon2: deliveryLongitude,
      );
    }

    // Parse items count
    int? parsedItemCount;
    final rawCount = json['item_count'] ??
        json['itemCount'] ??
        json['total_items'] ??
        json['totalItems'] ??
        json['items_count'];
    if (rawCount is num) {
      parsedItemCount = rawCount.toInt();
    } else if (rawCount is String) {
      parsedItemCount = int.tryParse(rawCount);
    } else if (json['items'] is List) {
      parsedItemCount = (json['items'] as List).length;
    }

    // Parse kit details
    String? parsedKit;
    final rawKit = json['kit_details'] ??
        json['kitDetails'] ??
        json['kit_type'] ??
        json['kitType'];
    if (rawKit is Map) {
      parsedKit = (rawKit['kit_type'] ??
              rawKit['kitType'] ??
              rawKit['name'] ??
              rawKit['cart_section'] ??
              '')
          .toString();
    } else if (rawKit != null) {
      parsedKit = rawKit.toString();
    }
    if ((parsedKit == null || parsedKit.isEmpty) && json['package_type'] != null) {
      parsedKit = json['package_type'].toString();
    }

    int timer = 30;
    final rawTimer = json['timer_seconds'] ?? json['timerSeconds'];
    if (rawTimer is num) {
      timer = rawTimer.toInt();
    } else if (rawTimer is String) {
      timer = int.tryParse(rawTimer) ?? 30;
    } else {
      final rawMinutes = json['expiry_minutes'] ?? json['expiryMinutes'];
      final minutes = rawMinutes is num
          ? rawMinutes.toInt()
          : int.tryParse(rawMinutes?.toString() ?? '');
      if (minutes != null && minutes > 0) timer = minutes * 60;
    }

    DateTime? expires;
    final rawExpires = json['expires_at'] ?? json['expiresAt'];
    if (rawExpires != null) {
      try {
        expires = DateTime.parse(rawExpires.toString());
        final diff = expires.difference(DateTime.now()).inSeconds;
        if (diff > 0) timer = diff;
      } catch (_) {}
    }

    if (timer <= 0) timer = 30;

    final broadcastId = (json['broadcast_id'] ??
            json['broadcastId'] ??
            json['order_id'] ??
            json['orderId'] ??
            json['id'] ??
            '')
        .toString();

    return OrderBroadcastModel(
      broadcastId: broadcastId,
      orderId: (json['order_id'] ?? json['orderId'] ?? json['id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? json['orderNumber'] ?? '').toString(),
      flowType: (json['flow_type'] ?? json['flowType'] ?? 'delivery').toString(),
      packageType: (json['package_type'] ?? json['packageType'] ?? 'standard').toString(),
      earningAmount: parsedEarning,
      formattedEarning: formatted,
      pickupAddress: (json['pickup_address'] ?? json['pickupAddress'] ?? 'Pickup Location').toString(),
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      deliveryAddress: (json['delivery_address'] ?? json['deliveryAddress'] ?? 'Delivery Location').toString(),
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      customerName: (json['customer_name'] ?? json['customerName'] ?? '').toString(),
      customerMobile: (json['customer_mobile'] ?? json['customerMobile'] ?? '').toString(),
      timerSeconds: timer,
      expiresAt: expires,
      distanceKm: parsedDistance,
      itemCount: parsedItemCount,
      kitDetails: parsedKit,
      soundUrl: _readHttpUrl(
        json['broadcast_sound_url'] ??
            json['broadcastSoundUrl'] ??
            json['sound_url'] ??
            json['soundUrl'] ??
            json['song_url'] ??
            json['songUrl'],
      ),
      soundDurationSeconds: _readPositiveInt(
        json['playDurationSeconds'] ??
            json['play_duration_seconds'] ??
            json['duration'],
      ),
    );
  }

  static double? _readNestedDistance(dynamic value) {
    if (value is Map) {
      return _kilometers(
        value['kmd'] ??
            value['km'] ??
            value['distance_km'] ??
            value['distanceKm'] ??
            value['value'],
      );
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{')) {
        try {
          return _readNestedDistance(jsonDecode(trimmed));
        } catch (_) {}
      }
      return _kilometers(trimmed);
    }
    return _kilometers(value);
  }

  static double? _kilometers(dynamic value) {
    if (value is num) return value.toDouble();
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)')
        .firstMatch(value?.toString() ?? '');
    if (match == null) return null;
    final parsed = double.tryParse(match.group(1)!);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static String? _readHttpUrl(dynamic value) {
    final text = value?.toString().trim() ?? '';
    final uri = Uri.tryParse(text);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    return text;
  }

  static int? _readPositiveInt(dynamic value) {
    final parsed =
        value is num ? value.toInt() : int.tryParse(value?.toString().trim() ?? '');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'broadcast_id': broadcastId,
      'order_id': orderId,
      'order_number': orderNumber,
      'flow_type': flowType,
      'package_type': packageType,
      'earning_amount': earningAmount,
      'formatted_earning': formattedEarning,
      'pickup_address': pickupAddress,
      'pickup_latitude': pickupLatitude,
      'pickup_longitude': pickupLongitude,
      'delivery_address': deliveryAddress,
      'delivery_latitude': deliveryLatitude,
      'delivery_longitude': deliveryLongitude,
      'customer_name': customerName,
      'customer_mobile': customerMobile,
      'timer_seconds': timerSeconds,
      'expires_at': expiresAt?.toIso8601String(),
      'distance_km': distanceKm,
      'item_count': itemCount,
      'kit_details': kitDetails,
      'broadcast_sound_url': soundUrl,
      'playDurationSeconds': soundDurationSeconds,
    };
  }
}

class OrderDismissModel {
  final String orderId;
  final String? claimedByPartnerId;
  final String message;

  const OrderDismissModel({
    required this.orderId,
    this.claimedByPartnerId,
    required this.message,
  });

  factory OrderDismissModel.fromJson(Map<String, dynamic> json) {
    return OrderDismissModel(
      orderId: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      claimedByPartnerId: json['claimed_by_partner_id']?.toString(),
      message: (json['message'] ?? 'This order was accepted by another partner.').toString(),
    );
  }
}
