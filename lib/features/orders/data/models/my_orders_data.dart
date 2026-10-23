import 'package:nomoride/features/home/data/models/dp_order.dart';

class MyOrdersData {
  const MyOrdersData({
    this.completedOrders = const [],
    this.inTransitOrders = const [],
    this.failedOrders = const [],
  });

  final List<DpOrder> completedOrders;
  final List<DpOrder> inTransitOrders;
  final List<DpOrder> failedOrders;

  /// In-transit, completed, then failed. Duplicate ids keep the first copy.
  List<DpOrder> get allOrders {
    final seen = <String>{};
    final merged = <DpOrder>[];
    for (final order in [
      ...inTransitOrders,
      ...completedOrders,
      ...failedOrders,
    ]) {
      final key = (order.id != null && order.id!.isNotEmpty)
          ? order.id!
          : order.orderNumber;
      if (key.isEmpty || !seen.add(key)) continue;
      merged.add(order);
    }
    return merged;
  }

  factory MyOrdersData.fromJson(Map<String, dynamic> json) {
    return MyOrdersData(
      completedOrders: _parseOrders(
        json['completedOrders'] ?? json['completed_orders'],
      ),
      inTransitOrders: _parseOrders(
        json['intransist_orders'] ??
            json['in_transit_orders'] ??
            json['inTransitOrders'],
      ),
      failedOrders: _parseOrders(
        json['failedOrders'] ?? json['failed_orders'],
      ),
    );
  }

  static List<DpOrder> _parseOrders(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((e) => DpOrder.fromJson(_withFailureHints(
              e.map((k, v) => MapEntry(k.toString(), v)),
            )))
        .where(
          (order) =>
              order.orderNumber.isNotEmpty &&
              order.id != null &&
              order.id!.isNotEmpty,
        )
        .toList();
  }

  /// Maps `is_pickup_failed` / `is_delivery_failed` / `failure_type` onto the
  /// parent status the existing My Orders tabs already read.
  static Map<String, dynamic> _withFailureHints(Map<String, dynamic> json) {
    final failureType = (json['failure_type'] ?? json['failureType'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final pickupFailed = json['is_pickup_failed'] == true ||
        json['isPickupFailed'] == true ||
        failureType == 'PICKUP_FAILED';
    final deliveryFailed = json['is_delivery_failed'] == true ||
        json['isDeliveryFailed'] == true ||
        failureType == 'DELIVERY_FAILED';
    if (!pickupFailed && !deliveryFailed) return json;

    final copy = Map<String, dynamic>.from(json);
    final parent = (copy['orderStatus'] ??
            copy['order_status'] ??
            copy['parent_order_status'] ??
            copy['parentOrderStatus'] ??
            '')
        .toString()
        .trim();
    if (parent.isEmpty) {
      copy['orderStatus'] = pickupFailed ? 'RETURN_FAILED' : 'NOT_DELIVERED';
    }
    final status = (copy['status'] ?? '').toString().trim();
    if (status.isEmpty) copy['status'] = 'not_delivered';
    return copy;
  }
}
