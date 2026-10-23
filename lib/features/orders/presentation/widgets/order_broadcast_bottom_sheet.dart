import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/core/services/broadcast_notification_service.dart';
import 'package:nomoride/core/services/broadcast_sound_player.dart';
import 'package:nomoride/core/services/socket_service.dart';
import 'package:nomoride/core/utils/custom_snack_bar.dart';
import 'package:nomoride/core/utils/size_utils.dart';
import 'package:nomoride/features/home/data/orders_repository.dart';
import 'package:nomoride/features/orders/data/models/order_broadcast_model.dart';
import 'package:nomoride/routes/app_routes.dart';
import 'package:nomoride/theme/theme_helper.dart';

/// Represents an individual active broadcast card and its countdown timer state.
class OrderBroadcastItem {
  final OrderBroadcastModel broadcast;
  final int totalSeconds;
  final ValueNotifier<int> remainingSecondsNotifier;
  Timer? countdownTimer;
  bool isAccepting = false;
  bool _disposed = false;

  OrderBroadcastItem({
    required this.broadcast,
    required this.totalSeconds,
    required this.remainingSecondsNotifier,
  });

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    countdownTimer?.cancel();
    countdownTimer = null;
    remainingSecondsNotifier.dispose();
  }
}

/// Controller that manages multi-broadcast state, carousel synchronization, and top notch overlays.
class OrderBroadcastManager {
  OrderBroadcastManager._();
  static final OrderBroadcastManager instance = OrderBroadcastManager._();

  OrdersRepository? _repo;
  OrdersRepository get _ordersRepository => _repo ??= OrdersRepository();

  final Set<String> _acceptingOrderIds = {};
  final List<OrderBroadcastItem> _items = [];
  final ValueNotifier<List<OrderBroadcastItem>> itemsNotifier =
      ValueNotifier<List<OrderBroadcastItem>>([]);

  Timer? _hapticTimer;
  DateTime? _lastAlertTime;
  OverlayEntry? _notchOverlay;
  bool _isDialogOpen = false;

  int _currentPageIndex = 0;
  int get currentPageIndex => _currentPageIndex;
  set currentPageIndex(int index) => _currentPageIndex = index;

  List<OrderBroadcastModel> get activeBroadcasts =>
      _items.map((e) => e.broadcast).toList();

  String? get currentActiveOrderId {
    if (_items.isEmpty) return null;
    final index = _currentPageIndex.clamp(0, _items.length - 1);
    return _items[index].broadcast.orderId;
  }

  List<String> get activeOrderIds =>
      _items.map((e) => e.broadcast.orderId).toList();

  bool hasBroadcast(String id) {
    return _items.any((item) =>
        item.broadcast.orderId == id ||
        item.broadcast.broadcastId == id ||
        item.broadcast.uniqueId == id);
  }

