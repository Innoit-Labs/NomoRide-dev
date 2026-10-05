import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/services/socket_service.dart';
import 'package:nomoride/core/utils/custom_snack_bar.dart';
import 'package:nomoride/core/utils/size_utils.dart';
import 'package:nomoride/features/home/data/orders_repository.dart';
import 'package:nomoride/features/orders/data/models/order_broadcast_model.dart';
import 'package:nomoride/routes/app_routes.dart';
import 'package:nomoride/theme/theme_helper.dart';

/// Controller that manages the active broadcast dialog and top notch widget.
class OrderBroadcastManager {
  OrderBroadcastManager._();
  static final OrderBroadcastManager instance = OrderBroadcastManager._();

  final OrdersRepository _ordersRepository = OrdersRepository();

  OrderBroadcastModel? _broadcast;
  int _remainingSeconds = 30;
  int _totalSeconds = 30;
  Timer? _countdownTimer;
  Timer? _hapticTimer;
  OverlayEntry? _notchOverlay;
  bool _isDialogOpen = false;
  bool _isAccepting = false;
  bool _isDeclined = false;

  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier<int>(30);

  String? get currentActiveOrderId => _broadcast?.orderId;

  /// Starts the broadcast flow: displays centered dialog and manages countdown.
  void startBroadcast(OrderBroadcastModel broadcast) {
    if (_broadcast?.orderId == broadcast.orderId) {
      return; // Already active for this order
    }

    // Dismiss any previous broadcast
    dismissAll();

    _broadcast = broadcast;
    final rawSec = broadcast.timerSeconds;
    _totalSeconds = (rawSec > 0 && rawSec <= 60) ? rawSec : 30;
    _remainingSeconds = _totalSeconds;
    remainingSecondsNotifier.value = _remainingSeconds;
    _isDeclined = false;
    _isAccepting = false;

    _startTimers();
    _showCenterDialog();
  }

