import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/auth_session.dart';
import '../../../../core/services/broadcast_notification_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/utils/icon_constant.dart';
import '../../../../theme/theme_helper.dart';
import '../../../../routes/app_routes.dart';
import '../../../../core/utils/size_utils.dart';
import '../../../../core/utils/image_constant.dart';
import '../../../../core/utils/custom_snack_bar.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../notifications/data/notifications_repository.dart';
import '../../../profile/data/models/delivery_partner_profile.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/dashboard_repository.dart';
import '../../data/models/dashboard_data.dart';
import '../../data/models/dp_order.dart';
import '../../data/orders_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static final ValueNotifier<bool> isHomeLoadingNotifier =
      ValueNotifier<bool>(true);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final OrdersRepository _ordersRepository = OrdersRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final NotificationsRepository _notificationsRepository = NotificationsRepository();

  final Set<String> _updatingOrderNumbers = {};
  bool _isLoadingDashboard = true;
  bool _isLoadingOrders = true;
  bool _isLoadingProfile = true;
  String? _dashboardError;
  String? _ordersError;
  String? _partnerDisplayName;
  String? _partnerPhotoUrl;
  bool _isOnline = ProfileRepository.currentOnlineStatus;
  bool _isUpdatingOnline = false;
  DashboardData? _dashboardData;
  List<DpOrder> _orders = [];

  Timer? _pollingTimer;
  StreamSubscription<void>? _orderUpdateSubscription;
  bool _isSilentRefreshing = false;
  DateTime? _lastSilentFetchTime;

  bool get _isLoading =>
      _isLoadingDashboard || _isLoadingOrders || _isLoadingProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isOnline = ProfileRepository.currentOnlineStatus;
    _orderUpdateSubscription =
        SocketService.instance.onOrderUpdate.listen((_) {
      _refreshOrdersSilently();
    });
    _initOnlineStatusAndLoadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BroadcastNotificationService.markHomeReady();
      if (mounted) BroadcastNotificationService.promptOverlayPermission(context);
    });
  }

  Future<void> _initOnlineStatusAndLoadData() async {
    final persisted = await ProfileRepository.restoreOnlineStatus();
    if (mounted && _isOnline != persisted) {
      setState(() => _isOnline = persisted);
    }
    await _loadHomeData();
    if (mounted && _isOnline) {
      _startPollingTimer();
      BroadcastNotificationService.setOnline(true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect socket if it dropped while backgrounded
      SocketService.instance.initAndConnect();
      // Silently fetch latest orders immediately on app resume
      _refreshOrdersSilently();
      if (_isOnline) {
        _startPollingTimer();
        BroadcastNotificationService.setOnline(true);
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopPollingTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orderUpdateSubscription?.cancel();
    _stopPollingTimer();
    HomeScreen.isHomeLoadingNotifier.value = false;
    super.dispose();
  }

  void _startPollingTimer() {
    _pollingTimer?.cancel();
    if (!_isOnline) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && _isOnline) {
        _refreshOrdersSilently();
      }
    });
  }

  void _stopPollingTimer() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _loadHomeData({bool forceRefreshProfile = false}) async {
    HomeScreen.isHomeLoadingNotifier.value = true;
    setState(() {
      _isLoadingDashboard = true;
      _isLoadingOrders = true;
      _isLoadingProfile = true;
      _dashboardError = null;
      _ordersError = null;
    });

    _notificationsRepository.checkUnreadStatus();

    final dashboardFuture = _loadDashboardSafe();
    final ordersFuture = _loadOrdersSafe();
    final profileFuture = _loadProfileSafe(forceRefresh: forceRefreshProfile);
    final dashboardResult = await dashboardFuture;
    final ordersResult = await ordersFuture;
    final profile = await profileFuture;

    if (!mounted) return;

    if (profile != null) {
      _profileRepository.syncSavedStatusWithBackend(profile);
    }

    setState(() {
      final name = profile?.fullName.trim();
      _partnerDisplayName =
          name != null && name.isNotEmpty ? name : null;
      final photo = profile?.profilePhotoUrl?.trim();
      _partnerPhotoUrl =
          photo != null && photo.isNotEmpty ? photo : null;

      // Always reflect the actual saved availability status.
      // Do not automatically switch between Online and Offline on screen navigation or API refresh.
      _isOnline = ProfileRepository.currentOnlineStatus;

      if (dashboardResult is DashboardData) {
        _dashboardData = dashboardResult;
        _dashboardError = null;
      } else {
        _dashboardError = dashboardResult?.toString() ?? 'Failed to load dashboard.';
      }
      _isLoadingDashboard = false;

      if (ordersResult is List<DpOrder>) {
        final visible = ordersResult
            .where((order) => order.isVisibleOnHomeAssigned)
            .toList();
        final seen = <String>{};
        _orders = visible.where((order) {
          final key = order.orderNumber.isNotEmpty
              ? order.orderNumber
              : (order.id ?? '');
          return key.isNotEmpty && seen.add(key);
        }).toList();
        _ordersError = null;
      } else {
        _ordersError = ordersResult?.toString() ?? 'Failed to load orders.';
      }
      _isLoadingOrders = false;
      _isLoadingProfile = false;
    });

    HomeScreen.isHomeLoadingNotifier.value = false;
  }

  Future<Object?> _loadDashboardSafe({bool log = true}) async {
    try {
      return await _dashboardRepository.getDashboardData(log: log);
    } catch (error) {
      return error;
    }
  }

  Future<Object?> _loadOrdersSafe({bool log = true}) async {
    try {
      return await _ordersRepository.getDpOrders(log: log);
    } catch (error) {
      return error;
    }
  }

  Future<DeliveryPartnerProfile?> _loadProfileSafe({
    bool forceRefresh = false,
  }) async {
    try {
      return await _profileRepository.getProfile(forceRefresh: forceRefresh);
    } catch (_) {
      return ProfileRepository.cachedProfile;
    }
  }

  Future<void> _acceptOrder(DpOrder order) async {
    if (_updatingOrderNumbers.contains(order.orderNumber)) return;
    if (order.isNotDelivered || order.isRejectedStatus) {
      return;
    }

    setState(() => _updatingOrderNumbers.add(order.orderNumber));

    try {
      final updated = await _ordersRepository.updateOrderStatus(
        order: order,
        status: 'start',
      );
      if (!mounted) return;

      try {
        final fresh = await _ordersRepository.refreshOrderDetails(updated);
        _replaceOrder(fresh);
      } catch (_) {
        _replaceOrder(updated);
      }

      final refreshed = await _ordersRepository.getDpOrders();
      if (!mounted) return;
      setState(() {
        _orders = refreshed
            .where((order) => order.isVisibleOnHomeAssigned)
            .toList();
      });

      if (mounted) {
        final current = _orders.firstWhere(
          (o) => o.orderNumber == order.orderNumber,
          orElse: () => updated,
        );
        Navigator.pushNamed(
          context,
          AppRoutes.orderDetailsScreen,
          arguments: {
            'order': current,
            'enableWorkflow': true,
          },
        );
      }
    } catch (error) {
      if (!mounted) return;
      CustomSnackBar.showError(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _updatingOrderNumbers.remove(order.orderNumber));
      }
    }
  }

  Future<void> _setOnline(bool value) async {
    if (_isUpdatingOnline || value == _isOnline) return;
    setState(() => _isUpdatingOnline = true);
    try {
      final updated = await _profileRepository.updateIsOnline(value);
      if (!mounted) return;
      await ProfileRepository.saveOnlineStatus(updated);
      if (!mounted) return;
      setState(() => _isOnline = updated);
      if (updated) {
        _startPollingTimer();
        _refreshOrdersSilently();
      } else {
        _stopPollingTimer();
      }
      BroadcastNotificationService.setOnline(updated);
      CustomSnackBar.showSuccess(
        context,
        updated ? 'You are online' : 'You are offline',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isOnline = ProfileRepository.currentOnlineStatus);
      CustomSnackBar.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _isUpdatingOnline = false);
    }
  }

  void _replaceOrder(DpOrder updated) {
    setState(() {
      if (updated.isReturnedToIap ||
          (updated.isNotDelivered && !updated.isUndeliveredReturnToHub)) {
        _orders = _orders
            .where((item) => item.orderNumber != updated.orderNumber)
            .toList();
        return;
      }

      _orders = _orders
          .map((item) =>
              item.orderNumber == updated.orderNumber ? updated : item)
          .where((order) => order.isVisibleOnHomeAssigned)
          .toList();
    });
  }

  Future<void> _refreshOrdersSilently() async {
    if (!mounted || _isLoadingOrders || _isSilentRefreshing) return;

    final now = DateTime.now();
    if (_lastSilentFetchTime != null &&
        now.difference(_lastSilentFetchTime!) <
            const Duration(seconds: 3)) {
      return;
    }

    _isSilentRefreshing = true;
    _lastSilentFetchTime = now;

    try {
      final ordersResult = await _loadOrdersSafe(log: false);
      if (!mounted) return;

      bool stateChanged = false;
      List<DpOrder>? updatedOrders;

      if (ordersResult is List<DpOrder>) {
        final visible = ordersResult
            .where((order) => order.isVisibleOnHomeAssigned)
            .toList();
        final seen = <String>{};
        final uniqueOrders = visible.where((order) {
          final key = order.orderNumber.isNotEmpty
              ? order.orderNumber
              : (order.id ?? '');
          return key.isNotEmpty && seen.add(key);
        }).toList();

        if (!_areOrdersEqual(_orders, uniqueOrders)) {
          updatedOrders = uniqueOrders;
          stateChanged = true;
        }
      }

      DashboardData? updatedDashboard;
      // Only fetch dashboard if orders actually changed!
      if (stateChanged) {
        final dashboardResult = await _loadDashboardSafe(log: false);
        if (dashboardResult is DashboardData) {
          updatedDashboard = dashboardResult;
        }
      }

      if (stateChanged && mounted) {
        setState(() {
          if (updatedOrders != null) {
            _orders = updatedOrders;
            _ordersError = null;
          }
          if (updatedDashboard != null) {
            _dashboardData = updatedDashboard;
            _dashboardError = null;
          }
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] Silent order refresh error: $e');
    } finally {
      _isSilentRefreshing = false;
    }
  }

  bool _areOrdersEqual(List<DpOrder> a, List<DpOrder> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final oA = a[i];
      final oB = b[i];
      if (oA.orderNumber != oB.orderNumber ||
          oA.id != oB.id ||
          oA.status != oB.status ||
          oA.subStatus != oB.subStatus ||
          oA.flowType != oB.flowType ||
          oA.pickupConfirmedAt != oB.pickupConfirmedAt ||
          oA.arrivedAtDeliveryAt != oB.arrivedAtDeliveryAt ||
          oA.deliveredAt != oB.deliveredAt ||
          oA.completedAt != oB.completedAt ||
          oA.arrivedAtIapAt != oB.arrivedAtIapAt ||
          oA.inTransitAt != oB.inTransitAt ||
          oA.rtoStatus != oB.rtoStatus ||
          oA.returnedToIapAt != oB.returnedToIapAt ||
          oA.rtoCompletedAt != oB.rtoCompletedAt ||
          oA.amount != oB.amount) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.black,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColours.primary,
          backgroundColor: AppColours.black,
          onRefresh: () => _loadHomeData(forceRefreshProfile: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20.h),
                    _buildHeader(),
                    SizedBox(height: 12.h),
                  ],
                ),
              ),
              _buildGradientDivider(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),
                    _buildOnlineToggleCard(),
                    SizedBox(height: 16.h),
                    _buildStatsRow(),
              SizedBox(height: 16.h),
              _isLoading
                  ? Padding(
                      padding: EdgeInsets.only(bottom: 4.h),
                      child: AppShimmer(
                        child: AppShimmer.box(
                          width: 140.w,
                          height: 20.h,
                          borderRadius: 6,
                        ),
                      ),
                    )
                  : Text(
                      'Orders Assigned',
                      style: CustomTextStyles.montserratBold.copyWith(
                        fontSize: 18.fSize,
                        color: AppColours.secondary,
                      ),
                    ),
              SizedBox(height: 16.h),
              _buildOrdersSection(),
                    SizedBox(height: 100.h), // Space for bottom bar
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildGradientDivider() {
    return
      Container(
      height: 2,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFFE6C27A).withValues(alpha: 0.15),
            const Color(0xFFE6C27A),
            const Color(0xFFE6C27A).withValues(alpha: 0.15),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_isLoading) {
      return const HomeHeaderShimmer();
    }

    final photoUrl = _partnerPhotoUrl?.trim();
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColours.primary, width: 1),
          ),
          child: ClipOval(
            child: hasPhoto
                ? Image.network(
                    photoUrl,
                    width: 48.w,
                    height: 48.w,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                      ImageConstant.comfortWearImg6,
                      width: 48.w,
                      height: 48.w,
                      fit: BoxFit.fill,
                    ),
                  )
                : Image.asset(
                    ImageConstant.comfortWearImg6,
                    width: 48.w,
                    height: 48.w,
                    fit: BoxFit.fill,
                  ),
          ),
        ),

        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WELCOME',
                style: CustomTextStyles.openSansRegular.copyWith(
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              Text(
                _partnerDisplayName ?? AuthSession.mobileNumber ?? 'Partner',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ),
            );
            _notificationsRepository.checkUnreadStatus();
          },
          behavior: HitTestBehavior.opaque,
          child: ValueListenableBuilder<bool>(
            valueListenable: NotificationsRepository.hasUnreadNotifier,
            builder: (context, hasUnread, child) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  child!,
                  if (hasUnread)
                    Positioned(
                      top: 4.w,
                      right: 4.w,
                      child: Container(
                        width: 9.w,
                        height: 9.w,
                        decoration: BoxDecoration(
                          color: AppColours.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            child: SvgPicture.asset(
              IconConstant.notification,
              width: 40.w,
              height: 40.w,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnlineToggleCard() {
    if (_isLoading) {
      return const HomeOnlineToggleShimmer();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColours.primary.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10.w,
                height: 10.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isOnline
                      ? const Color(0xFF34A853)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                _isOnline ? 'Your Online' : 'Your Offline',
                style: CustomTextStyles.openSansSemiBold.copyWith(
                  fontSize: 15.fSize,
                  color: AppColours.primary.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: _isOnline,
              onChanged: _isUpdatingOnline ? null : _setOnline,
              thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.black;
                }
                return const Color(0xFFF5E6C8);
              }),
              activeTrackColor: const Color(0xFFE6C27A),
              inactiveTrackColor: const Color(0xFF2A2A32),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    if (_isLoading) {
      return const HomeStatsShimmer();
    }

    if (_dashboardError != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColours.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              _dashboardError!,
              textAlign: TextAlign.center,
              style: CustomTextStyles.openSansRegular.copyWith(fontSize: 12),
            ),
            SizedBox(height: 12.h),
            TextButton(
              onPressed: () => _loadHomeData(forceRefreshProfile: true),
              child: Text(
                'Retry',
                style: CustomTextStyles.montserratBold.copyWith(
                  color: AppColours.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final activeCount = (_dashboardData?.activeOrders ?? 0).toString();
    final completedCount = (_dashboardData?.completedOrders ?? 0).toString();

    return Row(
      children: [
        Expanded(child: _buildStatBox(activeCount, 'Active')),
        SizedBox(width: 16.w),
        Expanded(child: _buildStatBox(completedCount, 'Completed')),
      ],
    );
  }

  Widget _buildOrdersSection() {
    if (_isLoading) {
      return const HomeOrdersShimmer();
    }

    if (_ordersError != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColours.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              _ordersError!,
              textAlign: TextAlign.center,
              style: CustomTextStyles.openSansRegular.copyWith(fontSize: 12),
            ),
            SizedBox(height: 12.h),
            TextButton(
              onPressed: () => _loadHomeData(forceRefreshProfile: true),
              child: Text(
                'Retry',
                style: CustomTextStyles.montserratBold.copyWith(
                  color: AppColours.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 32.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColours.primary.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Text(
          'No orders assigned yet.',
          textAlign: TextAlign.center,
          style: CustomTextStyles.openSansRegular.copyWith(
            fontSize: 14.fSize,
            color: AppColours.secondary,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColours.primary.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _orders.length; i++) ...[
            if (i > 0)
              Divider(
                color: AppColours.primary,
                height: 1,
                thickness: 0.2,
                indent: 18,
                endIndent: 18,
              ),
            _buildOrderItem(
              order: _orders[i],
              isUpdating: _updatingOrderNumbers.contains(_orders[i].orderNumber),
              onAccept: () => _acceptOrder(_orders[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatBox(String count, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColours.primary,width: 0.5),


        // boxShadow: [
        //   BoxShadow(
        //     color: const Color(0xFFCFAF6E).withOpacity(0.3),
        //     blurRadius: 8,
        //     spreadRadius: 4,
        //     offset: const Offset(0, 0), // X=0, Y=0
        //   ),
        // ],
      ),
      child: Column(
        children: [
          Text(
            count,
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 24.fSize,
              color: AppColours.secondary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: CustomTextStyles.openSansRegular.copyWith(
              fontSize: 14.fSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeaderBadge(DpOrder order) {
    final badge = order.journey.statusBadgeInfo;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: badge.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badge.color.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badge.icon, size: 12.h, color: badge.color),
          SizedBox(width: 4.w),
          Text(
            badge.label,
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 11.fSize,
              color: badge.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem({
    required DpOrder order,
    required bool isUpdating,
    required VoidCallback onAccept,
  }) {
    final orderIcon =
        order.usesDeliveryIcon ? IconConstant.delivery : IconConstant.pickup;

    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    SvgPicture.asset(
                      orderIcon,
                      width: 20.h,
                      height: 20.h,
                      colorFilter: const ColorFilter.mode(
                        AppColours.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        order.displayTitle,
                        style: CustomTextStyles.montserratBold.copyWith(
                          fontSize: 16.fSize,
                          color: AppColours.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (order.displayPartnerEarning != null &&
                  ProfileRepository.showsPartnerEarning)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6C27A).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₹ ${order.displayPartnerEarning}',
                    style: CustomTextStyles.openSansBold.copyWith(
                      fontSize: 14.fSize,
                      color: AppColours.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 6.h,
            children: [
              Text(
                order.orderNumber,
                style: CustomTextStyles.openSansRegular.copyWith(
                  fontSize: 12.fSize,
                  color: AppColours.secondary,
                ),
              ),
              SizedBox(width: 20),
              _buildStatusHeaderBadge(order),
            ],
          ),
          if (order.isUndeliveredReturnToHub
                  ? (order.rtoReturnAddress ?? order.pickupAddress) != null
                  : order.pickupAddress != null) ...[
            SizedBox(height: 20.h),
            _buildLocationRow(
              Icons.location_on_outlined,
              order.isUndeliveredReturnToHub
                  ? (order.rtoHubName != null && order.rtoHubName!.isNotEmpty
                      ? order.rtoHubName!
                      : 'IAP Store (Return Destination)')
                  : 'Pickup location',
              order.isUndeliveredReturnToHub
                  ? (order.rtoReturnAddress ?? order.pickupAddress!)
                  : order.pickupAddress!,
              mapEnabled: true,
              onMapTap: () => _openMaps(
                latitude: order.isUndeliveredReturnToHub
                    ? (order.rtoReturnLatitude ?? order.pickupLatitude)
                    : order.pickupLatitude,
                longitude: order.isUndeliveredReturnToHub
                    ? (order.rtoReturnLongitude ?? order.pickupLongitude)
                    : order.pickupLongitude,
                address: order.isUndeliveredReturnToHub
                    ? (order.rtoReturnAddress ?? order.pickupAddress!)
                    : order.pickupAddress!,
              ),
            ),
          ],
          if (order.dropAddress != null) ...[
            SizedBox(height: 16.h),
            _buildLocationRow(
              Icons.location_on_outlined,
              'Drop location',
              order.dropAddress!,
              mapEnabled: order.isDropMapEnabled,
              onMapTap: order.isDropMapEnabled
                  ? () => _openMaps(
                        latitude: order.deliveryLatitude,
                        longitude: order.deliveryLongitude,
                        address: order.dropAddress!,
                      )
                  : null,
            ),
          ],
          if (order.formattedDeliverySchedule != 'Not scheduled') ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: AppColours.primary,
                  size: 16.h,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        if (order.isReturnFlow)
                          TextSpan(
                            text: 'Return Schedule: ',
                            style: CustomTextStyles.openSansSemiBold.copyWith(
                              fontSize: 14.fSize,
                              color: AppColours.primary,
                            ),
                          ),
                        TextSpan(
                          text: order.formattedDeliverySchedule,
                          style: CustomTextStyles.openSansSemiBold.copyWith(
                            fontSize: 14.fSize,
                            color: AppColours.primary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (order.displayNotes != null && order.displayNotes!.isNotEmpty) ...[
            SizedBox(height: 14.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: AppColours.primary,
                  size: 16.h,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: order.isReturnFlow ? 'Return Notes: ' : 'Notes: ',
                          style: CustomTextStyles.openSansSemiBold.copyWith(
                            fontSize: 13.fSize,
                            color: AppColours.primary,
                          ),
                        ),
                        TextSpan(
                          text: order.displayNotes!,
                          style: CustomTextStyles.openSansRegular.copyWith(
                            fontSize: 13.fSize,
                            color: AppColours.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 24.h),
          Row(
            children: [
              if (order.isUndeliveredReturnToHub ||
                  order.isNotDelivered ||
                  order.isRejectedStatus) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: isUpdating
                        ? null
                        : () async {
                            final updated = await Navigator.pushNamed(
                              context,
                              AppRoutes.orderDetailsScreen,
                              arguments: {
                                'order': order,
                                'enableWorkflow': order.isUndeliveredReturnToHub,
                              },
                            );
                            if (updated is DpOrder) {
                              _replaceOrder(updated);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ] else if (order.isAccepted) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: isUpdating
                        ? null
                        : () async {
                            final updated = await Navigator.pushNamed(
                              context,
                              AppRoutes.orderDetailsScreen,
                              arguments: {
                                'order': order,
                                'enableWorkflow': true,
                              },
                            );
                            if (updated is DpOrder) {
                              _replaceOrder(updated);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Order Details',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: Material(
                    color: const Color(0xFFE6C27A),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: isUpdating
                          ? null
                          : onAccept,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: isUpdating
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                order.isReturnFlow
                                    ? 'Start Trip to Customer'
                                    : 'Start Trip to Hub',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openMaps({
    double? latitude,
    double? longitude,
    required String address,
  }) async {
    final Uri uri;
    if (latitude != null && longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
      );
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      CustomSnackBar.showWarning(context, 'Unable to open maps.');
    }
  }

  Widget _buildLocationRow(
    IconData icon,
    String label,
    String location, {
    required bool mapEnabled,
    VoidCallback? onMapTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: AppColours.primary,
          size: 22.h,
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: CustomTextStyles.openSansSemiBold.copyWith(
                  fontSize: 13,
                  color: AppColours.primary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                location,
                style: CustomTextStyles.openSansRegular.copyWith(
                  fontSize: 13,
                  color: AppColours.secondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: mapEnabled ? onMapTap : null,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Opacity(
              // Avoid ColorFilter on stroke-based map.svg — it can hide paths.
              opacity: mapEnabled ? 1.0 : 0.28,
              child: SvgPicture.asset(
                IconConstant.map,
                width: 22.h,
                height: 22.h,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