  /// Starts or appends a broadcast order to the multi-broadcast queue.
  void startBroadcast(OrderBroadcastModel broadcast) {
    if (broadcast.orderId.isEmpty) return;

    // Prevent duplicate entries
    if (hasBroadcast(broadcast.orderId) ||
        (broadcast.broadcastId.isNotEmpty &&
            hasBroadcast(broadcast.broadcastId))) {
      debugPrint(
          '[OrderBroadcastManager] Broadcast ${broadcast.orderId} is already active.');
      return;
    }

    final rawSec = broadcast.timerSeconds;
    final totalSec = rawSec > 0 ? rawSec : 30;
    final remainingNotifier = ValueNotifier<int>(totalSec);

    final item = OrderBroadcastItem(
      broadcast: broadcast,
      totalSeconds: totalSec,
      remainingSecondsNotifier: remainingNotifier,
    );

    // Setup per-card countdown timer
    item.countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (item.remainingSecondsNotifier.value <= 1) {
        timer.cancel();
        _handleItemExpired(item);
      } else {
        item.remainingSecondsNotifier.value--;
      }
    });

    _items.add(item);
    itemsNotifier.value = List.unmodifiable(_items);

    _playAlertWithThrottle(broadcast);
    _startPeriodicHaptics();

    if (_isDialogOpen) {
      // Dialog is already open, carousel will dynamically show new card
      debugPrint(
          '[OrderBroadcastManager] Added broadcast ${broadcast.orderId} to existing carousel. Total: ${_items.length}');
    } else if (_notchOverlay != null) {
      // Minimized notch is active, refresh notch content
      _showNotchOverlay();
    } else {
      // Show full carousel modal
      _showCenterDialog();
    }
  }

  void _playAlertWithThrottle(OrderBroadcastModel broadcast) {
    final soundUrl = broadcast.soundUrl;
    final hasSound = soundUrl != null && soundUrl.trim().isNotEmpty;
    if (hasSound) {
      // Keep the alert playing for as long as the broadcast card is visible.
      final popupSeconds = broadcast.timerSeconds > 0
          ? broadcast.timerSeconds
          : (broadcast.soundDurationSeconds ?? 30);
      final soundSeconds = broadcast.soundDurationSeconds != null &&
              broadcast.soundDurationSeconds! > popupSeconds
          ? broadcast.soundDurationSeconds!
          : popupSeconds;
      unawaited(BroadcastSoundPlayer.play(
        soundUrl,
        durationSeconds: soundSeconds,
      ));
    }

    final now = DateTime.now();
    if (_lastAlertTime == null ||
        now.difference(_lastAlertTime!) > const Duration(milliseconds: 2000)) {
      _lastAlertTime = now;
      try {
        HapticFeedback.heavyImpact();
        if (!hasSound) SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    } else {
      // Subtle medium impact if successive broadcasts hit rapidly
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  void _startPeriodicHaptics() {
    if (_hapticTimer != null && _hapticTimer!.isActive) return;

    _hapticTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_items.isNotEmpty && !_items.any((e) => e.isAccepting)) {
        try {
          HapticFeedback.lightImpact();
        } catch (_) {}
      } else if (_items.isEmpty) {
        _hapticTimer?.cancel();
        _hapticTimer = null;
      }
    });
  }

  void _handleItemExpired(OrderBroadcastItem item) {
    final orderNumber = item.broadcast.orderNumber.isNotEmpty
        ? item.broadcast.orderNumber
        : item.broadcast.orderId;

    SocketService.instance.emitOrderDismiss(item.broadcast.orderId);
    _removeItem(item);

    final context = SessionGuard.navigatorKey.currentContext;
    if (context != null) {
      CustomSnackBar.showInfo(
        context,
        'Order #$orderNumber request timed out.',
      );
    }

    if (_items.isEmpty) {
      dismissAll();
    }
  }

  /// Stops the broadcast sound once no request is waiting for a response.
  void _syncBroadcastSound() {
    if (_items.any((item) => !item.isAccepting)) return;
    unawaited(BroadcastSoundPlayer.stop());
  }

  /// Re-opens the full popup when broadcasts are waiting behind the notch.
  void bringToFront() {
    if (_items.isEmpty || _isDialogOpen) return;
    _showCenterDialog();
  }

  void _removeItem(OrderBroadcastItem item) {
    final index = _items.indexOf(item);
    BroadcastNotificationService.cancel(item.broadcast.orderId);
    item.dispose();
    _items.remove(item);
    itemsNotifier.value = List.unmodifiable(_items);
    _syncBroadcastSound();

    if (_currentPageIndex >= _items.length && _items.isNotEmpty) {
      _currentPageIndex = _items.length - 1;
    }
  }

  bool _isOwnClaim(String orderId, String? claimedByPartnerId) {
    if (_acceptingOrderIds.contains(orderId)) return true;
    for (final item in _items) {
      final matches = item.broadcast.orderId == orderId ||
          item.broadcast.broadcastId == orderId ||
          item.broadcast.uniqueId == orderId;
      if (matches && item.isAccepting) return true;
    }
    final mine = AuthSession.partnerId?.trim();
    final claimed = claimedByPartnerId?.trim();
    return mine != null &&
        mine.isNotEmpty &&
        claimed != null &&
        claimed.isNotEmpty &&
        mine == claimed;
  }

  /// Dismisses a specific order (e.g. claimed by another partner or socket dismiss).
  void dismissOrder(
    String orderId, {
    String? reason,
    String? claimedByPartnerId,
  }) {
    final ownClaim = _isOwnClaim(orderId, claimedByPartnerId);
    OrderBroadcastItem? targetItem;
    for (final item in _items) {
      if (item.broadcast.orderId == orderId ||
          item.broadcast.broadcastId == orderId ||
          item.broadcast.uniqueId == orderId) {
        targetItem = item;
        break;
      }
    }

    if (targetItem == null) return;

    _removeItem(targetItem);

    if (ownClaim) {
      if (_items.isEmpty) dismissAll();
      return;
    }

    final context = SessionGuard.navigatorKey.currentContext;
    if (context != null && reason != null && reason.isNotEmpty) {
      CustomSnackBar.showWarning(context, reason);
    }

    if (_items.isEmpty) {
      dismissAll();
    }
  }

  /// Handles action button decline for a specific card.
  void handleDecline(BuildContext context, String orderId) {
    handleNativeDecline(orderId);
  }

  /// Decline from the Android overlay / notification (no UI context required).
  void handleNativeDecline(String orderId) {
    OrderBroadcastItem? targetItem;
    for (final item in _items) {
      if (item.broadcast.orderId == orderId ||
          item.broadcast.broadcastId == orderId) {
        targetItem = item;
        break;
      }
    }

    if (targetItem != null) {
      _removeItem(targetItem);
    }

    // Decline always cuts the alert as soon as this card is gone.
    if (_items.isEmpty || !_items.any((item) => !item.isAccepting)) {
      unawaited(BroadcastSoundPlayer.stop());
    }

    if (_items.isEmpty) {
      dismissAll();
    }
  }

  /// Handles accept action for a specific broadcast card.
  Future<void> handleAccept(BuildContext context, String orderId) async {
    OrderBroadcastItem? targetItem;
    for (final item in _items) {
      if (item.broadcast.orderId == orderId ||
          item.broadcast.broadcastId == orderId) {
        targetItem = item;
        break;
      }
    }

    if (targetItem == null || targetItem.isAccepting) return;

    targetItem.isAccepting = true;
    _acceptingOrderIds.add(orderId);
    _acceptingOrderIds.add(targetItem.broadcast.orderId);
    _acceptingOrderIds.add(targetItem.broadcast.broadcastId);
    itemsNotifier.value = List.unmodifiable(_items);
    // Accept stops the alert immediately, even while the API is still running.
    unawaited(BroadcastSoundPlayer.stop());

    final orderNumber = targetItem.broadcast.orderNumber.isNotEmpty
        ? targetItem.broadcast.orderNumber
        : targetItem.broadcast.orderId;

    try {
      await _ordersRepository.acceptBroadcastOrder(orderId);
      unawaited(BroadcastNotificationService.stayInApp());

      if (_items.contains(targetItem)) {
        _removeItem(targetItem);
      }

      if (_items.isEmpty) {
        _closeDialogOnly();
      }

      final currentCtx = SessionGuard.navigatorKey.currentContext;
      if (currentCtx != null) {
      CustomSnackBar.showSuccess(
          currentCtx,
          '🎉 Order #$orderNumber Accepted Successfully!',
      );
      }

      // Navigate to active delivery order details screen
      SessionGuard.navigatorKey.currentState?.pushNamed(
        AppRoutes.orderDetailsScreen,
        arguments: {
          'orderId': orderId,
          'orderNumber': orderNumber,
          'enableWorkflow': true,
          'isInTransit': true,
        },
      );
    } catch (error) {
      if (_items.contains(targetItem)) {
        _removeItem(targetItem);
      }

      if (_items.isEmpty) {
        _closeDialogOnly();
      }

      String msg = 'This order was already accepted by another partner.';
      if (error is ApiException && error.message.isNotEmpty) {
        msg = error.message;
      }

      final currentCtx = SessionGuard.navigatorKey.currentContext;
      if (currentCtx != null) {
        CustomSnackBar.showError(currentCtx, msg);
      }
    } finally {
      _acceptingOrderIds.remove(orderId);
      _acceptingOrderIds.remove(targetItem.broadcast.orderId);
      _acceptingOrderIds.remove(targetItem.broadcast.broadcastId);
    }
  }

  void _showCenterDialog() {
    final context = SessionGuard.navigatorKey.currentContext;
    if (context == null || _items.isEmpty) return;

    _removeNotchOverlay();
    _isDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: true, // Tapping outside minimizes to top notch
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => const _OrderBroadcastCarouselDialog(),
    ).then((_) {
      _isDialogOpen = false;
      // If closed by tapping outside while broadcasts remain, minimize to top notch
      if (_items.isNotEmpty) {
        _showNotchOverlay();
      }
    });
  }

  void _showNotchOverlay() {
    _removeNotchOverlay();
    final overlayState = SessionGuard.navigatorKey.currentState?.overlay;
    if (overlayState == null || _items.isEmpty) return;

    _notchOverlay = OverlayEntry(
      builder: (context) => _TopNotchMultiContainer(
        onTap: () {
          _removeNotchOverlay();
          _showCenterDialog();
        },
      ),
    );

    overlayState.insert(_notchOverlay!);
  }

  void _removeNotchOverlay() {
    _notchOverlay?.remove();
    _notchOverlay = null;
  }

  void _closeDialogOnly() {
    if (_isDialogOpen) {
      _isDialogOpen = false;
      if (SessionGuard.navigatorKey.currentState?.canPop() == true) {
        SessionGuard.navigatorKey.currentState?.pop();
      }
    }
    _removeNotchOverlay();
  }

  /// Dismisses all broadcasts and closes modals/overlays cleanly.
  void dismissAll({bool showTimeoutMessage = false, String? reason}) {
    _hapticTimer?.cancel();
    _hapticTimer = null;
    unawaited(BroadcastSoundPlayer.stop());

    for (final item in _items) {
      BroadcastNotificationService.cancel(item.broadcast.orderId);
      item.dispose();
    }
    _items.clear();
    itemsNotifier.value = const [];
    _currentPageIndex = 0;

    _removeNotchOverlay();

    if (_isDialogOpen) {
      _isDialogOpen = false;
      if (SessionGuard.navigatorKey.currentState?.canPop() == true) {
      SessionGuard.navigatorKey.currentState?.pop();
      }
    }

    final context = SessionGuard.navigatorKey.currentContext;
    if (context != null) {
      if (showTimeoutMessage) {
        CustomSnackBar.showInfo(context, 'Order request timed out.');
      } else if (reason != null && reason.isNotEmpty) {
        CustomSnackBar.showWarning(context, reason);
      }
    }
  }
}

