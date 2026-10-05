class OrderBroadcastModel {
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

  const OrderBroadcastModel({
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
  });

  factory OrderBroadcastModel.fromJson(Map<String, dynamic> json) {
    double parsedEarning = 0.0;
    final rawEarning = json['earning_amount'] ?? json['earningAmount'];
    if (rawEarning is num) {
      parsedEarning = rawEarning.toDouble();
    } else if (rawEarning is String) {
      parsedEarning = double.tryParse(rawEarning) ?? 0.0;
    }

    String formatted = (json['formatted_earning'] ?? json['formattedEarning'] ?? '').toString().trim();
    if (formatted.isEmpty) {
      formatted = '₹${parsedEarning.toStringAsFixed(2)}';
    }

    int timer = 30;
    final rawTimer = json['timer_seconds'] ?? json['timerSeconds'];
    if (rawTimer is num) {
      timer = rawTimer.toInt();
    } else if (rawTimer is String) {
      timer = int.tryParse(rawTimer) ?? 30;
    }

    DateTime? expires;
    final rawExpires = json['expires_at'] ?? json['expiresAt'];
    if (rawExpires != null) {
      try {
        expires = DateTime.parse(rawExpires.toString());
        final diff = expires.difference(DateTime.now()).inSeconds;
        if (diff > 0 && diff <= 60) {
          timer = diff;
        }
      } catch (_) {}
    }

    // Delivery partner broadcast acceptance window is strictly 30 seconds (Uber/Swiggy style).
    // If backend sends order lifetime (e.g. 1800s / 30m) or invalid <= 0, cap to 30.
    if (timer > 60 || timer <= 0) {
      timer = 30;
    }

    double? parseCoord(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return OrderBroadcastModel(
      orderId: (json['order_id'] ?? json['orderId'] ?? json['id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? json['orderNumber'] ?? '').toString(),
      flowType: (json['flow_type'] ?? json['flowType'] ?? 'delivery').toString(),
      packageType: (json['package_type'] ?? json['packageType'] ?? 'standard').toString(),
      earningAmount: parsedEarning,
      formattedEarning: formatted,
      pickupAddress: (json['pickup_address'] ?? json['pickupAddress'] ?? 'Pickup Location').toString(),
      pickupLatitude: parseCoord(json['pickup_latitude'] ?? json['pickupLatitude']),
      pickupLongitude: parseCoord(json['pickup_longitude'] ?? json['pickupLongitude']),
      deliveryAddress: (json['delivery_address'] ?? json['deliveryAddress'] ?? 'Delivery Location').toString(),
      deliveryLatitude: parseCoord(json['delivery_latitude'] ?? json['deliveryLatitude']),
      deliveryLongitude: parseCoord(json['delivery_longitude'] ?? json['deliveryLongitude']),
      customerName: (json['customer_name'] ?? json['customerName'] ?? '').toString(),
      customerMobile: (json['customer_mobile'] ?? json['customerMobile'] ?? '').toString(),
      timerSeconds: timer,
      expiresAt: expires,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
