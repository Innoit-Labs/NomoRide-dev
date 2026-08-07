export 'order_flow.dart';

import 'package:nomoride/features/home/data/models/order_flow.dart';

/// Backward-compatible alias for [OrderFlow].
typedef OrderJourney = OrderFlow;

extension OrderJourneyCompat on OrderFlow {
  bool get isReturnOrder => isReturn;

  FlowTransition? get nextStep => nextTransition;

  int get completedStepIndex => completedTransitionIndex;

  bool isStepCompleted(int index) => isTransitionCompleted(index);

  List<FlowTransition> get steps => transitions;

  bool get requiresConfirmation => requiresPhotoConfirmation;

  bool get showCustomerDeliveryAddress {
    if (isReturn) {
      return currentPhase == OrderPhase.returnToCustomer &&
          !isCompleted &&
          !isRejected;
    }
    return completedTransitionIndex >= 2 &&
        !isCompleted &&
        !isRejected &&
        currentPhase == OrderPhase.delivery;
  }

  bool get showIapReturnAddress =>
      isReturn &&
      currentPhase == OrderPhase.returnToIap &&
      !isCompleted &&
      !isRejected;

  bool get isAwaitingDeliveryStart {
    if (isReturn) return false;
    final next = nextTransition;
    return showCustomerDeliveryAddress &&
        completedTransitionIndex == 2 &&
        next?.apiStatus == 'start' &&
        next?.statusOccurrence == 1;
  }
}