/// Compatibility wrapper for SocketService and FCM invocations.
class OrderBroadcastBottomSheet {
  OrderBroadcastBottomSheet._();

  static String? get currentActiveOrderId =>
      OrderBroadcastManager.instance.currentActiveOrderId;

  static List<String> get activeOrderIds =>
      OrderBroadcastManager.instance.activeOrderIds;

  static void dismissActive(
    String orderId, {
    String? reason,
    String? claimedByPartnerId,
  }) {
    OrderBroadcastManager.instance.dismissOrder(
      orderId,
      reason: reason,
      claimedByPartnerId: claimedByPartnerId,
    );
  }

  static void dismissAll({String? reason}) {
      OrderBroadcastManager.instance.dismissAll(reason: reason);
  }

  static Future<void> show(
      BuildContext context, OrderBroadcastModel broadcast) async {
    OrderBroadcastManager.instance.startBroadcast(broadcast);
  }
}

/// Standalone helper function for accepting a broadcast order directly
Future<void> acceptBroadcastOrder({
  required BuildContext context,
  required String orderId,
  required String token,
  required VoidCallback onOrderClaimed,
}) async {
  final navigator = Navigator.of(context);

  try {
    final response = await http.post(
      ApiConfig.acceptBroadcastOrderUri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'order_id': orderId.trim()}),
    );
    final result = jsonDecode(response.body);
    if (response.statusCode == 200 && result['success'] == true) {
      if (navigator.canPop()) {
        navigator.pop();
      }
      onOrderClaimed();
    } else {
      if (navigator.canPop()) {
        navigator.pop();
      }
      CustomSnackBar.showError(
        SessionGuard.navigatorKey.currentContext,
        result['message'] ?? 'Failed to accept order',
      );
    }
  } catch (err) {
    CustomSnackBar.showError(
      SessionGuard.navigatorKey.currentContext,
      'Network error: $err',
    );
  }
}

