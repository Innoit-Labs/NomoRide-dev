import 'dart:convert';

import 'package:nomoride/features/home/data/models/delivery_fee.dart';
import 'package:nomoride/features/home/data/models/dp_order_product.dart';
import 'package:nomoride/features/home/data/models/order_item_section.dart';
import 'package:nomoride/features/home/data/models/order_journey.dart';
import 'package:nomoride/features/home/data/models/rto_details.dart';

class DpOrder {
  const DpOrder({
    required this.orderNumber,
    required this.status,
    this.id,
    this.flowType,
    this.stepLabels = const {},
    this.apiNextActionLabel,
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
    this.returnedToIapAt,
    this.rtoCompletedAt,
    this.deliveryDate,
    this.deliveryTime,
    this.returnDate,
    this.returnTime,
    this.returnNotes,
    this.rejectionReason,
    this.parentOrderStatus,
    this.rtoStatus,
    this.rtoDetails,
    this.waited10mins,
    this.pickupFailedImages = const [],
    this.customerAddressId,
  });

  final String? id;
  final String orderNumber;
  final String status;
  final String? flowType;
  final Map<String, String> stepLabels;
  final String? apiNextActionLabel;
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
  final String? returnedToIapAt;
  final String? rtoCompletedAt;
  final String? deliveryDate;
  final String? deliveryTime;
  final String? returnDate;
  final String? returnTime;
  final String? returnNotes;
  final String? rejectionReason;
  /// Parent commerce order status from myorders (`NOT_DELIVERED`, etc.).
  final String? parentOrderStatus;
  final String? rtoStatus;
  final RtoDetails? rtoDetails;
  final int? waited10mins;
  final List<String> pickupFailedImages;
  final String? customerAddressId;

  /// Customer side of the trip: pickup for returns, drop for deliveries.
  String? get customerAddress =>
      flowType?.trim().toLowerCase() == 'return' ? pickupAddress : dropAddress;

  OrderFlow get journey => OrderFlow(this);

  bool get isReturnFlow {
    // Explicit flow_type wins — delivery RTO ends as `returned_to_iap` and
    // must not be treated as a customer-return pickup flow.
    final flow = flowType?.toLowerCase().trim();
    if (flow != null && flow.isNotEmpty) {
      if (flow == 'delivery') return false;
      if (flow == 'return' || flow == 'pickup') return true;
    }

    final orderStatus = status.toLowerCase().trim();
    if (orderStatus == 'return_assigned' ||
        orderStatus == 'returned_to_iap' ||
        orderStatus == 'return_failed' ||
        orderStatus.startsWith('return_')) {
      return true;
    }

    final type = orderType?.toLowerCase().trim() ?? '';
    if (type.contains('return')) return true;

    final sub = subStatus?.toLowerCase().trim() ?? '';
    if (sub.contains('return')) return true;

    final ordNum = orderNumber.toUpperCase().trim();
    if (ordNum.startsWith('RET') || ordNum.contains('-RET-') || ordNum.contains('_RET_')) {
      return true;
    }

    if (type == 'pickup') return true;

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

  /// Parent / status key used for return-failed vs delivery-failed bucketing.
  String get _normalizedParentOrderStatus =>
      (parentOrderStatus ?? '')
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[\s-]+'), '_');

  /// Customer return pickup failed (My Orders → Pickup Failed).
  /// Uses parent `RETURN_FAILED` even when this DP row has `flow_type: delivery`
  /// (e.g. after RTO / reassignment), so those orders are not lost under
  /// Not Delivered.
  bool get isReturnFailed {
    if (_normalizedParentOrderStatus == 'RETURN_FAILED') return true;

    final s = normalizedStatus;
    if (s == 'return failed' ||
        s == 'return_failed' ||
        s == 'pickup failed' ||
        s == 'pickup_failed' ||
        s == 'mark return as failed') {
      return true;
    }

    // Explicit return-flow failure without a delivery RTO completion.
    if (isReturnFlow &&
        (s == 'failed' ||
            s == 'not delivered' ||
            s == 'not_delivered' ||
            s == 'delivery failed' ||
            s == 'delivery_failed')) {
      return true;
    }

    return false;
  }

  bool get isNotDelivered {
    // Return pickup failures belong in Pickup Failed, but still count as
    // "failed" so they stay out of Completed.
    if (isReturnFailed) return true;

    final s = normalizedStatus;
    if (s == 'not delivered' ||
        s == 'not_delivered' ||
        s == 'failed' ||
        s == 'delivery failed' ||
        s == 'delivery_failed') {
      return true;
    }

    if (_normalizedParentOrderStatus == 'NOT_DELIVERED') return true;

    // Delivery failed → RTO → hub confirmed (`returned_to_iap` / RTO_COMPLETED).
    // These land in myorders `completedOrders` but belong under Not Delivered.
    if (!isReturnFlow) {
      if (s == 'returned to iap') return true;
      if (isRtoCompleted || hasCompletedRtoHandover) return true;
    }

    return false;
  }

  bool get isRejectedStatus =>
      normalizedStatus == 'rejected' ||
      normalizedStatus == 'order rejected' ||
      normalizedStatus == 'order failed';

  String get _normalizedRtoStatus =>
      rtoStatus?.trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_') ?? '';

  bool get isRtoInitiated =>
      _normalizedRtoStatus == 'RTO_INITIATED' ||
      (rtoDetails?.status
              ?.trim()
              .toUpperCase()
              .replaceAll(RegExp(r'[\s-]+'), '_') ==
          'RTO_INITIATED');

  bool _hasTimestamp(String? value) =>
      value != null && value.trim().isNotEmpty;

  /// Failed-delivery package was handed back to IAP.
  /// Delivery Failed alone must NOT count as completed — only hub confirmation.
  bool get hasCompletedRtoHandover {
    if (isRtoInitiated) return false;
    if (_normalizedRtoStatus == 'RTO_RETURNED' ||
        _normalizedRtoStatus == 'RTO_COMPLETED') {
      return true;
    }
    if (_hasTimestamp(returnedToIapAt) || _hasTimestamp(rtoCompletedAt)) {
      return true;
    }
    return false;
  }

  bool get isReturnedToIap {
    final s = normalizedStatus;
    final sub = subStatus?.trim().toLowerCase().replaceAll(RegExp(r'[_\s]+'), ' ') ?? '';
    return s == 'returned to iap' ||
        s == 'rto returned' ||
        sub == 'returned to iap' ||
        sub == 'rto returned' ||
        hasCompletedRtoHandover;
  }

  /// Hub handover finished after a failed delivery (`rto_status: RTO_COMPLETED`).
  bool get isRtoCompleted =>
      !isRtoInitiated &&
      (_normalizedRtoStatus == 'RTO_COMPLETED' || _hasTimestamp(rtoCompletedAt));

  /// IAP hub destination for an active RTO return.
  String? get rtoReturnAddress {
    final fromDetails = rtoDetails?.returnDestinationLabel?.trim();
    if (fromDetails != null && fromDetails.isNotEmpty) return fromDetails;
    return null;
  }

  double? get rtoReturnLatitude => rtoDetails?.dropLocation?.latitude;

  double? get rtoReturnLongitude => rtoDetails?.dropLocation?.longitude;

  String? get rtoOtp => rtoDetails?.rtoOtp?.trim();

  String? get rtoDisplayNotes {
    final fromDetails = rtoDetails?.rtoNotes?.trim();
    if (fromDetails != null && fromDetails.isNotEmpty) return fromDetails;
    return rejectionReason?.trim();
  }

  String? get rtoHubContactPerson =>
      rtoDetails?.dropLocation?.contactPerson?.trim();

  String? get rtoHubContactMobile =>
      rtoDetails?.dropLocation?.contactMobile?.trim();

  String? get rtoHubName => rtoDetails?.dropLocation?.hubName?.trim();

  /// Partner earnings total after RTO (forward + return) when backend sends it.
  String? get rtoPartnerEarningDisplay =>
      rtoDetails?.formattedTotalEarning ?? amount;

  /// `ui_labels.next_action_label` is Return to IAP (RTO).
  bool get isReturnToIapRtoAction {
    final label = (apiNextActionLabel ?? '').trim().toLowerCase();
    if (label.isEmpty) return false;
    return label.contains('return to iap') && label.contains('rto');
  }

  /// Card / Total Fare amount. For Return to IAP (RTO) only, use `base_amount`.
  String? get displayPartnerEarning {
    if (isReturnToIapRtoAction) {
      return rtoDetails?.formattedBaseAmount ??
          rtoPartnerEarningDisplay ??
          amount;
    }
    return rtoPartnerEarningDisplay ?? amount;
  }

  /// When a forward delivery order was not delivered to the customer,
  /// the delivery partner has collected garments that must be returned to the IAP store/hub.
  bool get isUndeliveredReturnToHub {
    if (isReturnFlow) return false;
    if (isReturnedToIap || normalizedStatus == 'completed') return false;
    if (isNotDelivered || isRtoInitiated) return true;
    final hasRejection = rejectionReason != null && rejectionReason!.trim().isNotEmpty;
    final inHubReturn = normalizedStatus == 'in transit to iap' ||
        normalizedStatus == 'arrived at iap';
    if (hasRejection && inHubReturn) return true;
    if (pickupConfirmedAt != null && pickupConfirmedAt!.trim().isNotEmpty && inHubReturn) {
      return true;
    }
    return false;
  }

  /// Orders shown on Home → Orders Assigned (excludes completed and purely rejected,
  /// but keeps undelivered forward orders until garments are returned to IAP).
  bool get isVisibleOnHomeAssigned {
    if (isReturnedToIap || isRtoCompleted || normalizedStatus == 'completed') {
      return false;
    }
    if (isUndeliveredReturnToHub) return true;
    return !isNotDelivered;
  }

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
    switch (flowType?.toLowerCase().trim()) {
      case 'pickup':
        return 'Order Pickup';
      case 'return':
        return 'Order Return';
      case 'delivery':
        return 'Order Delivery';
    }

    if (isReturnFlow) return 'Order Return';

    final type = orderType?.toLowerCase().trim() ?? '';
    if (type.contains('return')) return 'Order Return';
    if (type == 'pickup' || type.contains('pickup')) return 'Order Pickup';
    if (type == 'delivery' || type.contains('delivery')) {
      return 'Order Delivery';
    }
    return 'Order Delivery';
  }

