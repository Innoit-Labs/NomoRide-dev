import 'dart:convert';

import 'package:nomoride/features/home/data/models/dp_order_product.dart';
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
    final dateStr = deliveryDate?.trim();
    final timeStr = deliveryTime?.trim();

    if (dateStr == null || dateStr.isEmpty) {
      return formattedScheduleTime;
    }

    String displayDate = '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
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
      displayDate = '$weekday, $day$suffix ${months[date.month - 1]}';
    } catch (_) {
      displayDate = dateStr;
    }

    if (timeStr != null && timeStr.isNotEmpty) {
      return '$displayDate $timeStr';
    }
    return displayDate;
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

  String get itemsCountLabel {
    final count = productCount;
    if (count <= 0) return '';
    return count == 1 ? '1 Item' : '$count Items';
  }

  bool get isPickupPhase =>
      !isReturnFlow && journey.currentPhase == OrderPhase.pickup;

  bool get isAccepted {
    final normalizedStatus = status.toLowerCase().trim();
    if (normalizedStatus == 'assigned' ||
        normalizedStatus == 'return_assigned' ||
        normalizedStatus == 'not_delivered' ||
        normalizedStatus == 'rejected') {
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
      deliveryDate: _readString(json['delivery_date'] ?? json['deliveryDate']),
      deliveryTime: _readString(json['delivery_time'] ?? json['deliveryTime']),
      rejectionReason: _readString(
        json['rejection_reason'] ??
            json['rejectionReason'] ??
            json['reject_reason'] ??
            json['rejectReason'] ??
            json['not_delivered_reason'],
      ),
    );
  }

  static Map<String, dynamic>? _readCustomerMap(Map<String, dynamic> json) {
    final customer = json['customer'] ?? json['user'] ?? json['customer_details'];
    if (customer is Map) {
      return customer.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static List<DpOrderProduct> _readProducts(Map<String, dynamic> json) {
    final candidates = [
      json['products'],
      json['items'],
      json['order_items'],
      json['orderItems'],
      json['line_items'],
      json['lineItems'],
      json['garments'],
      json['package_items'],
      json['packageItems'],
    ];

    for (final candidate in candidates) {
      final products = DpOrderProduct.listFromJson(candidate);
      if (products.isNotEmpty) return products;
    }

    // Nested order payload (some APIs wrap details under `order`).
    final nested = json['order'] ?? json['order_details'] ?? json['orderDetails'];
    if (nested is Map) {
      final nestedMap =
          nested.map((key, value) => MapEntry(key.toString(), value));
      return _readProducts(nestedMap);
    }

    return const [];
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