/// Minimized Top Notch (Dynamic Island style) overlay supporting multiple broadcasts.
class _TopNotchMultiContainer extends StatelessWidget {
  final VoidCallback onTap;

  const _TopNotchMultiContainer({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 6.h,
      left: 14.w,
      right: 14.w,
      child: Material(
        color: Colors.transparent,
        child: ValueListenableBuilder<List<OrderBroadcastItem>>(
          valueListenable: OrderBroadcastManager.instance.itemsNotifier,
          builder: (context, items, _) {
            if (items.isEmpty) return const SizedBox.shrink();

            final count = items.length;
            final primaryItem = items.first;

            // Find minimum remaining seconds across all active items
            int minSeconds = primaryItem.remainingSecondsNotifier.value;
            for (final item in items) {
              if (item.remainingSecondsNotifier.value < minSeconds) {
                minSeconds = item.remainingSecondsNotifier.value;
              }
            }

            final isMultiple = count > 1;

            return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          tween: Tween(begin: -30.0, end: 0.0),
          builder: (context, translateY, child) {
            return Transform.translate(
              offset: Offset(0, translateY),
              child: child,
            );
          },
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF14141B),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: AppColours.primary.withValues(alpha: 0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: AppColours.primary.withValues(alpha: 0.25),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                      // Moped Icon or Multi Badge with Glow
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: AppColours.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                        child: Icon(
                          isMultiple ? Icons.layers_outlined : Icons.electric_moped,
                      color: AppColours.primary,
                      size: 17,
                    ),
                  ),
                  SizedBox(width: 10.w),

                      // Order Details / Count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                              isMultiple
                                  ? '$count Incoming Orders Available'
                                  : (primaryItem.broadcast.orderNumber.isNotEmpty
                                      ? '#${primaryItem.broadcast.orderNumber}'
                                      : 'New Order Request'),
                          style: CustomTextStyles.openSansBold.copyWith(
                            fontSize: 12.fSize,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1.h),
                        Text(
                              isMultiple
                                  ? 'Tap to swipe & review all'
                                  : 'Tap to view • ${primaryItem.broadcast.formattedEarning}',
                          style: CustomTextStyles.openSansRegular.copyWith(
                            fontSize: 11.fSize,
                            color: AppColours.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 8.w),

                      // Live Countdown Timer Badge (earliest expiry)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: (minSeconds <= 5
                                  ? Colors.redAccent
                                  : AppColours.primary)
                              .withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: minSeconds <= 5
                                ? Colors.redAccent
                                : AppColours.primary,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 13.fSize,
                              color: minSeconds <= 5
                                  ? Colors.redAccent
                                  : AppColours.primary,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              '${minSeconds}s',
                              style: CustomTextStyles.montserratBold.copyWith(
                                fontSize: 12.fSize,
                                color: minSeconds <= 5
                                    ? Colors.redAccent
                                    : AppColours.primary,
                              ),
                            ),
                          ],
                        ),
                  ),
                ],
              ),
            ),
          ),
            );
          },
        ),
      ),
    );
  }
}

