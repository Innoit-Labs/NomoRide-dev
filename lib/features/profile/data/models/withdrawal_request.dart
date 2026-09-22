class WithdrawalRequest {
  const WithdrawalRequest({
    required this.id,
    required this.amount,
    required this.status,
    required this.payTo,
    this.notes,
    this.orderIds = const [],
    this.upiId,
    this.bankAccountNumber,
    this.bankIfsc,
    this.bankAccountName,
    this.createdAt,
  });

  final String id;
  final double amount;
  final String status;
  final String payTo;
  final String? notes;
  final List<String> orderIds;
  final String? upiId;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? bankAccountName;
  final DateTime? createdAt;

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequest(
      id: json['id']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      status: json['status']?.toString() ?? 'pending',
      payTo: json['payTo']?.toString() ?? json['pay_to']?.toString() ?? '',
      notes: json['notes']?.toString(),
      orderIds: _readOrderIds(json),
      upiId: json['upi_id']?.toString() ?? json['upiId']?.toString(),
      bankAccountNumber: json['bank_account_number']?.toString() ??
          json['bankAccountNumber']?.toString(),
      bankIfsc: json['bank_ifsc']?.toString() ?? json['bankIfsc']?.toString(),
      bankAccountName: json['bank_account_name']?.toString() ??
          json['bankAccountName']?.toString(),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  static List<String> _readOrderIds(Map<String, dynamic> json) {
    final raw = json['order_ids'] ?? json['orderIds'];
    if (raw is List) {
      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    }

    final single = json['order_id'] ?? json['orderId'];
    final text = single?.toString().trim();
    if (text != null && text.isNotEmpty) return [text];
    return const [];
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