  void _startTimers() {
    _countdownTimer?.cancel();
    _hapticTimer?.cancel();

    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    // Subtle vibration alert every 4 seconds
    _hapticTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isAccepting && _broadcast != null) {
        HapticFeedback.mediumImpact();
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _handleTimeExpired();
      } else {
        _remainingSeconds--;
        remainingSecondsNotifier.value = _remainingSeconds;
      }
    });
  }

  void _handleTimeExpired() {
    dismissAll(showTimeoutMessage: true);
  }

  void _showCenterDialog() {
    final context = SessionGuard.navigatorKey.currentContext;
    if (context == null || _broadcast == null) return;

    _removeNotchOverlay();
    _isDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: true, // Tapping outside minimizes to top notch!
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => _OrderBroadcastDialogCard(
        broadcast: _broadcast!,
        remainingSecondsNotifier: remainingSecondsNotifier,
        totalSeconds: _totalSeconds,
        onAccept: () => _handleAccept(ctx),
        onDecline: () => _handleDecline(ctx),
      ),
    ).then((_) {
      _isDialogOpen = false;
      // If closed by clicking outside (not accepted or declined), minimize to top notch
      if (!_isAccepting && !_isDeclined && _broadcast != null && _remainingSeconds > 0) {
        _showNotchOverlay();
      }
    });
  }

  void _showNotchOverlay() {
    _removeNotchOverlay();
    final overlayState = SessionGuard.navigatorKey.currentState?.overlay;
    if (overlayState == null || _broadcast == null) return;

    _notchOverlay = OverlayEntry(
      builder: (context) => _TopNotchContainer(
        broadcast: _broadcast!,
        remainingSecondsNotifier: remainingSecondsNotifier,
        totalSeconds: _totalSeconds,
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

  Future<void> _handleDecline(BuildContext context) async {
    _isDeclined = true;
    final orderId = _broadcast?.orderId;
    if (orderId != null && orderId.isNotEmpty) {
      // Temporarily ignore this order so the driver is not re-prompted during this session
      SocketService.instance.ignoreOrder(orderId);
    }

    _countdownTimer?.cancel();
    _hapticTimer?.cancel();
    _removeNotchOverlay();

    if (_isDialogOpen) {
      _isDialogOpen = false;
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    _broadcast = null;
  }

  Future<void> _handleAccept(BuildContext context) async {
    if (_isAccepting || _broadcast == null) return;
    _isAccepting = true;

    _countdownTimer?.cancel();
    _hapticTimer?.cancel();
    _removeNotchOverlay();

    final orderId = _broadcast!.orderId;
    final orderNumber = _broadcast!.orderNumber;

    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      await _ordersRepository.acceptBroadcastOrder(orderId);

      _isDialogOpen = false;
      if (navigator.canPop()) {
        navigator.pop();
      }
      _broadcast = null;

      CustomSnackBar.showSuccess(
        SessionGuard.navigatorKey.currentContext,
        '🎉 Order Accepted Successfully!',
      );

      // Navigate to active delivery order details / workflow screen
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
      _isDialogOpen = false;
      if (navigator.canPop()) {
        navigator.pop();
      }
      _broadcast = null;

      String msg = 'This order was already accepted by another partner.';
      if (error is ApiException && error.message.isNotEmpty) {
        msg = error.message;
      }

      CustomSnackBar.showError(
        SessionGuard.navigatorKey.currentContext,
        msg,
      );
    } finally {
      _isAccepting = false;
    }
  }

  /// Dismisses all modals and notch overlays cleanly.
  void dismissAll({bool showTimeoutMessage = false, String? reason}) {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _hapticTimer?.cancel();
    _hapticTimer = null;

    _removeNotchOverlay();

    if (_isDialogOpen) {
      _isDialogOpen = false;
      SessionGuard.navigatorKey.currentState?.pop();
    }

    _broadcast = null;
    _isAccepting = false;
    _isDeclined = false;

    final context = SessionGuard.navigatorKey.currentContext;
    if (context != null) {
      if (showTimeoutMessage) {
        CustomSnackBar.showInfo(
          context,
          'Order request timed out.',
        );
      } else if (reason != null && reason.isNotEmpty) {
        CustomSnackBar.showWarning(
          context,
          reason,
        );
      }
    }
  }
}

/// Compatibility wrapper for SocketService invocations.
class OrderBroadcastBottomSheet {
  OrderBroadcastBottomSheet._();

  static String? get currentActiveOrderId =>
      OrderBroadcastManager.instance.currentActiveOrderId;

  static void dismissActive(String orderId, {String? reason}) {
    if (currentActiveOrderId == orderId) {
      OrderBroadcastManager.instance.dismissAll(reason: reason);
    }
  }

  static Future<void> show(BuildContext context, OrderBroadcastModel broadcast) async {
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

/// Floating Top Notch (Dynamic Island style) container showing live countdown timer.
class _TopNotchContainer extends StatelessWidget {
  final OrderBroadcastModel broadcast;
  final ValueNotifier<int> remainingSecondsNotifier;
  final int totalSeconds;
  final VoidCallback onTap;

  const _TopNotchContainer({
    required this.broadcast,
    required this.remainingSecondsNotifier,
    required this.totalSeconds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 6.h,
      left: 14.w,
      right: 14.w,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
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
                  // Moped Icon with Gold Glow
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: AppColours.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.electric_moped,
                      color: AppColours.primary,
                      size: 17,
                    ),
                  ),
                  SizedBox(width: 10.w),

                  // Order Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          broadcast.orderNumber.isNotEmpty
                              ? '#${broadcast.orderNumber}'
                              : 'New Order Request',
                          style: CustomTextStyles.openSansBold.copyWith(
                            fontSize: 12.fSize,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1.h),
                        Text(
                          'Tap to view • ${broadcast.formattedEarning}',
                          style: CustomTextStyles.openSansRegular.copyWith(
                            fontSize: 11.fSize,
                            color: AppColours.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(width: 8.w),

                  // Live Countdown Timer Badge
                  ValueListenableBuilder<int>(
                    valueListenable: remainingSecondsNotifier,
                    builder: (context, seconds, _) {
                      final isLow = seconds <= 5;
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: (isLow ? Colors.redAccent : AppColours.primary).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isLow ? Colors.redAccent : AppColours.primary,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 13.fSize,
                              color: isLow ? Colors.redAccent : AppColours.primary,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              '${seconds}s',
                              style: CustomTextStyles.montserratBold.copyWith(
                                fontSize: 12.fSize,
                                color: isLow ? Colors.redAccent : AppColours.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered Dialog Card in the middle of the screen.
class _OrderBroadcastDialogCard extends StatefulWidget {
  final OrderBroadcastModel broadcast;
  final ValueNotifier<int> remainingSecondsNotifier;
  final int totalSeconds;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _OrderBroadcastDialogCard({
    required this.broadcast,
    required this.remainingSecondsNotifier,
    required this.totalSeconds,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_OrderBroadcastDialogCard> createState() => _OrderBroadcastDialogCardState();
}

class _OrderBroadcastDialogCardState extends State<_OrderBroadcastDialogCard> {
  bool _isAccepting = false;

  void _triggerAccept() {
    if (_isAccepting) return;
    setState(() => _isAccepting = true);
    widget.onAccept();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF14141B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColours.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.9),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColours.primary.withValues(alpha: 0.15),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header: Badge, Order number, and circular countdown timer
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
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
                          const Icon(
                            Icons.electric_moped,
                            color: AppColours.primary,
                            size: 15,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'NEW ORDER REQUEST',
                            style: CustomTextStyles.openSansBold.copyWith(
                              fontSize: 10.fSize,
                              color: AppColours.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Circular Countdown Timer
                    ValueListenableBuilder<int>(
                      valueListenable: widget.remainingSecondsNotifier,
                      builder: (context, seconds, _) {
                        final progress = widget.totalSeconds > 0
                            ? (seconds / widget.totalSeconds)
                            : 0.0;
                        final isLow = seconds <= 5;
                        return Container(
                          width: 46.w,
                          height: 46.w,
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
                                padding: EdgeInsets.all(6.w),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$seconds',
                                    textAlign: TextAlign.center,
                                    style: CustomTextStyles.montserratBold.copyWith(
                                      fontSize: 14.fSize,
                                      fontWeight: FontWeight.w800,
                                      color: isLow ? Colors.redAccent : AppColours.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),

                SizedBox(height: 12.h),

                // Order Number & Earning Card
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E28),
                    borderRadius: BorderRadius.circular(16),
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
                              fontSize: 10.fSize,
                              color: AppColours.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            widget.broadcast.orderNumber.isNotEmpty
                                ? '#${widget.broadcast.orderNumber}'
                                : '#${widget.broadcast.orderId}',
                            style: CustomTextStyles.montserratBold.copyWith(
                              fontSize: 15.fSize,
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
                              fontSize: 10.fSize,
                              color: AppColours.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            widget.broadcast.formattedEarning,
                            style: CustomTextStyles.montserratBold.copyWith(
                              fontSize: 20.fSize,
                              color: AppColours.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 14.h),

                // Pickup & Delivery Route section
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B24),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      // Pickup Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 2.h),
                            width: 10.w,
                            height: 10.w,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PICKUP',
                                  style: CustomTextStyles.openSansBold.copyWith(
                                    fontSize: 10.fSize,
                                    color: const Color(0xFF4ADE80),
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  widget.broadcast.pickupAddress,
                                  style: CustomTextStyles.openSansMedium.copyWith(
                                    fontSize: 12.fSize,
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
                        padding: EdgeInsets.only(left: 4.w, top: 2.h, bottom: 2.h),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 2,
                            height: 16.h,
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
                            width: 10.w,
                            height: 10.w,
                            decoration: const BoxDecoration(
                              color: AppColours.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DELIVERY',
                                  style: CustomTextStyles.openSansBold.copyWith(
                                    fontSize: 10.fSize,
                                    color: AppColours.primary,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  widget.broadcast.deliveryAddress,
                                  style: CustomTextStyles.openSansMedium.copyWith(
                                    fontSize: 12.fSize,
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

                SizedBox(height: 16.h),

                // Action Buttons: Decline & Accept Order (Both exactly height 44)
                Row(
                  children: [
                    // Decline Button (Height: 44)
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
                          onPressed: _isAccepting ? null : widget.onDecline,
                          child: Text(
                            'Decline',
                            style: CustomTextStyles.openSansSemiBold.copyWith(
                              fontSize: 14.fSize,
                              color: AppColours.grey,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 12.w),

                    // Animated Accept Order Button (Height: 44)
                    Expanded(
                      flex: 4,
                      child: _AnimatedAcceptOrderButton(
                        isAccepting: _isAccepting,
                        onPressed: _isAccepting ? null : _triggerAccept,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
                  color: AppColours.primary.withValues(alpha: _glowAnimation.value),
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
                                fontSize: 14.fSize,
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
