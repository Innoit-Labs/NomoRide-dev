import 'package:flutter/material.dart';
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

  static const undeliveredReturnTransitions = [
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

  List<FlowTransition> get transitions {
    if (order.isUndeliveredReturnToHub) {
      return undeliveredReturnTransitions;
    }
    return isReturn ? returnTransitions : deliveryTransitions;
  }

  String get apiStatusKey => order.apiStatusKey;

  bool get isRejected {
    if (order.isUndeliveredReturnToHub) return false;
    return order.isNotDelivered || order.isRejectedStatus;
  }

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
    // RTO hub return finished (incl. status still `not_delivered` + RTO_COMPLETED).
    if (order.isReturnedToIap || order.isRtoCompleted) {
      return true;
    }

    if (isReturn || order.isUndeliveredReturnToHub) {
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

  int get completedTransitionIndex {
    if (order.isUndeliveredReturnToHub) {
      return _undeliveredReturnCompletedIndex;
    }
    return isReturn ? _returnCompletedIndex : _deliveryCompletedIndex;
  }

  int get _undeliveredReturnCompletedIndex {
    if (order.isReturnedToIap || apiStatusKey == 'completed') {
      return undeliveredReturnTransitions.length - 1;
    }

    final status = apiStatusKey;
    switch (status) {
      case 'not_delivered':
      case 'failed':
      case 'delivery_failed':
        return -1;
      case 'in_transit_to_iap':
      case 'in_transit':
      case 'start':
        return 0;
      case 'arrived_at_iap':
      case 'arrived':
        return 1;
      case 'confirm_delivery':
      case 'delivered':
        return 2;
      case 'delivery_success':
      case 'returned_to_iap':
      case 'completed':
        return undeliveredReturnTransitions.length - 1;
    }

    return -1;
  }

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
      case 'in_transit_to_customer':
        return 0;
      case 'in_transit_to_iap':
        return 0;
      case 'arrived_at_customer':
        return 1;
      case 'arrived_at_iap':
        if (_hasTs(order.pickupConfirmedAt)) return 4;
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

    final serverNextLabel = order.apiNextActionLabel?.trim();
    if (serverNextLabel != null && serverNextLabel.isNotEmpty) {
      return serverNextLabel;
    }

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
            return 'Start Trip to Hub';
          case OrderPhase.delivery:
            return 'Start Delivery to Customer';
          case OrderPhase.returnToCustomer:
            return 'Start Trip to Customer';
          case OrderPhase.returnToIap:
            return 'Head to Hub for Drop-off';
        }
      case 'arrived':
        switch (transition.phase) {
          case OrderPhase.pickup:
            return 'Arrived at Hub';
          case OrderPhase.delivery:
            return 'Arrived at Customer';
          case OrderPhase.returnToCustomer:
            return 'Arrived at Customer';
          case OrderPhase.returnToIap:
            return 'Arrived at Hub';
        }
      case 'confirm_pickup':
        return transition.phase == OrderPhase.returnToCustomer
            ? 'Collect Return Items (Photo)'
            : 'Collect & Verify Kit (Photo)';
      case 'confirm_delivery':
        return transition.phase == OrderPhase.returnToIap
            ? 'Handover Items to IAP Hub'
            : 'Confirm Handover (Photo)';
      case 'delivery_success':
        return isReturn ? 'Complete Return' : 'Finish Order';
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
    if (order.isUndeliveredReturnToHub) {
      return OrderPhase.returnToIap;
    }
    final next = nextTransition;
    if (next != null) return next.phase;
    final index = completedTransitionIndex;
    if (index >= 0 && index < transitions.length) {
      return transitions[index].phase;
    }
    return isReturn ? OrderPhase.returnToCustomer : OrderPhase.pickup;
  }

  /// In return flow: whether the rider has reached the customer's pickup location.
  bool get hasArrivedAtCustomerLocation {
    if (!isReturn) return false;
    // Step index >= 1 means arrival at customer location is completed.
    if (completedTransitionIndex >= 1) return true;
    if (_hasTs(order.pickupConfirmedAt) ||
        _hasTs(order.arrivedAtDeliveryAt) ||
        _hasTs(order.deliveredAt) ||
        _hasTs(order.completedAt)) {
      return true;
    }
    final status = apiStatusKey;
    switch (status) {
      case 'arrived':
      case 'arrived_at_customer':
      case 'arrived_at_iap':
      case 'confirm_pickup':
      case 'pickup_confirmed':
      case 'picked_up':
      case 'in_transit_to_delivery':
      case 'arrived_at_delivery':
      case 'confirm_delivery':
      case 'delivered':
      case 'delivery_success':
      case 'returned_to_iap':
      case 'completed':
        return true;
      default:
        return false;
    }
  }

  String get statusBadgeLabel => statusBadgeInfo.label;

  ({String label, Color color, Color backgroundColor, IconData icon}) get statusBadgeInfo {
    if (order.isUndeliveredReturnToHub) {
      if (isCompleted) {
        return (
          label: 'Returned to IAP Store',
          color: const Color(0xFF4CAF50),
          backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
          icon: Icons.check_circle_outline,
        );
      }
      final idx = completedTransitionIndex;
      if (idx < 0) {
        return (
          label: 'Return to IAP Store',
          color: const Color(0xFFFFA726),
          backgroundColor: const Color(0xFFFFA726).withValues(alpha: 0.15),
          icon: Icons.storefront_outlined,
        );
      }
      if (idx == 0) {
        return (
          label: 'En Route to Hub',
          color: const Color(0xFF42A5F5),
          backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.15),
          icon: Icons.directions_bike_outlined,
        );
      }
      if (idx == 1) {
        return (
          label: 'At IAP Store',
          color: const Color(0xFFAB47BC),
          backgroundColor: const Color(0xFFAB47BC).withValues(alpha: 0.15),
          icon: Icons.storefront_outlined,
        );
      }
      return (
        label: 'Handover at Hub',
        color: const Color(0xFF66BB6A),
        backgroundColor: const Color(0xFF66BB6A).withValues(alpha: 0.15),
        icon: Icons.task_alt_outlined,
      );
    }

    if (isReturn) {
      if (isRejected) {
        return (
          label: 'Return Failed',
          color: Colors.redAccent,
          backgroundColor: Colors.red.withValues(alpha: 0.12),
          icon: Icons.cancel_outlined,
        );
      }
      if (isCompleted) {
        return (
          label: 'Return Completed',
          color: const Color(0xFF4CAF50),
          backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
          icon: Icons.check_circle_outline,
        );
      }

      final status = apiStatusKey;
      if (status == 'assigned' ||
          status == 'return_assigned' ||
          completedTransitionIndex < 0) {
        return (
          label: 'Return Accepted',
          color: const Color(0xFFE6C27A),
          backgroundColor: const Color(0xFFE6C27A).withValues(alpha: 0.15),
          icon: Icons.assignment_outlined,
        );
      }

      // First leg is always the customer, even when the forward delivery
      // left pickup/in-transit timestamps on the same order.
      const customerLeg = {
        'accepted',
        'in_progress',
        'start',
        'in_transit',
        'in_transit_to_customer',
        'in_transit_to_iap',
        'arrived',
        'arrived_at_customer',
      };
      if (customerLeg.contains(status) ||
          (status == 'arrived_at_iap' && !_hasTs(order.pickupConfirmedAt))) {
        return (
          label: 'En Route to Customer Location',
          color: const Color(0xFF42A5F5),
          backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.15),
          icon: Icons.directions_bike_outlined,
        );
      }

      if (!hasArrivedAtCustomerLocation) {
        return (
          label: 'En Route to Customer Location',
          color: const Color(0xFF42A5F5),
          backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.15),
          icon: Icons.directions_bike_outlined,
        );
      }

      // Arrived at hub for drop-off / handover
      if (completedTransitionIndex >= 4 ||
          status == 'arrived_at_delivery' ||
          (status == 'arrived_at_iap' && _hasTs(order.pickupConfirmedAt))) {
        if (completedTransitionIndex >= 5 ||
            status == 'confirm_delivery' ||
            status == 'delivered') {
          return (
            label: 'Handover at Hub',
            color: const Color(0xFF66BB6A),
            backgroundColor: const Color(0xFF66BB6A).withValues(alpha: 0.15),
            icon: Icons.task_alt_outlined,
          );
        }
        return (
          label: 'At Hub for Return',
          color: const Color(0xFFAB47BC),
          backgroundColor: const Color(0xFFAB47BC).withValues(alpha: 0.15),
          icon: Icons.storefront_outlined,
        );
      }

      // Once arrived at customer location (and on the way to Hub) -> En Route to Hub
      return (
        label: 'En Route to Hub',
        color: const Color(0xFF42A5F5),
        backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.15),
        icon: Icons.directions_bike_outlined,
      );
    }

    // Keep the delivery outcome visible even after RTO is completed.
    if (order.isNotDelivered) {
      return (
        label: 'Not Delivered',
        color: Colors.redAccent,
        backgroundColor: Colors.red.withValues(alpha: 0.12),
        icon: Icons.cancel_outlined,
      );
    }

    if (isRejected) {
      return (
        label: 'Delivery Failed',
        color: Colors.redAccent,
        backgroundColor: Colors.red.withValues(alpha: 0.12),
        icon: Icons.cancel_outlined,
      );
    }

    if (isCompleted) {
      return (
        label: 'Completed',
        color: const Color(0xFF4CAF50),
        backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
        icon: Icons.check_circle_outline,
      );
    }

    final status = apiStatusKey;
    switch (status) {
      case 'assigned':
      case 'accepted':
        return (
          label: 'Accepted',
          color: const Color(0xFFE6C27A),
          backgroundColor: const Color(0xFFE6C27A).withValues(alpha: 0.15),
          icon: Icons.assignment_outlined,
        );
      case 'in_transit_to_iap':
        return (
          label: 'En Route to Hub',
          color: const Color(0xFF42A5F5),
          backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.15),
          icon: Icons.directions_bike_outlined,
        );
      case 'arrived_at_iap':
        return (
          label: 'At IAP Store',
          color: const Color(0xFFAB47BC),
          backgroundColor: const Color(0xFFAB47BC).withValues(alpha: 0.15),
          icon: Icons.storefront_outlined,
        );
      case 'confirm_pickup':
      case 'pickup_confirmed':
      case 'picked_up':
        return (
          label: 'Kit Collected',
          color: const Color(0xFFFFA726),
          backgroundColor: const Color(0xFFFFA726).withValues(alpha: 0.15),
          icon: Icons.inventory_2_outlined,
        );
      case 'in_transit_to_delivery':
      case 'in_transit_to_customer':
        return (
          label: 'Out for Delivery',
          color: const Color(0xFF29B6F6),
          backgroundColor: const Color(0xFF29B6F6).withValues(alpha: 0.15),
          icon: Icons.local_shipping_outlined,
        );
      case 'arrived_at_delivery':
      case 'arrived_at_customer':
        return (
          label: 'At Customer Location',
          color: const Color(0xFF7E57C2),
          backgroundColor: const Color(0xFF7E57C2).withValues(alpha: 0.15),
          icon: Icons.person_pin_circle_outlined,
        );
      case 'confirm_delivery':
      case 'delivered':
        return (
          label: 'Handover Done',
          color: const Color(0xFF66BB6A),
          backgroundColor: const Color(0xFF66BB6A).withValues(alpha: 0.15),
          icon: Icons.task_alt_outlined,
        );
      case 'delivery_success':
      case 'completed':
        return (
          label: 'Completed',
          color: const Color(0xFF4CAF50),
          backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
          icon: Icons.check_circle_outline,
        );
      case 'start':
      case 'in_progress':
        if (_hasTs(order.pickupConfirmedAt)) {
          return (
            label: 'Out for Delivery',
            color: const Color(0xFF29B6F6),
            backgroundColor: const Color(0xFF29B6F6).withValues(alpha: 0.15),
            icon: Icons.local_shipping_outlined,
          );
        }
        return (
          label: 'En Route to Hub',
          color: const Color(0xFF42A5F5),
          backgroundColor: const Color(0xFF42A5F5).withValues(alpha: 0.15),
          icon: Icons.directions_bike_outlined,
        );
      default:
        final idx = completedTransitionIndex;
        final label = idx >= 0 ? completedLabelForIndex(idx) : 'Trip Accepted';
        return (
          label: label,
          color: const Color(0xFFE6C27A),
          backgroundColor: const Color(0xFFE6C27A).withValues(alpha: 0.15),
          icon: Icons.assignment_outlined,
        );
    }
  }

  String get statusSummary => statusBadgeLabel;

  bool get requiresPhotoConfirmation {
    final next = nextTransition?.apiStatus;
    return next == 'confirm_pickup' || next == 'confirm_delivery';
  }

  bool get requiresReturnConfirmation => isReturn && requiresPhotoConfirmation;
}

enum OrderPhase { pickup, delivery, returnToCustomer, returnToIap }
