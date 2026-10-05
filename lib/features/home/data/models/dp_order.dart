import 'dart:convert';

import 'package:nomoride/features/home/data/models/dp_order_product.dart';
import 'package:nomoride/features/home/data/models/order_item_section.dart';
import 'package:nomoride/features/home/data/models/order_journey.dart';

class DpOrder {
  const DpOrder({
    required this.orderNumber,
    required this.status,
    this.id,
    this.flowType,
    this.stepLabels = const {},
    this.subStatus,
    this.orderType,
    this.packageType,
    this.customerName,
    this.customerPhone,
    this.products = const [],
    this.pickupAddress,
    this.dropAddress,
    this.scheduledTime,
    this.amount,
    this.description,
    this.notes,
    this.instructions,
    this.weightKg,
    this.pickupLatitude,
    this.pickupLongitude,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.arrivedAtIapAt,
    this.pickupConfirmedAt,
    this.inTransitAt,
    this.arrivedAtDeliveryAt,
    this.deliveredAt,
    this.completedAt,
    this.deliveryDate,
    this.deliveryTime,
    this.rejectionReason,
    this.waited10mins,
    this.pickupFailedImages = const [],
  });

  final String? id;
  final String orderNumber;
  final String status;
  final String? flowType;
  final Map<String, String> stepLabels;
  final String? subStatus;
  final String? orderType;
  final String? packageType;
  final String? customerName;
  final String? customerPhone;
  final List<DpOrderProduct> products;
  final String? pickupAddress;
  final String? dropAddress;
  final String? scheduledTime;
  final String? amount;
  final String? description;
  final String? notes;
  final String? instructions;
  final String? weightKg;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? arrivedAtIapAt;
  final String? pickupConfirmedAt;
  final String? inTransitAt;
  final String? arrivedAtDeliveryAt;
  final String? deliveredAt;
  final String? completedAt;
  final String? deliveryDate;
  final String? deliveryTime;
  final String? rejectionReason;
  final int? waited10mins;
  final List<String> pickupFailedImages;

  OrderFlow get journey => OrderFlow(this);

  bool get isReturnFlow {
    final flow = flowType?.toLowerCase().trim();
    if (flow == 'return') return true;
    if (flow == 'delivery') return false;

    final type = orderType?.toLowerCase().trim() ?? '';
    if (type.contains('return')) return true;

    final orderStatus = status.toLowerCase().trim();
    if (orderStatus == 'return_assigned' ||
        orderStatus == 'returned_to_iap' ||
        orderStatus.startsWith('return_')) {
      return true;
    }

    final sub = subStatus?.toLowerCase().trim() ?? '';
    if (sub.contains('return')) return true;

    return false;
  }

  @Deprecated('Use isReturnFlow')
  bool get isReturnOrder => isReturnFlow;

  /// Normalizes API status for safe comparisons (`not_delivered`, `Not Delivered`, etc.).
  String get normalizedStatus =>
      status.trim().toLowerCase().replaceAll(RegExp(r'[_\s]+'), ' ');

  /// Underscore API status key used for workflow transitions (`in_transit_to_iap`).
  String get apiStatusKey =>
      status.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  bool get isNotDelivered {
    final s = normalizedStatus;
    if (s == 'not delivered' ||
        s == 'not_delivered' ||
        s == 'failed' ||
        s == 'return failed' ||
        s == 'mark return as failed') {
      return true;
    }
    final reason = rejectionReason?.trim();
    if (reason != null &&
        reason.isNotEmpty &&
        reason.toLowerCase() != 'null') {
      return true;
    }
    if (pickupFailedImages.isNotEmpty) {
      return true;
    }
    return false;
  }

  bool get isRejectedStatus =>
      normalizedStatus == 'rejected' ||
      normalizedStatus == 'order rejected' ||
      normalizedStatus == 'order failed';

  /// Orders shown on Home → Orders Assigned (excludes completed and not delivered).
  bool get isVisibleOnHomeAssigned =>
      !isNotDelivered && normalizedStatus != 'completed';

