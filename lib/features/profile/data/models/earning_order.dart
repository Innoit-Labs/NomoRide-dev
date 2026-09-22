class EarningOrder {
  const EarningOrder({
    required this.id,
    required this.orderNumber,
    required this.packageType,
    required this.status,
    required this.partnerEarning,
    required this.paymentStatus,
    this.createdAt,
    this.deliveredAt,
    this.completedAt,
  });

  final String id;
  final String orderNumber;
  final String packageType;
  final String status;
  final double partnerEarning;
  final String paymentStatus;
  final DateTime? createdAt;
  final DateTime? deliveredAt;
  final DateTime? completedAt;

  bool get isPaymentPending => paymentStatus.toLowerCase() == 'pending';

  bool get isWithdrawalRequested {
    final value = paymentStatus.toLowerCase();
    return value == 'requested' || value == 'withdrawal_requested';
  }

  bool get isPaymentCompleted {
    final value = paymentStatus.toLowerCase();
    return value == 'paid' ||
        value == 'completed' ||
        value == 'settled' ||
        value == 'paid_out';
  }

  bool get canWithdraw => isPaymentPending;

  String get displayOrderType {
    final type = packageType.toLowerCase();
    if (type.contains('return')) return 'Return';
    return 'Delivery';
  }

  String get displayPaymentStatus {
    switch (paymentStatus.toLowerCase()) {
      case 'pending':
        return 'Payment Pending';
      case 'requested':
      case 'withdrawal_requested':
        return 'Withdrawal Requested';
      case 'paid':
      case 'paid_out':
      case 'settled':
      case 'completed':
        return 'Paid';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return _titleCase(paymentStatus.replaceAll('_', ' '));
    }
  }

  String get formattedDate {
    final date = createdAt;
    if (date == null) return 'Date not available';

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = weekdays[date.weekday - 1];
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour =
        date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$weekday, $day/$month/$year , $hour:$minute $period';
  }

  EarningOrder copyWith({
    String? id,
    String? orderNumber,
    String? packageType,
    String? status,
    double? partnerEarning,
    String? paymentStatus,
    DateTime? createdAt,
    DateTime? deliveredAt,
    DateTime? completedAt,
  }) {
    return EarningOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      packageType: packageType ?? this.packageType,
      status: status ?? this.status,
      partnerEarning: partnerEarning ?? this.partnerEarning,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(' ')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  factory EarningOrder.fromJson(Map<String, dynamic> json) {
    return EarningOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ??
          json['orderNumber']?.toString() ??
          '',
      packageType: json['package_type']?.toString() ??
          json['packageType']?.toString() ??
          '',
      status: json['status']?.toString() ?? '',
      partnerEarning: _toDouble(
        json['partner_earning'] ?? json['partnerEarning'],
      ),
      paymentStatus: json['payment_status']?.toString() ??
          json['paymentStatus']?.toString() ??
          'pending',
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
      deliveredAt: _parseDate(json['delivered_at'] ?? json['deliveredAt']),
      completedAt: _parseDate(json['completed_at'] ?? json['completedAt']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
