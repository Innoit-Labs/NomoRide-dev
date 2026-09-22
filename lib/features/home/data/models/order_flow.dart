import 'package:nomoride/features/home/data/models/dp_order.dart';

/// A single transition in the delivery/return workflow.
class FlowTransition {
  const FlowTransition({
    required this.apiStatus,
    required this.statusOccurrence,
    required this.phase,
  });

  final String apiStatus;
  final int statusOccurrence;
  final OrderPhase phase;
}

class OrderFlow {
  const OrderFlow(this.order);

  final DpOrder order;

  static const deliveryTransitions = [
    FlowTransition(
      apiStatus: 'start',
      statusOccurrence: 0,
      phase: OrderPhase.pickup,
    ),
    FlowTransition(
      apiStatus: 'arrived',
      statusOccurrence: 0,
      phase: OrderPhase.pickup,
    ),
    FlowTransition(
      apiStatus: 'confirm_pickup',
      statusOccurrence: 0,
      phase: OrderPhase.pickup,
    ),
    FlowTransition(
      apiStatus: 'start',
      statusOccurrence: 1,
      phase: OrderPhase.delivery,
    ),
    FlowTransition(
      apiStatus: 'arrived',
      statusOccurrence: 1,
      phase: OrderPhase.delivery,
    ),
    FlowTransition(
      apiStatus: 'confirm_delivery',
      statusOccurrence: 0,
      phase: OrderPhase.delivery,
    ),
    FlowTransition(
      apiStatus: 'delivery_success',
      statusOccurrence: 0,
      phase: OrderPhase.delivery,
    ),
  ];

  static const returnTransitions = [
    FlowTransition(
      apiStatus: 'start',
      statusOccurrence: 0,
      phase: OrderPhase.returnToCustomer,
    ),
    FlowTransition(
      apiStatus: 'arrived',
      statusOccurrence: 0,
      phase: OrderPhase.returnToCustomer,
    ),
    FlowTransition(
      apiStatus: 'confirm_pickup',
      statusOccurrence: 0,
      phase: OrderPhase.returnToCustomer,
    ),
    FlowTransition(
      apiStatus: 'start',
      statusOccurrence: 1,
      phase: OrderPhase.returnToIap,
    ),
    FlowTransition(
      apiStatus: 'arrived',
      statusOccurrence: 1,
      phase: OrderPhase.returnToIap,
    ),
    FlowTransition(
      apiStatus: 'confirm_delivery',
      statusOccurrence: 0,
      phase: OrderPhase.returnToIap,
    ),
    FlowTransition(
      apiStatus: 'delivery_success',
      statusOccurrence: 0,
      phase: OrderPhase.returnToIap,
    ),
  ];

  bool get isReturn => order.isReturnFlow;

  List<FlowTransition> get transitions =>
      isReturn ? returnTransitions : deliveryTransitions;

  String get apiStatusKey => order.apiStatusKey;

  bool get isRejected => order.isNotDelivered || order.isRejectedStatus;

  static const _inProgressStatuses = {
    'assigned',
    'return_assigned',
    'accepted',
    'in_progress',
    'start',
    'in_transit',
    'in_transit_to_iap',
    'in_transit_to_customer',
    'in_transit_to_delivery',
    'arrived',
    'arrived_at_iap',
    'arrived_at_customer',
    'arrived_at_delivery',
    'confirm_pickup',
    'pickup_confirmed',
    'confirm_delivery',
    'delivered',
    'delivery_success',
  };

  bool get isCompleted {
    if (isReturn) {
      return apiStatusKey == 'completed' ||
          apiStatusKey == 'returned_to_iap';
    }

    final status = apiStatusKey;
    if (status == 'delivery_success' || status == 'completed') {
      return true;
    }

    final completedAt = order.completedAt?.trim();
    if (completedAt != null &&
        completedAt.isNotEmpty &&
        !_inProgressStatuses.contains(status)) {
      return true;
    }

    return false;
  }

  /// No extra auto-finalize step is required for return flow.
  bool get needsReturnedToIapFollowUp => false;

  int get completedTransitionIndex =>
      isReturn ? _returnCompletedIndex : _deliveryCompletedIndex;

