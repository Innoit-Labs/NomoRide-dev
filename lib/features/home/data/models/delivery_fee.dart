import 'dart:math' as math;

/// Resolves the partner-facing delivery fee from the order payload.
///
/// Distance pricing wins when the API sends a per-km rate and a distance
/// (or pickup/drop coordinates). Otherwise the explicit delivery-fee fields
/// are used ahead of a generic order amount.
class DeliveryFee {
  DeliveryFee._();

  static String? formatFromJson(
    Map<String, dynamic> json, {
    double? pickupLatitude,
    double? pickupLongitude,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) {
    final amount = resolve(
      json,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
    );
    if (amount == null || amount <= 0) return null;
    return amount.toStringAsFixed(2);
  }

  static double? resolve(
    Map<String, dynamic> json, {
    double? pickupLatitude,
    double? pickupLongitude,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) {
    final sources = _sources(json);
    final distanceKm = _distanceKm(
      sources,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
    );
    final perKm = _find(sources, _perKmKeys);
    final calculated = _fromDistance(
      distanceKm: distanceKm,
      perKm: perKm,
      base: _find(sources, _baseKeys),
      includedKm: _find(sources, _includedKmKeys) ?? 0,
      minimum: _find(sources, _minimumKeys),
    );
    if (calculated != null && calculated > 0) return calculated;

    final explicit = _find(sources, _explicitFeeKeys) ??
        _find([json], _amountKeys);
    if (explicit == null || explicit <= 0) return null;
    return _roundMoney(explicit);
  }

  static double? _fromDistance({
    required double? distanceKm,
    required double? perKm,
    required double? base,
    required double includedKm,
    required double? minimum,
  }) {
    if (distanceKm == null || distanceKm <= 0) return null;
    if (perKm == null || perKm <= 0) return null;

    final extraKm = math.max(0, distanceKm - includedKm);
    var fee = (base ?? 0) + (extraKm * perKm);
    if (minimum != null && minimum > fee) fee = minimum;
    return _roundMoney(fee);
  }

  static double? _distanceKm(
    List<Map<String, dynamic>> sources, {
    double? pickupLatitude,
    double? pickupLongitude,
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) {
    final fromApi = _find(sources, _distanceKeys);
    if (fromApi != null && fromApi > 0) return fromApi;

    if (pickupLatitude == null ||
        pickupLongitude == null ||
        deliveryLatitude == null ||
        deliveryLongitude == null) {
      return null;
    }

    final km = _haversineKm(
      pickupLatitude,
      pickupLongitude,
      deliveryLatitude,
      deliveryLongitude,
    );
    if (km < 0.05) return null;
    return km;
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthKm = 6371.0;
    double rad(double degrees) => degrees * math.pi / 180.0;
    final dLat = rad(lat2 - lat1);
    final dLon = rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthKm * c;
  }

  static List<Map<String, dynamic>> _sources(Map<String, dynamic> json) {
    final sources = <Map<String, dynamic>>[json];

    void addMap(dynamic value) {
      if (value is Map) {
        sources.add(value.map((key, val) => MapEntry(key.toString(), val)));
      }
    }

    for (final key in const [
      'pricing',
      'fare',
      'charges',
      'delivery_pricing',
      'deliveryPricing',
      'fee_breakdown',
      'feeBreakdown',
      'earning',
      'summary',
      'payment',
    ]) {
      addMap(json[key]);
    }

    final items = json['items'] ?? json['orderItems'] ?? json['order_items'];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        final map = item.map((key, value) => MapEntry(key.toString(), value));
        addMap(map['kitDetails'] ?? map['kit_details']);
      }
    }

    return sources;
  }

  static double? _find(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final key in keys) {
      final wanted = _normalizeKey(key);
      for (final source in sources) {
        for (final entry in source.entries) {
          if (_normalizeKey(entry.key) != wanted) continue;
          final value = _asDouble(entry.value);
          if (value != null && value > 0) return value;
        }
      }
    }
    return null;
  }

  static String _normalizeKey(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[\s-]'), '_');

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is! String) return null;
    final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') return null;
    return double.tryParse(cleaned);
  }

  static double _roundMoney(double value) => (value * 100).round() / 100;

  static const _distanceKeys = [
    'distance_km',
    'distanceKm',
    'delivery_distance',
    'deliveryDistance',
    'distance_in_km',
    'total_distance_km',
    'route_distance_km',
  ];

  static const _perKmKeys = [
    'per_km',
    'perKm',
    'price_per_km',
    'pricePerKm',
    'rate_per_km',
    'ratePerKm',
    'per_km_charge',
    'perKmCharge',
    'charge_per_km',
    'additional_per_km',
    'additionalPerKm',
  ];

  static const _baseKeys = [
    'base_fee',
    'baseFee',
    'base_charge',
    'baseCharge',
    'base_price',
    'basePrice',
    'flag_fall',
  ];

  static const _includedKmKeys = [
    'included_km',
    'includedKm',
    'base_km',
    'baseKm',
    'free_km',
    'freeKm',
  ];

  static const _minimumKeys = [
    'min_charge',
    'minimum_charge',
    'minimumCharge',
    'min_delivery_fee',
    'minimum_fee',
  ];

  static const _explicitFeeKeys = [
    'distance_based_fee',
    'distanceBasedFee',
    'calculated_delivery_fee',
    'calculatedDeliveryFee',
    'delivery_fee',
    'deliveryFee',
    'delivery_charge',
    'deliveryCharge',
    'partner_earning',
    'partnerEarning',
    'earning_amount',
    'earningAmount',
    'formatted_earning',
    'formattedEarning',
  ];

  static const _amountKeys = [
    'amount',
    'price',
    'totalAmount',
    'total_value',
  ];
}