  /// Resolves the action button label from API [stepLabels].
  String labelForStep({
    required String apiStatus,
    required int occurrence,
    String? currentStatus,
    bool preferCurrentStatus = false,
  }) {
    final keys = <String>[
      if (preferCurrentStatus &&
          currentStatus != null &&
          currentStatus.isNotEmpty)
        currentStatus,
      if (occurrence > 0) '${apiStatus}_$occurrence',
      if (occurrence > 0) '${apiStatus}_${occurrence + 1}',
      apiStatus,
    ];

    for (final key in keys) {
      final label = stepLabels[key]?.trim();
      if (label != null && label.isNotEmpty) return label;
    }

    return _formatStatusLabel(apiStatus);
  }

  static String _formatStatusLabel(String apiStatus) {
    return apiStatus
        .replaceAll('_', ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String get displayTitle {
    final type = orderType?.toLowerCase().trim() ?? '';
    if (type == 'pickup' || type.contains('pickup')) return 'Order Pickup';
    if (type == 'delivery' || type.contains('delivery')) {
      return 'Order Delivery';
    }
    if (type.contains('return') || isReturnFlow) return 'Order Return';

    final flow = flowType?.toLowerCase().trim() ?? '';
    if (flow == 'return') return 'Order Return';
    if (flow == 'delivery') {
      return isPickupPhase ? 'Order Pickup' : 'Order Delivery';
    }

    if (isPickupPhase) return 'Order Pickup';
    return 'Order Delivery';
  }

  String get packageDisplayTitle {
    final type = packageType?.trim();
    if (type != null && type.isNotEmpty) {
      return type
          .replaceAll('_', ' ')
          .split(' ')
          .map(
            (word) => word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
          )
          .join(' ');
    }
    return displayTitle;
  }

  bool get isDeliveryOrderCard {
    final type = orderType?.toLowerCase().trim() ?? '';
    if (type == 'pickup' || type.contains('pickup')) return false;
    if (type == 'delivery' || type.contains('delivery')) return true;
    if (isReturnFlow) return false;
    return !isPickupPhase;
  }

  /// Delivery/drop map is enabled only after pickup is confirmed.
  bool get isDropMapEnabled {
    if (pickupConfirmedAt != null && pickupConfirmedAt!.trim().isNotEmpty) {
      return true;
    }

    final currentStatus = status.toLowerCase().trim();

    if (isReturnFlow) {
      // Return: drop = IAP. Enable only after customer pickup is done.
      return currentStatus == 'pickup_confirmed' ||
          currentStatus == 'confirm_pickup' ||
          currentStatus == 'picked_up' ||
          currentStatus == 'in_transit_to_iap' ||
          currentStatus == 'arrived_at_iap' ||
          currentStatus == 'confirm_delivery' ||
          currentStatus == 'delivered' ||
          currentStatus == 'delivery_success' ||
          currentStatus == 'returned_to_iap' ||
          journey.completedTransitionIndex >= 2;
    }

    return currentStatus == 'pickup_confirmed' ||
        currentStatus == 'confirm_pickup' ||
        currentStatus == 'picked_up' ||
        currentStatus == 'in_transit_to_delivery' ||
        currentStatus == 'in_transit_to_customer' ||
        currentStatus == 'arrived_at_delivery' ||
        currentStatus == 'arrived_at_customer' ||
        currentStatus == 'confirm_delivery' ||
        currentStatus == 'delivered' ||
        currentStatus == 'delivery_success' ||
        currentStatus == 'completed' ||
        journey.completedTransitionIndex >= 2;
  }

  String get displayStatus => journey.statusSummary;

  String get formattedScheduleTime {
    if (scheduledTime == null || scheduledTime!.isEmpty) {
      return 'Not scheduled';
    }
    try {
      final date = DateTime.parse(scheduledTime!).toLocal();
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final weekday = weekdays[date.weekday - 1];
      final day = date.day;
      final suffix = _daySuffix(day);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$weekday, $day$suffix ${months[date.month - 1]}  $hour:$minute $period';
    } catch (_) {
      return scheduledTime!;
    }
  }

  String get formattedDeliverySchedule {
    final dateStr = _resolvedDeliveryDate?.trim();
    final timeStr = _resolvedDeliveryTime?.trim();

    if (dateStr == null || dateStr.isEmpty) {
      return 'Not scheduled';
    }

    final displayDate = _formatCalendarDateLabel(dateStr) ?? dateStr;

    if (timeStr != null && timeStr.isNotEmpty) {
      return '$displayDate $timeStr';
    }
    return displayDate;
  }

  String? get _resolvedDeliveryDate {
    final stored = deliveryDate?.trim();
    if (stored != null && stored.isNotEmpty) return _normalizeDateOnly(stored);
    return null;
  }

  String? get _resolvedDeliveryTime {
    final stored = deliveryTime?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    return null;
  }

  static String? _formatCalendarDateLabel(String value) {
    final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(value.trim());
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final weekday = weekdays[DateTime(year, month, day).weekday - 1];
    return '$weekday, $day${_daySuffix(day)} ${months[month - 1]}';
  }

  String? get packageDescription {
    final text = description?.trim();
    if (text != null && text.isNotEmpty) return text;
    final weight = weightKg?.trim();
    if (weight != null && weight.isNotEmpty && weight != '0' && weight != '0.00') {
      return 'Weight: $weight kg';
    }
    return null;
  }

  /// Prefer dedicated instructions; fall back to [notes].
  String? get displayInstructions {
    final text = instructions?.trim();
    if (text != null && text.isNotEmpty) return text;
    final note = notes?.trim();
    if (note != null && note.isNotEmpty) return note;
    return null;
  }

  String get customerDisplayName {
    final name = customerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Customer name unavailable';
  }

  int get productCount => products.isEmpty ? 0 : products.length;

  List<OrderProductSection> get productSections =>
      OrderProductSectionBuilder.build(products);

  List<DpOrderProduct> get displayProducts => [
        for (final section in productSections) ...section.products,
      ];

  String get itemsCountLabel {
    final count = productCount;
    if (count <= 0) return '';
    return count == 1 ? '1 Item' : '$count Items';
  }

  bool get isPickupPhase =>
      !isReturnFlow && journey.currentPhase == OrderPhase.pickup;

  bool get isAccepted {
    if (isNotDelivered || isRejectedStatus) return false;

    final statusKey = apiStatusKey;
    if (statusKey == 'assigned' || statusKey == 'return_assigned') {
      return false;
    }
    return journey.hasStarted;
  }

  DpOrder copyWith({
    String? status,
    String? flowType,
    Map<String, String>? stepLabels,
    String? subStatus,
    String? arrivedAtIapAt,
    String? pickupConfirmedAt,
    String? inTransitAt,
    String? arrivedAtDeliveryAt,
    String? deliveredAt,
    String? completedAt,
    String? deliveryDate,
    String? deliveryTime,
    String? rejectionReason,
    int? waited10mins,
    List<String>? pickupFailedImages,
  }) {
    return DpOrder(
      id: id,
      orderNumber: orderNumber,
      status: status ?? this.status,
      flowType: flowType ?? this.flowType,
      stepLabels: stepLabels ?? this.stepLabels,
      subStatus: subStatus ?? this.subStatus,
      orderType: orderType,
      packageType: packageType,
      customerName: customerName,
      customerPhone: customerPhone,
      products: products,
      pickupAddress: pickupAddress,
      dropAddress: dropAddress,
      scheduledTime: scheduledTime,
      amount: amount,
      description: description,
      notes: notes,
      instructions: instructions,
      weightKg: weightKg,
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      arrivedAtIapAt: arrivedAtIapAt ?? this.arrivedAtIapAt,
      pickupConfirmedAt: pickupConfirmedAt ?? this.pickupConfirmedAt,
      inTransitAt: inTransitAt ?? this.inTransitAt,
      arrivedAtDeliveryAt: arrivedAtDeliveryAt ?? this.arrivedAtDeliveryAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      completedAt: completedAt ?? this.completedAt,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      waited10mins: waited10mins ?? this.waited10mins,
      pickupFailedImages: pickupFailedImages ?? this.pickupFailedImages,
    );
  }

  factory DpOrder.fromJson(Map<String, dynamic> json) {
    final deliveryAddressRaw = json['delivery_address'] ??
        json['dropAddress'] ??
        json['drop_address'] ??
        json['dropLocation'] ??
        json['drop'];
    final deliveryAddressMap = _tryParseAddressMap(deliveryAddressRaw);
    final stepLabels = _readStepLabels(json);
    final customer = _readCustomerMap(json);

    return DpOrder(
      id: _readString(json['id']),
      orderNumber: _readString(
            json['orderNumber'] ??
                json['order_number'] ??
                json['id'],
          ) ??
          '',
      status: json['status']?.toString() ?? '',
      flowType: _readString(json['flow_type'] ?? json['flowType']),
      stepLabels: stepLabels,
      subStatus: _readString(json['sub_status'] ?? json['subStatus']),
      orderType: _readString(
        json['orderType'] ??
            json['order_type'] ??
            json['assignment_type'] ??
            json['assignmentType'] ??
            json['type'],
      ),
      packageType: _readString(
        json['package_type'] ?? json['packageType'],
      ),
      customerName: _readString(
        json['customer_name'] ??
            json['customerName'] ??
            customer?['name'] ??
            customer?['full_name'] ??
            customer?['fullName'] ??
            json['user_name'] ??
            json['userName'],
      ),
      customerPhone: _readString(
        json['customer_phone'] ??
            json['customerPhone'] ??
            json['customer_mobile'] ??
            json['customerMobile'] ??
            customer?['phone'] ??
            customer?['mobile'] ??
            customer?['phone_number'] ??
            customer?['phoneNumber'] ??
            json['phone'] ??
            json['mobile'],
      ),
      products: _readProducts(json),
      pickupAddress: _readAddress(
        json['pickupAddress'] ??
            json['pickup_address'] ??
            json['pickupLocation'] ??
            json['pickup'],
      ),
      dropAddress: _readAddress(deliveryAddressRaw),
      scheduledTime: _readString(
        json['scheduledTime'] ??
            json['scheduled_time'] ??
            json['scheduledAt'] ??
            json['assigned_at'] ??
            json['created_at'] ??
            json['time'],
      ),
      amount: _readString(
        json['amount'] ??
            json['partner_earning'] ??
            json['delivery_charge'] ??
            json['price'] ??
            json['totalAmount'] ??
            json['total_value'],
      ),
      description: _readString(json['description']),
      notes: _readString(json['notes']),
      instructions: _readString(
        json['instructions'] ??
            json['delivery_instructions'] ??
            json['deliveryInstructions'] ??
            json['pickup_instructions'] ??
            json['pickupInstructions'],
      ),
      weightKg: _readString(json['weight_kg'] ?? json['weightKg']),
      pickupLatitude: _readDouble(json['pickup_latitude'] ?? json['pickupLatitude']),
      pickupLongitude: _readDouble(json['pickup_longitude'] ?? json['pickupLongitude']),
      deliveryLatitude: _readDouble(
            json['delivery_latitude'] ??
                json['deliveryLatitude'] ??
                deliveryAddressMap?['latitude'],
          ) ??
          _readDouble(deliveryAddressMap?['lat']),
      deliveryLongitude: _readDouble(
            json['delivery_longitude'] ??
                json['deliveryLongitude'] ??
                deliveryAddressMap?['longitude'],
          ) ??
          _readDouble(deliveryAddressMap?['lng']),
      arrivedAtIapAt: _readString(json['arrived_at_iap_at']),
      pickupConfirmedAt: _readString(json['pickup_confirmed_at']),
      inTransitAt: _readString(json['in_transit_at']),
      arrivedAtDeliveryAt: _readString(json['arrived_at_delivery_at']),
      deliveredAt: _readString(json['delivered_at']),
      completedAt: _readString(json['completed_at']),
      deliveryDate: _readDeliveryDate(json),
      deliveryTime: _readDeliveryTime(json),
      rejectionReason: _readString(
        json['rejection_reason'] ??
            json['rejectionReason'] ??
            json['reject_reason'] ??
            json['rejectReason'] ??
            json['not_delivered_reason'],
      ),
      waited10mins: _readInt(json['waited10mins'] ?? json['waited_10_mins']),
      pickupFailedImages: _readStringList(
        json['pickup_failed_images'] ??
            json['pickup_failed_image'] ??
            json['pickupFailedImages'],
      ),
    );
  }

  static List<String> _readStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      final list = <String>[];
      for (final item in value) {
        if (item is String && item.trim().isNotEmpty) {
          list.add(item.trim());
        } else if (item is Map) {
          final url = item['url']?.toString().trim();
          if (url != null && url.isNotEmpty) list.add(url);
        }
      }
      return list;
    }
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty || text == 'null' || text == '[]') return const [];
      if (text.startsWith('[')) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is List) return _readStringList(decoded);
        } catch (_) {}
      }
      return [text];
    }
    return const [];
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static Map<String, dynamic>? _readCustomerMap(Map<String, dynamic> json) {
    final customer = json['customer'] ?? json['user'] ?? json['customer_details'];
    if (customer is Map) {
      return customer.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static List<DpOrderProduct> _readProducts(Map<String, dynamic> json) {
    final items = json['items'] ?? json['orderItems'] ?? json['order_items'];
    if (items is! List || items.isEmpty) return const [];
    return _parseProductItems(items);
  }

  static List<DpOrderProduct> _parseProductItems(List<dynamic> rawItems) {
    final products = <DpOrderProduct>[];

    for (final entry in rawItems) {
      if (entry is! Map) continue;
      final map = entry.map((key, value) => MapEntry(key.toString(), value));

      final product = DpOrderProduct.fromJson(map);
      final hasContent = (product.name?.trim().isNotEmpty == true) ||
          (product.kitType?.trim().isNotEmpty == true) ||
          product.garments.isNotEmpty;
      if (hasContent) products.add(product);
    }

    return products;
  }

  static Map<String, String> _readStepLabels(Map<String, dynamic> json) {
    final uiLabels = json['ui_labels'] ?? json['uiLabels'];
    if (uiLabels is! Map) return const {};

    final stepLabels = uiLabels['step_labels'] ?? uiLabels['stepLabels'];
    if (stepLabels is! Map) return const {};

    return stepLabels.map(
      (key, value) => MapEntry(
        key.toString(),
        value?.toString().trim() ?? '',
      ),
    );
  }

  static Map<String, dynamic>? _tryParseAddressMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }

    final text = value.toString().trim();
    if (text.isEmpty || !text.startsWith('{')) return null;

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return decoded.map((key, val) => MapEntry(key.toString(), val));
      }
    } catch (_) {}

    return null;
  }

  static String? _readAddress(dynamic value) {
    final map = _tryParseAddressMap(value);
    if (map != null) {
      final formatted = _formatAddressMap(map);
      return formatted.isEmpty ? null : formatted;
    }

    return _readString(value);
  }

  static String _formatAddressMap(Map<String, dynamic> map) {
    final parts = <String>[];

    void addPart(dynamic raw) {
      final text = raw?.toString().trim();
      if (text == null || text.isEmpty || text == 'null') return;
      if (!parts.contains(text)) parts.add(text);
    }

    addPart(map['full_address']);
    addPart(map['buildingNumber']);
    addPart(map['streetName']);
    addPart(map['city']);
    addPart(map['state']);
    addPart(map['country']);

    if (parts.isEmpty) {
      addPart(map['address']);
      addPart(map['line1']);
      addPart(map['line2']);
    }

    final pincode = map['pincode']?.toString().trim();
    if (parts.isEmpty) return '';

    final address = parts.join(', ');
    if (pincode != null && pincode.isNotEmpty && pincode != 'null') {
      return '$address - $pincode';
    }
    return address;
  }

  static String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _normalizeDateOnly(String? value) {
    if (value == null) return null;
    final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(value.trim());
    if (match == null) return value.trim();
    return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
  }

  static String? _readDeliveryDate(Map<String, dynamic> json) {
    return _normalizeDateOnly(
      _readKitDetailField(
        json,
        fieldKeys: const ['delivery_date'],
      ),
    );
  }

  static String? _readDeliveryTime(Map<String, dynamic> json) {
    return _readKitDetailField(
      json,
      fieldKeys: const ['delivery_time'],
    );
  }

  static String? _readKitDetailField(
    Map<String, dynamic> json, {
    required List<String> fieldKeys,
  }) {
    final items = json['items'];
    if (items is! List) return null;

    for (final item in items) {
      final itemMap = _tryParseMap(item);
      if (itemMap == null) continue;

      final kitMap = _tryParseMap(itemMap['kitDetails']);
      if (kitMap == null) continue;

      for (final key in fieldKeys) {
        final value = _readString(kitMap[key]);
        if (value != null) return value;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _tryParseMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }

    if (value is String) {
      final text = value.trim();
      if (text.isEmpty || !text.startsWith('{')) return null;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          return decoded.map((key, val) => MapEntry(key.toString(), val));
        }
      } catch (_) {}
    }
    return null;
  }

  static String _daySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