  bool _hasTs(String? value) => value != null && value.trim().isNotEmpty;

  /// Status-first mapping so backend statuses like [in_transit_to_iap]
  /// never fall back to the initial "start" action.
  int get _deliveryCompletedIndex {
    if (isRejected) return -1;
    if (isCompleted) return deliveryTransitions.length - 1;

    final status = apiStatusKey;
    switch (status) {
      case 'assigned':
        return -1;
      case 'accepted':
      case 'in_progress':
      case 'in_transit_to_iap':
        return 0;
      case 'arrived_at_iap':
        return 1;
      case 'confirm_pickup':
      case 'pickup_confirmed':
      case 'picked_up':
        return 2;
      case 'in_transit_to_delivery':
      case 'in_transit_to_customer':
        return 3;
      case 'arrived_at_delivery':
      case 'arrived_at_customer':
        return 4;
      case 'confirm_delivery':
      case 'delivered':
        return 5;
      case 'delivery_success':
      case 'completed':
        return deliveryTransitions.length - 1;
    }

    // Ambiguous short statuses — resolve carefully with timestamps.
    if (status == 'arrived') {
      if (_hasTs(order.deliveredAt) || _hasTs(order.arrivedAtDeliveryAt)) {
        return 4;
      }
      // Pickup done but not yet at customer → stay after confirm_pickup.
      if (_hasTs(order.pickupConfirmedAt)) return 2;
      if (_hasTs(order.arrivedAtIapAt)) return 1;
      return 1;
    }

    if (status == 'start' || status == 'in_transit') {
      if (_hasTs(order.pickupConfirmedAt)) return 3;
      return 0;
    }

    if (_hasTs(order.deliveredAt)) return 5;
    if (_hasTs(order.arrivedAtDeliveryAt)) return 4;
    if (_hasTs(order.pickupConfirmedAt)) {
      if (_hasTs(order.inTransitAt)) return 3;
      return 2;
    }
    if (_hasTs(order.arrivedAtIapAt)) return 1;

    return -1;
  }

  int get _returnCompletedIndex {
    if (isRejected) return -1;
    if (apiStatusKey == 'returned_to_iap') {
      return returnTransitions.length - 1;
    }

    final status = apiStatusKey;
    switch (status) {
      case 'assigned':
      case 'return_assigned':
        return -1;
      case 'accepted':
      case 'in_progress':
      case 'in_transit_to_iap':
        return 0;
      case 'arrived_at_iap':
        return 1;
      case 'confirm_pickup':
      case 'pickup_confirmed':
      case 'picked_up':
        return 2;
      case 'in_transit_to_delivery':
        return 3;
      case 'arrived_at_delivery':
        return 4;
      case 'confirm_delivery':
      case 'delivered':
        return 5;
      case 'delivery_success':
        return 6;
      case 'completed':
        return returnTransitions.length - 1;
      case 'returned_to_iap':
        return returnTransitions.length - 1;
    }

    // Ambiguous short statuses — resolve carefully with timestamps.
    if (status == 'arrived') {
      if (_hasTs(order.arrivedAtDeliveryAt) || _hasTs(order.deliveredAt)) {
        return 4;
      }
      if (_hasTs(order.pickupConfirmedAt)) return 2;
      if (_hasTs(order.arrivedAtIapAt)) return 1;
      return 1;
    }

    if (status == 'start' || status == 'in_transit') {
      if (_hasTs(order.pickupConfirmedAt)) return 3;
      return 0;
    }

    if (_hasTs(order.deliveredAt)) return 5;
    if (_hasTs(order.arrivedAtDeliveryAt)) return 4;
    if (_hasTs(order.pickupConfirmedAt)) {
      if (_hasTs(order.inTransitAt)) return 3;
      return 2;
    }
    if (_hasTs(order.arrivedAtIapAt)) return 1;

    return -1;
  }

  FlowTransition? get nextTransition {
    if (isRejected || isCompleted) return null;
    final nextIndex = completedTransitionIndex + 1;
    if (nextIndex < 0 || nextIndex >= transitions.length) return null;
    return transitions[nextIndex];
  }

