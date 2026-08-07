import 'package:nomoride/features/home/data/models/dp_order.dart';

class MyOrdersData {
  const MyOrdersData({
    this.completedOrders = const [],
    this.inTransitOrders = const [],
  });

  final List<DpOrder> completedOrders;
  final List<DpOrder> inTransitOrders;

  List<DpOrder> get allOrders => [...inTransitOrders, ...completedOrders];

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
    );
  }

  static List<DpOrder> _parseOrders(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map<String, dynamic>>()
        .map(DpOrder.fromJson)
        .where(
          (order) =>
              order.orderNumber.isNotEmpty &&
              order.id != null &&
              order.id!.isNotEmpty,
        )
        .toList();
  }
}