/// The Multi-Broadcast Swipeable Carousel Dialog featuring:
/// - Horizontal swipeable PageView with page-snapping
/// - Top Counter Badge (`Incoming Orders: 2 of 4`)
/// - Dynamic animated Pagination Indicator Dots
/// - Per-card timer, distance, kit details, pickup/delivery timeline, and actions
class OrderBroadcastCarouselDialog extends StatefulWidget {
  const OrderBroadcastCarouselDialog({super.key});

  @override
  State<OrderBroadcastCarouselDialog> createState() =>
      _OrderBroadcastCarouselDialogState();
}

typedef _OrderBroadcastCarouselDialog = OrderBroadcastCarouselDialog;

class _OrderBroadcastCarouselDialogState
    extends State<_OrderBroadcastCarouselDialog> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = OrderBroadcastManager.instance.currentPageIndex;
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    OrderBroadcastManager.instance.currentPageIndex = index;
  }

  void _jumpToPage(int index) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 20.h),
      child: ValueListenableBuilder<List<OrderBroadcastItem>>(
        valueListenable: OrderBroadcastManager.instance.itemsNotifier,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return const SizedBox.shrink();
          }

          // Ensure active page is within bounds when an order is removed
          if (_currentPage >= items.length) {
            _currentPage = math.max(0, items.length - 1);
            OrderBroadcastManager.instance.currentPageIndex = _currentPage;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                _pageController.jumpToPage(_currentPage);
              }
            });
          }

          final currentItem = items[_currentPage];
          final totalOrders = items.length;
          final isMultiple = totalOrders > 1;

          return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14141B),
              borderRadius: BorderRadius.circular(22),
          border: Border.all(
                color: AppColours.primary.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
                  color: Colors.black.withValues(alpha: 0.95),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
            ),
            BoxShadow(
                  color: AppColours.primary.withValues(alpha: 0.18),
                  blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  // Top Carousel Header: Counter Badge & Minimize Hint
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      // Counter badge / Request type
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColours.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColours.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                              Icon(
                                isMultiple
                                    ? Icons.layers_outlined
                                    : Icons.electric_moped,
                            color: AppColours.primary,
                                size: 14,
                              ),
                              SizedBox(width: 5.w),
                              Flexible(
                                child: Text(
                                  isMultiple
                                      ? 'Incoming Orders: ${_currentPage + 1} of $totalOrders'
                                      : (currentItem.broadcast.flowType
                                                  .toLowerCase()
                                                  .trim() !=
                                              'delivery'
                                          ? 'NEW RETURN REQUEST'
                                          : 'NEW ORDER REQUEST'),
                                  style: CustomTextStyles.openSansBold.copyWith(
                                    fontSize: 11.fSize,
                                    color: AppColours.primary,
                                    letterSpacing: 0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),

                      // Swipe hint / Minimize indicator
                      if (isMultiple)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Swipe',
                              style: CustomTextStyles.openSansRegular.copyWith(
                                fontSize: 11.fSize,
                                color: Colors.white54,
                              ),
                            ),
                            SizedBox(width: 2.w),
                            Icon(
                              Icons.swipe_outlined,
                              size: 14.fSize,
                              color: Colors.white54,
                            ),
                          ],
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Minimize',
                            style: CustomTextStyles.openSansRegular.copyWith(
                              fontSize: 10.fSize,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                    ],
                  ),

                  SizedBox(height: 10.h),

                  // Horizontal Scrollable Carousel (Pager)
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: math.min(
                            MediaQuery.of(context).size.height * 0.72, 380.h),
                      ),
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: totalOrders,
                        onPageChanged: _onPageChanged,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _StandaloneBroadcastCard(
                            key: ValueKey(item.broadcast.uniqueId),
                            item: item,
                            onAccept: () => OrderBroadcastManager.instance
                                .handleAccept(context, item.broadcast.orderId),
                            onDecline: () => OrderBroadcastManager.instance
                                .handleDecline(context, item.broadcast.orderId),
                          );
                        },
                      ),
                    ),
                  ),

                  // Pagination Indicator Dots
                  if (isMultiple) ...[
                    SizedBox(height: 12.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(totalOrders, (index) {
                        final isSelected = index == _currentPage;
                        return GestureDetector(
                          onTap: () => _jumpToPage(index),
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            margin: EdgeInsets.symmetric(horizontal: 3.5.w),
                            width: isSelected ? 22.w : 6.5.w,
                            height: 6.5.h,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColours.primary
                                  : Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColours.primary
                                            .withValues(alpha: 0.55),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A standalone broadcast card within the carousel
class _StandaloneBroadcastCard extends StatelessWidget {
  final OrderBroadcastItem item;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _StandaloneBroadcastCard({
    super.key,
    required this.item,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final broadcast = item.broadcast;
    final isDelivery = broadcast.flowType.toLowerCase().trim() == 'delivery';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Per-Card Header Row: Flow badge + Circular Countdown Timer
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: (isDelivery
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF38BDF8))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDelivery
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFF38BDF8))
                        .withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDelivery ? Icons.directions_bike : Icons.replay,
                      color: isDelivery
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFF38BDF8),
                      size: 13,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                      isDelivery ? 'DELIVERY' : 'RETURN',
                            style: CustomTextStyles.openSansBold.copyWith(
                              fontSize: 10.fSize,
                        color: isDelivery
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFF38BDF8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

              // Circular Countdown Timer for this specific card
                    ValueListenableBuilder<int>(
                valueListenable: item.remainingSecondsNotifier,
                      builder: (context, seconds, _) {
                  final progress = item.totalSeconds > 0
                      ? (seconds / item.totalSeconds)
                            : 0.0;
                        final isLow = seconds <= 5;

                  return Padding(
                    padding: const EdgeInsets.only(right: 5,top: 5),
                    child: Container(
                      width: 42.w,
                      height: 42.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E1E28),
                            boxShadow: [
                              BoxShadow(
                                color: (isLow ? Colors.redAccent : AppColours.primary)
                                    .withValues(alpha: 0.25),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: CircularProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  strokeWidth: 3.0,
                                  backgroundColor: Colors.white12,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isLow ? Colors.redAccent : AppColours.primary,
                                  ),
                                ),
                              ),
                              Padding(
                            padding: EdgeInsets.all(5.w),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$seconds',
                                    textAlign: TextAlign.center,
                                    style: CustomTextStyles.montserratBold.copyWith(
                                  fontSize: 13.fSize,
                                      fontWeight: FontWeight.w800,
                                  color: isLow
                                      ? Colors.redAccent
                                      : AppColours.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                      ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

          SizedBox(height: 10.h),

          // Order Number & Earning Container
                Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E28),
              borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColours.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ORDER NUMBER',
                            style: CustomTextStyles.openSansRegular.copyWith(
                        fontSize: 9.5.fSize,
                              color: AppColours.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                      broadcast.orderNumber.isNotEmpty
                          ? '#${broadcast.orderNumber}'
                          : '#${broadcast.orderId}',
                            style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 14.fSize,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'YOU EARN',
                            style: CustomTextStyles.openSansRegular.copyWith(
                        fontSize: 9.5.fSize,
                              color: AppColours.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                      broadcast.formattedEarning,
                            style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 19.fSize,
                              color: AppColours.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

          // Details Row: Distance, Items count, and Kit Details Badges
          if (broadcast.formattedDistance != null ||
              broadcast.itemsCountLabel != null ||
              broadcast.kitDetailsLabel != null) ...[
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 4.h,
              children: [
                if (broadcast.formattedDistance != null)
                  _DetailBadge(
                    icon: Icons.near_me_outlined,
                    label: broadcast.formattedDistance!,
                    color: const Color(0xFF60A5FA),
                  ),
                if (broadcast.itemsCountLabel != null)
                  _DetailBadge(
                    icon: Icons.shopping_bag_outlined,
                    label: broadcast.itemsCountLabel!,
                    color: const Color(0xFFA78BFA),
                  ),
                if (broadcast.kitDetailsLabel != null)
                  _DetailBadge(
                    icon: Icons.inventory_2_outlined,
                    label: broadcast.kitDetailsLabel!,
                    color: const Color(0xFFFBBF24),
                  ),
              ],
            ),
          ],

          SizedBox(height: 10.h),

          // Pickup & Delivery Route Section
                Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B24),
              borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      // Pickup Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 2.h),
                      width: 9.w,
                      height: 9.w,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                    SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                            !isDelivery
                                ? 'PICKUP (CUSTOMER)'
                                : 'PICKUP (IAP HUB)',
                                  style: CustomTextStyles.openSansBold.copyWith(
                              fontSize: 9.5.fSize,
                                    color: const Color(0xFF4ADE80),
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                            broadcast.pickupAddress,
                                  style: CustomTextStyles.openSansMedium.copyWith(
                              fontSize: 11.5.fSize,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Connecting route line
                      Padding(
                  padding: EdgeInsets.only(left: 3.5.w, top: 2.h, bottom: 2.h),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 2,
                      height: 14.h,
                            color: Colors.white24,
                          ),
                        ),
                      ),

                      // Delivery Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 2.h),
                      width: 9.w,
                      height: 9.w,
                            decoration: const BoxDecoration(
                              color: AppColours.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                    SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                            !isDelivery
                                ? 'DROP-OFF (IAP HUB)'
                                : 'DELIVERY (CUSTOMER)',
                                  style: CustomTextStyles.openSansBold.copyWith(
                              fontSize: 9.5.fSize,
                                    color: AppColours.primary,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                            broadcast.deliveryAddress,
                                  style: CustomTextStyles.openSansMedium.copyWith(
                              fontSize: 11.5.fSize,
                                    color: Colors.white,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

          SizedBox(height: 12.h),

          // Individual Action Buttons for this card: Decline & Accept
                Row(
                  children: [
              // Decline Button
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 44.h,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.transparent,
                          ),
                    onPressed: item.isAccepting ? null : onDecline,
                          child: Text(
                            'Decline',
                            style: CustomTextStyles.openSansSemiBold.copyWith(
                        fontSize: 13.5.fSize,
                              color: AppColours.grey,
                            ),
                          ),
                        ),
                      ),
                    ),

              SizedBox(width: 10.w),

              // Animated Accept Order Button
                    Expanded(
                flex: 3,
                      child: _AnimatedAcceptOrderButton(
                  isAccepting: item.isAccepting,
                  onPressed: item.isAccepting ? null : onAccept,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Small visual chip badge for distance, items count, and kit details.
class _DetailBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.fSize, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: CustomTextStyles.openSansSemiBold.copyWith(
              fontSize: 10.5.fSize,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated Accept Order Button featuring:
/// - Breathing pulse scale animation
/// - Pulsing glowing gold shadow
/// - Moving light-beam shimmer sweep
/// - Haptic feedback on tap
/// - Height: precisely 44.h
class _AnimatedAcceptOrderButton extends StatefulWidget {
  final bool isAccepting;
  final VoidCallback? onPressed;

  const _AnimatedAcceptOrderButton({
    required this.isAccepting,
    required this.onPressed,
  });

  @override
  State<_AnimatedAcceptOrderButton> createState() =>
      _AnimatedAcceptOrderButtonState();
}

class _AnimatedAcceptOrderButtonState extends State<_AnimatedAcceptOrderButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAccepting) {
      return SizedBox(
        height: 44.h,
        child: Container(
          decoration: BoxDecoration(
            color: AppColours.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: SizedBox(
              height: 20.h,
              width: 20.h,
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            height: 44.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFDF88),
                  Color(0xFFE6C27A),
                  Color(0xFFD4A853),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      AppColours.primary.withValues(alpha: _glowAnimation.value),
                  blurRadius: 10 + 6 * _scaleAnimation.value,
                  spreadRadius: 1 + 2 * _scaleAnimation.value,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onPressed?.call();
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      // Shimmer light beam sweeping across button
                      Positioned.fill(
                        child: Transform.translate(
                          offset: Offset(
                            _shimmerAnimation.value * 120.w,
                            0,
                          ),
                          child: Transform.rotate(
                            angle: 0.3,
                            child: Container(
                              width: 35.w,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.35),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Button Content
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.black,
                              size: 19,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Accept Order',
                              style: CustomTextStyles.openSansBold.copyWith(
                                fontSize: 13.5.fSize,
                                color: Colors.black,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
