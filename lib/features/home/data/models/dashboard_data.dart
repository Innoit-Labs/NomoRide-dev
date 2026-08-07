class DashboardData {
  const DashboardData({
    required this.totalOrders,
    required this.completedOrders,
  });

  final int totalOrders;
  final int completedOrders;

  int get activeOrders {
    final active = totalOrders - completedOrders;
    return active < 0 ? 0 : active;
  }

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalOrders: _readInt(
        json['totalOrders'] ?? json['totlaOrders'] ?? json['total_orders'],
      ),
      completedOrders: _readInt(
        json['completedOrders'] ?? json['completed_orders'],
      ),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
