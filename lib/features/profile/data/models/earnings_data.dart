import 'package:nomoride/features/profile/data/models/earning_order.dart';

class EarningsData {
  const EarningsData({
    required this.totalEarnings,
    required this.paidOut,
    required this.pending,
    required this.availableBalance,
    required this.orders,
  });

  final double totalEarnings;
  final double paidOut;
  final double pending;
  final double availableBalance;
  final List<EarningOrder> orders;

  factory EarningsData.fromJson(Map<String, dynamic> json) {
    final ordersRaw = json['orders'];
    final orders = ordersRaw is List
        ? ordersRaw
            .whereType<Map>()
            .map(
              (item) => EarningOrder.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .where((order) => order.id.isNotEmpty)
            .toList()
        : <EarningOrder>[];

    final pending = _toDouble(json['pending']);
    final availableBalance = _toDouble(
      json['availableBalance'] ?? json['available_balance'] ?? pending,
    );

    return EarningsData(
      totalEarnings: _toDouble(json['totalEarnings'] ?? json['total_earnings']),
      paidOut: _toDouble(json['paidOut'] ?? json['paid_out']),
      pending: pending,
      availableBalance: availableBalance,
      orders: orders,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
