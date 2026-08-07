import 'package:nomoride/features/profile/data/models/earning_order.dart';

class EarningsData {
  const EarningsData({
    required this.totalEarnings,
    required this.paidOut,
    required this.pending,
    required this.orders,
  });

  final double totalEarnings;
  final double paidOut;
  final double pending;
  final List<EarningOrder> orders;

  factory EarningsData.fromJson(Map<String, dynamic> json) {
    final ordersRaw = json['orders'];
    final orders = ordersRaw is List
        ? ordersRaw
            .whereType<Map<String, dynamic>>()
            .map(EarningOrder.fromJson)
            .where((order) => order.id.isNotEmpty)
            .toList()
        : <EarningOrder>[];

    return EarningsData(
      totalEarnings: _toDouble(json['totalEarnings'] ?? json['total_earnings']),
      paidOut: _toDouble(json['paidOut'] ?? json['paid_out']),
      pending: _toDouble(json['pending']),
      orders: orders,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