  String get nextActionLabel {
    final next = nextTransition;
    if (next == null) return '';

    final fromApi = order.labelForStep(
      apiStatus: next.apiStatus,
      occurrence: next.statusOccurrence,
      currentStatus: apiStatusKey,
      preferCurrentStatus: true,
    );

    final generic = _formatStatus(next.apiStatus);
    if (fromApi.trim().isNotEmpty &&
        fromApi.toLowerCase() != generic.toLowerCase()) {
      return fromApi;
    }

    return defaultActionLabel(next);
  }

  String defaultActionLabel(FlowTransition transition) {
    switch (transition.apiStatus) {
      case 'start':
        switch (transition.phase) {
          case OrderPhase.pickup:
            return 'Head to IAP to collect kit';
          case OrderPhase.delivery:
            return 'Arrived at customer location';
          case OrderPhase.returnToCustomer:
            return 'Head to customer for return pickup';
          case OrderPhase.returnToIap:
            return 'Head to IAP to drop off return';
        }
      case 'arrived':
        switch (transition.phase) {
          case OrderPhase.pickup:
            return 'Confirm kit pickup from IAP';
          case OrderPhase.delivery:
            return 'Confirm delivery to customer';
          case OrderPhase.returnToCustomer:
            return 'Confirm kit pickup from customer';
          case OrderPhase.returnToIap:
            return 'Confirm drop-off at IAP';
        }
      case 'confirm_pickup':
        return transition.phase == OrderPhase.returnToCustomer
            ? 'Head to IAP to drop off return'
            : 'Head to customer for delivery';
      case 'confirm_delivery':
        return transition.phase == OrderPhase.returnToIap
            ? 'Mark return as complete'
            : 'Mark delivery as complete';
      case 'delivery_success':
        return isReturn ? 'Return completed' : 'Delivery completed';
      default:
        return _formatStatus(transition.apiStatus);
    }
  }

  static String _formatStatus(String apiStatus) {
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

  String completedLabelForIndex(int index) {
    if (index < 0) {
      return order.labelForStep(
        apiStatus: 'assigned',
        occurrence: 0,
        currentStatus: apiStatusKey,
      );
    }
    if (index >= transitions.length) return '';
    final transition = transitions[index];
    final fromApi = order.labelForStep(
      apiStatus: transition.apiStatus,
      occurrence: transition.statusOccurrence,
      currentStatus: _statusAfterTransition(index),
      preferCurrentStatus: true,
    );
    final generic = _formatStatus(transition.apiStatus);
    if (fromApi.trim().isNotEmpty &&
        fromApi.toLowerCase() != generic.toLowerCase()) {
      return fromApi;
    }
    return defaultActionLabel(transition);
  }

  String _statusAfterTransition(int index) {
    if (index < 0 || index >= transitions.length) return apiStatusKey;
    return transitions[index].apiStatus;
  }

  bool isTransitionCompleted(int index) {
    if (isRejected) return false;
    if (isReturn &&
        (apiStatusKey == 'returned_to_iap' ||
            apiStatusKey == 'completed')) {
      return true;
    }
    return index <= completedTransitionIndex;
  }

  bool get hasStarted => completedTransitionIndex >= 0;

  OrderPhase get currentPhase {
    final next = nextTransition;
    if (next != null) return next.phase;
    final index = completedTransitionIndex;
    if (index >= 0 && index < transitions.length) {
      return transitions[index].phase;
    }
    return isReturn ? OrderPhase.returnToCustomer : OrderPhase.pickup;
  }

  String get statusSummary {
    if (isRejected) {
      return isReturn
          ? 'Return Failed'
          : (order.isNotDelivered ? 'Not Delivered' : 'Rejected');
    }
    if (isCompleted) {
      return isReturn ? 'Return Success' : 'Delivery Success';
    }
    final index = completedTransitionIndex;
    if (index >= 0) return completedLabelForIndex(index);
    return isReturn ? 'Return Assigned' : 'Assigned';
  }

  bool get requiresPhotoConfirmation {
    final next = nextTransition?.apiStatus;
    return next == 'confirm_pickup' || next == 'confirm_delivery';
  }

  bool get requiresReturnConfirmation => isReturn && requiresPhotoConfirmation;
}

enum OrderPhase { pickup, delivery, returnToCustomer, returnToIap }