  /// Card icon follows [flowType], so a delivery stays a delivery while the
  /// partner is still collecting the garments.
  bool get usesDeliveryIcon {
    switch (flowType?.toLowerCase().trim()) {
      case 'delivery':
        return true;
      case 'pickup':
      case 'return':
        return false;
    }
    return isDeliveryOrderCard;
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
    switch (flowType?.toLowerCase().trim()) {
      case 'delivery':
        return true;
      case 'pickup':
      case 'return':
        return false;
    }
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
      if (pickupConfirmedAt != null && pickupConfirmedAt!.trim().isNotEmpty) {
        return true;
      }
      return journey.completedTransitionIndex >= 2 ||
          currentStatus == 'pickup_confirmed' ||
          currentStatus == 'confirm_pickup' ||
          currentStatus == 'picked_up' ||
          currentStatus == 'confirm_delivery' ||
          currentStatus == 'delivered' ||
          currentStatus == 'delivery_success' ||
          currentStatus == 'returned_to_iap';
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

  /// Returns the appropriate schedule display:
  /// - For Return Order flow: the customer's actual requested return date and time.
  /// - For Delivery/Pickup flow: the garment delivery schedule.
  String get formattedDeliverySchedule => formattedSchedule;

  String get formattedSchedule {
    if (isReturnFlow) {
      return formattedReturnSchedule;
    }
    return _formattedStandardDeliverySchedule;
  }

  /// Formatted customer requested return date and time for Return Order flow.
  String get formattedReturnSchedule {
    final dateStr = _resolvedReturnDate?.trim();
    final timeStr = _resolvedReturnTime?.trim();

    if (dateStr == null || dateStr.isEmpty) {
      if (timeStr != null && timeStr.isNotEmpty) {
        return timeStr;
      }
      return 'Not scheduled';
    }

    final displayDate = _formatCalendarDateLabel(dateStr) ?? dateStr;

    if (timeStr != null && timeStr.isNotEmpty) {
      return '$displayDate $timeStr';
    }
    return displayDate;
  }

  String get _formattedStandardDeliverySchedule {
    final dateStr = _resolvedDeliveryDate?.trim();
    final timeStr = _resolvedDeliveryTime?.trim();

    if (dateStr == null || dateStr.isEmpty) {
      if (timeStr != null && timeStr.isNotEmpty) {
        return timeStr;
      }
      return 'Not scheduled';
    }

    final displayDate = _formatCalendarDateLabel(dateStr) ?? dateStr;

    if (timeStr != null && timeStr.isNotEmpty) {
      return '$displayDate $timeStr';
    }
    return displayDate;
  }

  String? get _resolvedReturnDate {
    final stored = returnDate?.trim();
    if (stored != null && stored.isNotEmpty) return _normalizeDateOnly(stored);
    return null;
  }

  String? get _resolvedReturnTime {
    final stored = returnTime?.trim();
    if (stored != null && stored.isNotEmpty) return _formatTimeDisplay(stored) ?? stored;
    return null;
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

  /// Primary notes text to display (prioritizes customer return notes for return flow).
  String? get displayNotes {
    if (isReturnFlow) {
      final rNote = returnNotes?.trim();
      if (rNote != null && rNote.isNotEmpty) return rNote;
      return null;
    }
    final gNote = notes?.trim();
    if (gNote != null && gNote.isNotEmpty) return gNote;
    final rNote = returnNotes?.trim();
    if (rNote != null && rNote.isNotEmpty) return rNote;
    final instr = instructions?.trim();
    if (instr != null && instr.isNotEmpty) return instr;
    final reason = rejectionReason?.trim();
    if (reason != null && reason.isNotEmpty) return reason;
    return null;
  }

  /// Prefer dedicated instructions; fall back to [returnNotes] / [notes].
  String? get displayInstructions {
    if (isReturnFlow) {
      final rNote = returnNotes?.trim();
      if (rNote != null && rNote.isNotEmpty) return rNote;
      return null;
    }

    final text = instructions?.trim();
    if (text != null && text.isNotEmpty) return text;
    final note = notes?.trim() ?? returnNotes?.trim();
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
    String? apiNextActionLabel,
    String? subStatus,
    String? orderType,
    String? packageType,
    String? customerName,
    String? customerPhone,
    String? pickupAddress,
    String? dropAddress,
    String? scheduledTime,
    String? arrivedAtIapAt,
    String? pickupConfirmedAt,
    String? inTransitAt,
    String? arrivedAtDeliveryAt,
    String? deliveredAt,
    String? completedAt,
    String? returnedToIapAt,
    String? rtoCompletedAt,
    String? deliveryDate,
    String? deliveryTime,
    String? returnDate,
    String? returnTime,
    String? returnNotes,
    String? amount,
    String? rejectionReason,
    String? parentOrderStatus,
    String? rtoStatus,
    RtoDetails? rtoDetails,
    int? waited10mins,
    List<String>? pickupFailedImages,
  }) {
    return DpOrder(
      id: id,
      orderNumber: orderNumber,
      status: status ?? this.status,
      flowType: flowType ?? this.flowType,
      stepLabels: stepLabels ?? this.stepLabels,
      apiNextActionLabel: apiNextActionLabel ?? this.apiNextActionLabel,
      subStatus: subStatus ?? this.subStatus,
      orderType: orderType ?? this.orderType,
      packageType: packageType ?? this.packageType,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      products: products,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropAddress: dropAddress ?? this.dropAddress,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      amount: amount ?? this.amount,
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
      returnedToIapAt: returnedToIapAt ?? this.returnedToIapAt,
      rtoCompletedAt: rtoCompletedAt ?? this.rtoCompletedAt,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      returnDate: returnDate ?? this.returnDate,
      returnTime: returnTime ?? this.returnTime,
      returnNotes: returnNotes ?? this.returnNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      parentOrderStatus: parentOrderStatus ?? this.parentOrderStatus,
      rtoStatus: rtoStatus ?? this.rtoStatus,
      rtoDetails: rtoDetails ?? this.rtoDetails,
      waited10mins: waited10mins ?? this.waited10mins,
      pickupFailedImages: pickupFailedImages ?? this.pickupFailedImages,
      customerAddressId: customerAddressId,
    );
  }

  factory DpOrder.fromJson(Map<String, dynamic> json) {
    final customer = _readCustomerMap(json);
    final deliveryDetails = _asStringMap(
      json['delivery_details'] ?? json['deliveryDetails'],
    );

    final customerAddressCandidate = _firstRealAddress([
      json['customer_address'],
      json['customerAddress'],
      customer?['address'],
      customer?['full_address'],
      customer?['formatted_address'],
      customer?['customer_address'],
      customer?['delivery_address'],
      json['delivery_address_json'],
      json['deliveryAddressJson'],
      json['delivery_address_snapshot'],
      json['deliveryAddressSnapshot'],
      json['customer_address_snapshot'],
      deliveryDetails?['customer_address'],
      deliveryDetails?['delivery_address_json'],
      deliveryDetails?['delivery_address_snapshot'],
      ..._readItemCustomerAddresses(json),
      customer?['primary_address'],
      customer?['primaryAddress'],
      customer?['addresses'],
      json['shipping_address'],
      json['shippingAddress'],
      json['user_address'],
      json['userAddress'],
      json['address'],
    ]);

    final pickupAddressRaw = json['pickupAddress'] ??
        json['pickup_address'] ??
        json['pickupLocation'] ??
        json['pickup_location'] ??
        deliveryDetails?['pickup_address'] ??
        json['pickup'];
    final pickupAddressMap = _tryParseAddressMap(pickupAddressRaw);

    final deliveryAddressRaw = json['delivery_address'] ??
        json['deliveryAddress'] ??
        json['dropAddress'] ??
        json['drop_address'] ??
        json['dropLocation'] ??
        json['drop_location'] ??
        json['delivery_location'] ??
        json['deliveryLocation'] ??
        deliveryDetails?['delivery_address'] ??
        deliveryDetails?['address'] ??
        json['drop'];
    final deliveryAddressMap = _tryParseAddressMap(deliveryAddressRaw);

    var pickupAddress = _readAddress(pickupAddressRaw);
    var dropAddress = _readAddress(deliveryAddressRaw);

    if (isDummyAddress(pickupAddress) && customerAddressCandidate != null) {
      pickupAddress = customerAddressCandidate;
    }
    if (isDummyAddress(dropAddress) && customerAddressCandidate != null) {
      dropAddress = customerAddressCandidate;
    }

    final isReturn =
        json['flow_type']?.toString().trim().toLowerCase() == 'return';
    if (!isReturn && isDummyAddress(dropAddress)) {
      dropAddress = _deepFindCustomerAddress(json, exclude: pickupAddress);
    }
    if (isReturn && isDummyAddress(pickupAddress)) {
      pickupAddress = _deepFindCustomerAddress(json, exclude: dropAddress);
    }
    if (isDummyAddress(pickupAddress)) pickupAddress = null;
    if (isDummyAddress(dropAddress)) dropAddress = null;

    final pickupLatitude = _readDouble(
          json['pickup_latitude'] ??
              json['pickupLatitude'] ??
              pickupAddressMap?['latitude'],
        ) ??
        _readDouble(pickupAddressMap?['lat']);
    final pickupLongitude = _readDouble(
          json['pickup_longitude'] ??
              json['pickupLongitude'] ??
              pickupAddressMap?['longitude'],
        ) ??
        _readDouble(pickupAddressMap?['lng']);
    final deliveryLatitude = _readDouble(
          json['delivery_latitude'] ??
              json['deliveryLatitude'] ??
              deliveryAddressMap?['latitude'],
        ) ??
        _readDouble(deliveryAddressMap?['lat']);
    final deliveryLongitude = _readDouble(
          json['delivery_longitude'] ??
              json['deliveryLongitude'] ??
              deliveryAddressMap?['longitude'],
        ) ??
        _readDouble(deliveryAddressMap?['lng']);
    final stepLabels = _readStepLabels(json);
    final uiLabels = json['ui_labels'] ?? json['uiLabels'];
    final apiNextActionLabel = _readString(
      (uiLabels is Map
              ? (uiLabels['next_action_label'] ??
                  uiLabels['nextActionLabel'])
              : null) ??
          json['next_action_label'] ??
          json['nextActionLabel'],
    );

    // After a failed delivery the backend overwrites `notes` and
    // `instructions` with the partner's failure reason; `order_note` keeps
    // what the customer wrote.
    final failureReason = _readString(
      json['failure_reason'] ??
          json['failureReason'] ??
          json['rejection_reason'] ??
          json['rejectionReason'] ??
          json['not_delivered_reason'],
    )?.trim();
    String? exceptFailureReason(dynamic value) {
      final text = _readString(value);
      if (text == null || text.trim() == failureReason) return null;
      return text;
    }

    final customerNote = _readString(
      json['order_note'] ??
          json['orderNote'] ??
          json['customer_note'] ??
          json['customerNote'] ??
          json['customer_notes'] ??
          json['customerNotes'] ??
          json['order_notes'] ??
          json['orderNotes'],
    );
    final returnCustomerName = isReturn ? _readReturnPartyName(json) : null;
    final returnCustomerPhone = isReturn ? _readReturnPartyPhone(json) : null;

    final rtoDetails = RtoDetails.fromOrderJson(json);
    final rtoStatus = _readString(
          json['rto_status'] ?? json['rtoStatus'] ?? rtoDetails.status,
        ) ??
        rtoDetails.status;
    final partnerAmount = rtoDetails.formattedTotalEarning ??
        DeliveryFee.formatFromJson(
          json,
          pickupLatitude: pickupLatitude,
          pickupLongitude: pickupLongitude,
          deliveryLatitude: deliveryLatitude,
          deliveryLongitude: deliveryLongitude,
        );

    return DpOrder(
      id: _readString(json['id']),
      orderNumber: _readString(
            json['orderNumber'] ??
                json['order_number'] ??
                json['id'],
          ) ??
          '',
      status: json['status']?.toString() ?? '',
      flowType: _readString(
        json['flow_type'] ??
            json['flowType'] ??
            (json['delivery_details'] is Map ? json['delivery_details']['flow_type'] : null) ??
            (json['ui_labels'] is Map ? json['ui_labels']['flow_type'] : null) ??
            json['flow'] ??
            json['assignment_type'] ??
            json['assignmentType'] ??
            json['task_type'],
      ),
      stepLabels: stepLabels,
      apiNextActionLabel: apiNextActionLabel,
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
      customerName: returnCustomerName ??
          _readString(
            json['customer_name'] ??
                json['customerName'] ??
                customer?['name'] ??
                customer?['full_name'] ??
                customer?['fullName'] ??
                json['user_name'] ??
                json['userName'],
          ),
      customerPhone: returnCustomerPhone ??
          _readString(
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
      pickupAddress: pickupAddress,
      dropAddress: dropAddress,
      scheduledTime: _readString(
        json['scheduledTime'] ??
            json['scheduled_time'] ??
            json['scheduledAt'] ??
            json['assigned_at'] ??
            json['created_at'] ??
            json['time'],
      ),
      amount: partnerAmount,
      notes: _readReturnNotes(json) ??
          customerNote ??
          exceptFailureReason(
            json['notes'] ??
                json['note'] ??
                json['remarks'] ??
                json['remark'] ??
                json['comments'] ??
                json['comment'],
          ),
      returnNotes: _readReturnNotes(json) ?? rtoDetails.rtoNotes,
      instructions: exceptFailureReason(
        json['instructions'] ??
            json['delivery_instructions'] ??
            json['deliveryInstructions'] ??
            json['pickup_instructions'] ??
            json['pickupInstructions'] ??
            json['customer_instructions'] ??
            json['customerInstructions'] ??
            json['special_instructions'] ??
            json['specialInstructions'],
      ),
      weightKg: _readString(json['weight_kg'] ?? json['weightKg']),
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      arrivedAtIapAt: _readString(json['arrived_at_iap_at']),
      pickupConfirmedAt: _readString(json['pickup_confirmed_at']),
      inTransitAt: _readString(json['in_transit_at']),
      arrivedAtDeliveryAt: _readString(json['arrived_at_delivery_at']),
      deliveredAt: _readString(json['delivered_at']),
      completedAt: _readString(json['completed_at']),
      returnedToIapAt: _readString(
        json['returned_to_iap_at'] ?? json['returnedToIapAt'],
      ),
      rtoCompletedAt: _readString(
        json['rto_completed_at'] ?? json['rtoCompletedAt'],
      ),
      deliveryDate: _readDeliveryDate(json),
      deliveryTime: _readDeliveryTime(json),
      returnDate: _readReturnDate(json),
      returnTime: _readReturnTime(json),
      rejectionReason: _readString(
            json['rejection_reason'] ??
                json['rejectionReason'] ??
                json['reject_reason'] ??
                json['rejectReason'] ??
                json['not_delivered_reason'],
          ) ??
          rtoDetails.rtoNotes,
      parentOrderStatus: _readString(
        json['parent_order_status'] ??
            json['parentOrderStatus'] ??
            json['orderStatus'] ??
            json['order_status'],
      ),
      rtoStatus: rtoStatus,
      rtoDetails: rtoDetails.hasAnyData ? rtoDetails : null,
      waited10mins: _readInt(json['waited10mins'] ?? json['waited_10_mins']),
      pickupFailedImages: _readStringList(
        json['pickup_failed_images'] ??
            json['pickup_failed_image'] ??
            json['pickupFailedImages'],
      ),
      customerAddressId: _readCustomerAddressId(json),
    );
  }

  static String? _readCustomerAddressId(Map<String, dynamic> json) {
    final direct = _readString(
      json['customer_address_id'] ?? json['customerAddressId'],
    );
    if (direct != null) return direct;

    final items = json['items'] ?? json['orderItems'] ?? json['order_items'];
    if (items is! List) return null;
    for (final item in items) {
      if (item is! Map) continue;
      final kit = item['kitDetails'] ?? item['kit_details'];
      final id = _readString(
        item['customerAddressId'] ??
            item['customer_address_id'] ??
            (kit is Map
                ? (kit['customerAddressId'] ?? kit['customer_address_id'])
                : null),
      );
      if (id != null) return id;
    }
    return null;
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

  static String? _readReturnPartyName(Map<String, dynamic> json) {
    return _readReturnParty(
      json,
      const [
        'name',
        'full_name',
        'fullName',
        'customer_name',
        'customerName',
      ],
    );
  }

  static String? _readReturnPartyPhone(Map<String, dynamic> json) {
    return _readReturnParty(
      json,
      const [
        'mobile',
        'phone',
        'customer_mobile',
        'customerMobile',
        'customer_phone',
        'customerPhone',
        'phone_number',
        'phoneNumber',
      ],
    );
  }

  static String? _readReturnParty(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    final maps = [
      _tryParseMap(json['pickup_details'] ?? json['pickupDetails']),
      _tryParseMap(json['return_pickup_details'] ?? json['returnPickupDetails']),
      _tryParseMap(json['return_pickup'] ?? json['returnPickup']),
      _tryParseMap(json['return_request'] ?? json['returnRequest']),
      _tryParseMap(json['return_details'] ?? json['returnDetails']),
    ];
    for (final map in maps) {
      if (map == null) continue;
      for (final key in keys) {
        final value = _readString(map[key]);
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  static Map<String, dynamic>? _readCustomerMap(Map<String, dynamic> json) {
    final customer = json['customer'] ??
        json['user'] ??
        json['customer_details'] ??
        json['pickup_details'] ??
        json['pickupDetails'] ??
        json['return_details'] ??
        json['returnDetails'] ??
        json['return_request'] ??
        json['returnRequest'];
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

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  static String? _firstRealAddress(List<dynamic> candidates) {
    for (final candidate in candidates) {
      final address = _readAddress(candidate);
      if (!isDummyAddress(address)) return address;
    }
    return null;
  }

  static String? _readAddress(dynamic value) {
    if (value is List) {
      final maps = value.whereType<Map>().toList();
      final preferred = maps.firstWhere(
        (item) =>
            item['is_default'] == true ||
            item['isDefault'] == true ||
            item['default'] == true,
        orElse: () => maps.isNotEmpty ? maps.first : const {},
      );
      if (preferred.isNotEmpty) return _readAddress(preferred);
      for (final item in value) {
        final text = _readString(item);
        if (text != null) return text;
      }
      return null;
    }

    final map = _tryParseAddressMap(value);
    if (map != null) {
      final formatted = _formatAddressMap(map);
      return formatted.isEmpty ? null : formatted;
    }

    final text = _readString(value);
    if (text == null || text.toLowerCase() == 'null') return null;
    return text;
  }

  static String _formatAddressMap(Map<String, dynamic> map) {
    final parts = <String>[];

    void addPart(dynamic raw) {
      if (raw is Map) {
        final nested = _formatAddressMap(
          raw.map((key, val) => MapEntry(key.toString(), val)),
        );
        if (nested.isNotEmpty) addPart(nested);
        return;
      }
      final text = raw?.toString().trim();
      if (text == null || text.isEmpty || _isPlaceholderText(text)) return;
      final lower = text.toLowerCase();
      if (parts.any((part) => part.toLowerCase().contains(lower))) return;
      parts.add(text);
    }

    for (final key in const [
      'full_address',
      'fullAddress',
      'formatted_address',
      'formattedAddress',
      'address',
      'buildingNumber',
      'building_number',
      'house_no',
      'houseNo',
      'house_number',
      'flat_no',
      'flatNo',
      'door_no',
      'doorNo',
      'building_name',
      'buildingName',
      'streetName',
      'street_name',
      'street',
      'address_line1',
      'address_line_1',
      'addressLine1',
      'line1',
      'address_line2',
      'address_line_2',
      'addressLine2',
      'line2',
      'area',
      'locality',
      'landmark',
      'city',
      'district',
      'state',
      'country',
    ]) {
      addPart(map[key]);
    }

    if (parts.isEmpty) return '';

    final pincode = (map['pincode'] ??
            map['pin_code'] ??
            map['postal_code'] ??
            map['postalCode'] ??
            map['zip'] ??
            map['zipcode'])
        ?.toString()
        .trim();

    final address = parts.join(', ');
    if (pincode != null &&
        pincode.isNotEmpty &&
        pincode != 'null' &&
        !address.contains(pincode)) {
      return '$address - $pincode';
    }
    return address;
  }

  static bool isDummyAddress(String? address) {
    if (address == null) return true;
    if (address.toLowerCase().replaceAll(RegExp('[^a-z]'), '').isEmpty) {
      return true;
    }
    return _isPlaceholderText(address);
  }

  static bool _isPlaceholderText(String text) {
    final letters = text.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    if (letters.startsWith('customeraddress')) return true;
    const dummyValues = {
      'address',
      'addressnotavailable',
      'dummyaddress',
      'testaddress',
      'customer',
      'deliverylocation',
      'droplocation',
      'pickuplocation',
      'notavailable',
      'na',
      'null',
    };
    return dummyValues.contains(letters);
  }

  /// Last resort for payloads that put the customer address under a key not
  /// listed above. Skips pickup/hub addresses and placeholder values.
  static String? _deepFindCustomerAddress(
    dynamic node, {
    String? exclude,
    int depth = 0,
  }) {
    if (depth > 4) return null;
    if (node is List) {
      for (final item in node) {
        final found =
            _deepFindCustomerAddress(item, exclude: exclude, depth: depth + 1);
        if (found != null) return found;
      }
      return null;
    }
    if (node is! Map) return null;

    for (final entry in node.entries) {
      final key = entry.key.toString().toLowerCase();
      final value = entry.value;
      final isAddressKey = key.contains('address') &&
          !key.endsWith('id') &&
          !const ['pickup', 'iap', 'hub', 'warehouse', 'email', 'proof', 'type']
              .any(key.contains);
      if (isAddressKey) {
        final address = _readAddress(value);
        if (!isDummyAddress(address) &&
            address != exclude &&
            !address!.toUpperCase().contains('IAP')) {
          return address;
        }
      }
      if (value is Map || value is List) {
        if (key.contains('pickup') || key.contains('iap')) continue;
        final found =
            _deepFindCustomerAddress(value, exclude: exclude, depth: depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  static List<dynamic> _readItemCustomerAddresses(Map<String, dynamic> json) {
    final items = json['items'] ?? json['orderItems'] ?? json['order_items'];
    if (items is! List) return const [];
    final candidates = <dynamic>[];
    for (final item in items) {
      if (item is! Map) continue;
      final kit = item['kitDetails'] ?? item['kit_details'];
      for (final source in [item, if (kit is Map) kit]) {
        candidates
          ..add(source['customer_address'])
          ..add(source['customerAddress'])
          ..add(source['delivery_address'])
          ..add(source['deliveryAddress']);
      }
    }
    return candidates;
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
    final text = value.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    // YYYY-MM-DD or YYYY/MM/DD
    final isoMatch = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(text);
    if (isoMatch != null) {
      final y = isoMatch.group(1)!;
      final m = isoMatch.group(2)!.padLeft(2, '0');
      final d = isoMatch.group(3)!.padLeft(2, '0');
      return '$y-$m-$d';
    }

    // DD-MM-YYYY or DD/MM/YYYY
    final dmyMatch = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})').firstMatch(text);
    if (dmyMatch != null) {
      final d = dmyMatch.group(1)!.padLeft(2, '0');
      final m = dmyMatch.group(2)!.padLeft(2, '0');
      final y = dmyMatch.group(3)!;
      return '$y-$m-$d';
    }

    // DD Mon YYYY (e.g. 10 Oct 2026 or 10th Oct 2026)
    final monMatch = RegExp(r'^(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)\s+(\d{4})').firstMatch(text);
    if (monMatch != null) {
      final d = monMatch.group(1)!.padLeft(2, '0');
      final monthName = monMatch.group(2)!.toLowerCase();
      final y = monMatch.group(3)!;
      const monthMap = {
        'jan': '01', 'january': '01',
        'feb': '02', 'february': '02',
        'mar': '03', 'march': '03',
        'apr': '04', 'april': '04',
        'may': '05',
        'jun': '06', 'june': '06',
        'jul': '07', 'july': '07',
        'aug': '08', 'august': '08',
        'sep': '09', 'september': '09',
        'oct': '10', 'october': '10',
        'nov': '11', 'november': '11',
        'dec': '12', 'december': '12',
      };
      final m = monthMap[monthName];
      if (m != null) {
        return '$y-$m-$d';
      }
    }

    final dt = DateTime.tryParse(text);
    if (dt != null) {
      final y = dt.year.toString();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    return text;
  }

  static String? _readDeliveryDate(Map<String, dynamic> json) {
    final direct = _readString(
      json['delivery_date'] ??
          json['deliveryDate'] ??
          json['scheduled_date'] ??
          json['scheduledDate'],
    );
    if (direct != null) return _normalizeDateOnly(direct);
    return _normalizeDateOnly(
      _readKitDetailField(
        json,
        fieldKeys: const ['delivery_date', 'deliveryDate'],
      ),
    );
  }

  static String? _readDeliveryTime(Map<String, dynamic> json) {
    final direct = _readString(
      json['delivery_time'] ??
          json['deliveryTime'] ??
          json['scheduled_time'] ??
          json['scheduledTime'],
    );
    if (direct != null) return direct;
    return _readKitDetailField(
      json,
      fieldKeys: const ['delivery_time', 'deliveryTime'],
    );
  }

  static bool _hasReturnIndicator(Map<String, dynamic> json) {
    final flow = _readString(
      json['flow_type'] ??
          json['flowType'] ??
          (json['delivery_details'] is Map ? json['delivery_details']['flow_type'] : null) ??
          (json['ui_labels'] is Map ? json['ui_labels']['flow_type'] : null),
    )?.toLowerCase().trim();
    if (flow == 'return' || flow == 'pickup') return true;

    final status = _readString(json['status'])?.toLowerCase().trim() ?? '';
    if (status == 'return_assigned' ||
        status == 'returned_to_iap' ||
        status == 'return_failed' ||
        status.startsWith('return_')) {
      return true;
    }

    final type = _readString(
      json['order_type'] ??
          json['orderType'] ??
          json['assignment_type'] ??
          json['assignmentType'] ??
          json['type'],
    )?.toLowerCase().trim() ?? '';
    if (type.contains('return') || type == 'pickup') return true;

    final subStatus = _readString(json['sub_status'] ?? json['subStatus'])?.toLowerCase().trim() ?? '';
    if (subStatus.contains('return')) return true;

    final ordNum = _readString(json['order_number'] ?? json['orderNumber'])?.toUpperCase().trim() ?? '';
    if (ordNum.startsWith('RET') || ordNum.contains('-RET-') || ordNum.contains('_RET_')) {
      return true;
    }

    if (json['pickup_details'] != null ||
        json['pickupDetails'] != null ||
        json['return_pickup'] != null ||
        json['returnPickup'] != null ||
        json['return_pickup_details'] != null ||
        json['returnPickupDetails'] != null ||
        json['return_request'] != null ||
        json['returnRequest'] != null ||
        json['return_details'] != null ||
        json['returnDetails'] != null ||
        json['return_schedule'] != null ||
        json['returnSchedule'] != null ||
        json['returns'] != null) {
      return true;
    }

    return false;
  }

  static String? _readReturnDate(Map<String, dynamic> json) {
    final flow = _readString(
      json['flow_type'] ??
          json['flowType'] ??
          (json['delivery_details'] is Map ? json['delivery_details']['flow_type'] : null) ??
          (json['ui_labels'] is Map ? json['ui_labels']['flow_type'] : null),
    )?.toLowerCase().trim();

    final isReturn = _hasReturnIndicator(json);

    if (flow == 'delivery' && !isReturn) {
      return null;
    }

    final direct = _readString(
      json['return_date'] ??
          json['returnDate'] ??
          json['pickup_date'] ??
          json['pickupDate'] ??
          json['requested_return_date'] ??
          json['requestedReturnDate'] ??
          json['requested_pickup_date'] ??
          json['requestedPickupDate'] ??
          json['return_pickup_date'] ??
          json['returnPickupDate'] ??
          json['return_scheduled_date'] ??
          json['returnScheduledDate'] ??
          json['pickup_scheduled_date'] ??
          json['pickupScheduledDate'] ??
          json['return_slot_date'] ??
          json['returnSlotDate'] ??
          json['slot_date'] ??
          json['slotDate'] ??
          json['schedule_date'] ??
          json['scheduleDate'] ??
          json['scheduled_date'] ??
          json['scheduledDate'],
    );
    if (direct != null) return _normalizeDateOnly(direct);

    final mapsToCheck = [
      _tryParseMap(json['pickup_details'] ?? json['pickupDetails']),
      _tryParseMap(json['return_pickup'] ?? json['returnPickup']),
      _tryParseMap(json['return_pickup_details'] ?? json['returnPickupDetails']),
      _tryParseMap(json['pickup']),
      _tryParseMap(json['return_request'] ?? json['returnRequest']),
      _tryParseMap(json['return_details'] ?? json['returnDetails']),
      _tryParseMap(json['returns'] is Map ? json['returns'] : null),
      _tryParseMap(json['return_schedule'] ?? json['returnSchedule']),
      _tryParseMap(json['schedule']),
      _tryParseMap(json['order_schedule'] ?? json['orderSchedule']),
      _tryParseMap(json['scheduled_slot'] ?? json['scheduledSlot']),
      _tryParseMap(json['slot_details'] ?? json['slotDetails']),
      _tryParseMap(json['slot']),
      _tryParseMap(json['customer_schedule'] ?? json['customerSchedule']),
    ];

    for (final m in mapsToCheck) {
      if (m != null) {
        final val = _readString(
          m['pickup_date'] ??
              m['pickupDate'] ??
              m['return_date'] ??
              m['returnDate'] ??
              m['requested_date'] ??
              m['requestedDate'] ??
              m['requested_return_date'] ??
              m['requestedReturnDate'] ??
              m['requested_pickup_date'] ??
              m['requestedPickupDate'] ??
              m['return_pickup_date'] ??
              m['returnPickupDate'] ??
              m['slot_date'] ??
              m['slotDate'] ??
              m['schedule_date'] ??
              m['scheduleDate'] ??
              m['scheduled_date'] ??
              m['scheduledDate'] ??
              m['date'],
        );
        if (val != null) return _normalizeDateOnly(val);
      }
    }

    final returnsList = json['returns'];
    if (returnsList is List && returnsList.isNotEmpty) {
      for (final item in returnsList) {
        final itemMap = _tryParseMap(item);
        if (itemMap != null) {
          final val = _readString(
            itemMap['pickup_date'] ??
                itemMap['pickupDate'] ??
                itemMap['return_date'] ??
                itemMap['returnDate'] ??
                itemMap['requested_date'] ??
                itemMap['requestedDate'] ??
                itemMap['date'],
          );
          if (val != null) return _normalizeDateOnly(val);
        }
      }
    }

    final kitReturnDate = _readKitDetailField(
      json,
      fieldKeys: const [
        'return_date',
        'returnDate',
        'requested_return_date',
        'requestedReturnDate',
        'pickup_date',
        'pickupDate',
      ],
    );
    if (kitReturnDate != null) return _normalizeDateOnly(kitReturnDate);

    final items = json['items'];
    if (items is List && items.isNotEmpty) {
      for (final item in items) {
        final itemMap = _tryParseMap(item);
        if (itemMap != null) {
          final val = _readString(
            itemMap['return_date'] ??
                itemMap['returnDate'] ??
                itemMap['pickup_date'] ??
                itemMap['pickupDate'] ??
                itemMap['requested_return_date'],
          );
          if (val != null) return _normalizeDateOnly(val);
        }
      }
    }

    return null;
  }

  static String? _readReturnTime(Map<String, dynamic> json) {
    final flow = _readString(
      json['flow_type'] ??
          json['flowType'] ??
          (json['delivery_details'] is Map ? json['delivery_details']['flow_type'] : null) ??
          (json['ui_labels'] is Map ? json['ui_labels']['flow_type'] : null),
    )?.toLowerCase().trim();

    final isReturn = _hasReturnIndicator(json);

    if (flow == 'delivery' && !isReturn) {
      return null;
    }

    final direct = _readString(
      json['return_time'] ??
          json['returnTime'] ??
          json['pickup_time'] ??
          json['pickupTime'] ??
          json['pickup_slot'] ??
          json['pickupSlot'] ??
          json['requested_return_time'] ??
          json['requestedReturnTime'] ??
          json['requested_pickup_time'] ??
          json['requestedPickupTime'] ??
          json['return_slot'] ??
          json['returnSlot'] ??
          json['return_scheduled_time'] ??
          json['returnScheduledTime'] ??
          json['pickup_scheduled_time'] ??
          json['pickupScheduledTime'] ??
          json['time_slot'] ??
          json['timeSlot'] ??
          json['slot_time'] ??
          json['slotTime'] ??
          json['scheduled_slot'] ??
          json['scheduledSlot'],
    );
    if (direct != null) return _formatTimeDisplay(direct);

    final mapsToCheck = [
      _tryParseMap(json['pickup_details'] ?? json['pickupDetails']),
      _tryParseMap(json['return_pickup'] ?? json['returnPickup']),
      _tryParseMap(json['return_pickup_details'] ?? json['returnPickupDetails']),
      _tryParseMap(json['pickup']),
      _tryParseMap(json['return_request'] ?? json['returnRequest']),
      _tryParseMap(json['return_details'] ?? json['returnDetails']),
      _tryParseMap(json['returns'] is Map ? json['returns'] : null),
      _tryParseMap(json['return_schedule'] ?? json['returnSchedule']),
      _tryParseMap(json['schedule']),
      _tryParseMap(json['order_schedule'] ?? json['orderSchedule']),
      _tryParseMap(json['scheduled_slot'] ?? json['scheduledSlot']),
      _tryParseMap(json['slot_details'] ?? json['slotDetails']),
      _tryParseMap(json['slot']),
      _tryParseMap(json['customer_schedule'] ?? json['customerSchedule']),
    ];

    for (final m in mapsToCheck) {
      if (m != null) {
        final val = _readString(
          m['pickup_time'] ??
              m['pickupTime'] ??
              m['pickup_slot'] ??
              m['pickupSlot'] ??
              m['return_time'] ??
              m['returnTime'] ??
              m['requested_time'] ??
              m['requestedTime'] ??
              m['requested_return_time'] ??
              m['requestedReturnTime'] ??
              m['requested_pickup_time'] ??
              m['requestedPickupTime'] ??
              m['return_slot'] ??
              m['returnSlot'] ??
              m['time_slot'] ??
              m['timeSlot'] ??
              m['slot_time'] ??
              m['slotTime'] ??
              m['scheduled_time'] ??
              m['scheduledTime'] ??
              m['slot'] ??
              m['time'],
        );
        if (val != null) return _formatTimeDisplay(val);
      }
    }

    final returnsList = json['returns'];
    if (returnsList is List && returnsList.isNotEmpty) {
      for (final item in returnsList) {
        final itemMap = _tryParseMap(item);
        if (itemMap != null) {
          final val = _readString(
            itemMap['pickup_time'] ??
                itemMap['pickupTime'] ??
                itemMap['pickup_slot'] ??
                itemMap['return_time'] ??
                itemMap['returnTime'] ??
                itemMap['requested_time'] ??
                itemMap['time'] ??
                itemMap['slot'] ??
                itemMap['time_slot'],
          );
          if (val != null) return _formatTimeDisplay(val);
        }
      }
    }

    final kitReturnTime = _readKitDetailField(
      json,
      fieldKeys: const [
        'pickup_time',
        'pickupTime',
        'pickup_slot',
        'pickupSlot',
        'return_time',
        'returnTime',
        'requested_return_time',
        'requestedReturnTime',
        'requested_pickup_time',
        'requestedPickupTime',
        'return_slot',
        'returnSlot',
        'time_slot',
        'timeSlot',
      ],
    );
    if (kitReturnTime != null) return _formatTimeDisplay(kitReturnTime);

    final items = json['items'];
    if (items is List && items.isNotEmpty) {
      for (final item in items) {
        final itemMap = _tryParseMap(item);
        if (itemMap != null) {
          final val = _readString(
            itemMap['pickup_time'] ??
                itemMap['pickupTime'] ??
                itemMap['pickup_slot'] ??
                itemMap['return_time'] ??
                itemMap['returnTime'] ??
                itemMap['return_slot'] ??
                itemMap['time'] ??
                itemMap['slot'],
          );
          if (val != null) return _formatTimeDisplay(val);
        }
      }
    }

    final pickupTime = _readString(
      json['pickup_time'] ??
          json['pickupTime'] ??
          json['pickup_slot'] ??
          json['pickupSlot'],
    );
    if (pickupTime != null) return _formatTimeDisplay(pickupTime);

    return null;
  }

  static String? _readReturnNotes(Map<String, dynamic> json) {
    final flow = _readString(
      json['flow_type'] ??
          json['flowType'] ??
          (json['delivery_details'] is Map ? json['delivery_details']['flow_type'] : null) ??
          (json['ui_labels'] is Map ? json['ui_labels']['flow_type'] : null),
    )?.toLowerCase().trim();

    final isReturn = _hasReturnIndicator(json);

    if (flow == 'delivery' && !isReturn) {
      return null;
    }

    final direct = _readString(
      json['return_notes'] ??
          json['returnNotes'] ??
          json['pickup_note'] ??
          json['pickupNote'] ??
          json['pickup_notes'] ??
          json['pickupNotes'] ??
          json['return_reason'] ??
          json['returnReason'],
    );
    if (direct != null) return direct;

    final mapsToCheck = [
      _tryParseMap(json['pickup_details'] ?? json['pickupDetails']),
      _tryParseMap(json['return_pickup'] ?? json['returnPickup']),
      _tryParseMap(json['return_pickup_details'] ?? json['returnPickupDetails']),
      _tryParseMap(json['pickup']),
      _tryParseMap(json['return_request'] ?? json['returnRequest']),
      _tryParseMap(json['return_details'] ?? json['returnDetails']),
      _tryParseMap(json['returns'] is Map ? json['returns'] : null),
      _tryParseMap(json['order_notes'] is Map ? json['order_notes'] : null),
    ];

    for (final m in mapsToCheck) {
      if (m != null) {
        final val = _readString(
          m['note'] ??
              m['notes'] ??
              m['pickup_note'] ??
              m['pickupNote'] ??
              m['pickup_notes'] ??
              m['pickupNotes'] ??
              m['return_notes'] ??
              m['returnNotes'] ??
              m['customer_notes'] ??
              m['customerNotes'] ??
              m['customer_note'] ??
              m['customerNote'] ??
              m['order_notes'] ??
              m['orderNotes'] ??
              m['order_note'] ??
              m['orderNote'] ??
              m['reason'] ??
              m['return_reason'] ??
              m['returnReason'] ??
              m['comment'] ??
              m['comments'] ??
              m['remarks'] ??
              m['remark'] ??
              m['instructions'],
        );
        if (val != null) return val;
      }
    }

    final returnsList = json['returns'];
    if (returnsList is List && returnsList.isNotEmpty) {
      for (final item in returnsList) {
        final itemMap = _tryParseMap(item);
        if (itemMap != null) {
          final val = _readString(
            itemMap['note'] ??
                itemMap['notes'] ??
                itemMap['pickup_note'] ??
                itemMap['pickupNote'] ??
                itemMap['return_notes'] ??
                itemMap['returnNotes'] ??
                itemMap['reason'] ??
                itemMap['comment'],
          );
          if (val != null) return val;
        }
      }
    }

    final kitNotes = _readKitDetailField(
      json,
      fieldKeys: const [
        'pickup_note',
        'pickupNote',
        'pickup_notes',
        'pickupNotes',
        'note',
        'return_notes',
        'returnNotes',
        'return_reason',
        'returnReason',
        'notes',
        'reason',
      ],
    );
    if (kitNotes != null) return kitNotes;

    final items = json['items'];
    if (items is List && items.isNotEmpty) {
      for (final item in items) {
        final itemMap = _tryParseMap(item);
        if (itemMap != null) {
          final val = _readString(
            itemMap['note'] ??
                itemMap['notes'] ??
                itemMap['pickup_note'] ??
                itemMap['pickupNote'] ??
                itemMap['return_notes'] ??
                itemMap['returnNotes'] ??
                itemMap['return_reason'] ??
                itemMap['reason'],
          );
          if (val != null) return val;
        }
      }
    }

    if (isReturn) {
      final rootNotes = _readString(
        json['notes'] ??
            json['note'] ??
            json['order_notes'] ??
            json['orderNotes'] ??
            json['order_note'] ??
            json['orderNote'] ??
            json['customer_notes'] ??
            json['customerNotes'] ??
            json['customer_note'] ??
            json['customerNote'] ??
            json['reason'] ??
            json['return_reason'] ??
            json['comments'] ??
            json['comment'] ??
            json['remarks'] ??
            json['remark'],
      );
      if (rootNotes != null && rootNotes.toLowerCase() != 'null') return rootNotes;
    }

    return null;
  }

  static String? _formatTimeDisplay(String? value) {
    if (value == null) return null;
    final text = value.trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    final timeMatch = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(text);
    if (timeMatch != null) {
      final hour24 = int.tryParse(timeMatch.group(1)!);
      final minute = timeMatch.group(2)!;
      if (hour24 != null && hour24 >= 0 && hour24 < 24) {
        final period = hour24 >= 12 ? 'PM' : 'AM';
        final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
        return '$hour12:$minute $period';
      }
    }

    // Try parsing ISO date-time string e.g. "2026-10-10T14:30:00.000Z"
    if (text.contains('T') || text.contains('-') || text.contains(':')) {
      final dt = DateTime.tryParse(text);
      if (dt != null) {
        final local = dt.toLocal();
        final hour12 = local.hour > 12
            ? local.hour - 12
            : (local.hour == 0 ? 12 : local.hour);
        final minute = local.minute.toString().padLeft(2, '0');
        final period = local.hour >= 12 ? 'PM' : 'AM';
        return '$hour12:$minute $period';
      }
    }

    return text;
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
