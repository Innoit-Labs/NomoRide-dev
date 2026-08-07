import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/auth_session.dart';
import '../../../../core/utils/icon_constant.dart';
import '../../../../theme/theme_helper.dart';
import '../../../../routes/app_routes.dart';
import '../../../../core/utils/size_utils.dart';
import '../../../../core/utils/image_constant.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../profile/data/models/delivery_partner_profile.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/dashboard_repository.dart';
import '../../data/models/dashboard_data.dart';
import '../../data/models/dp_order.dart';
import '../../data/orders_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final OrdersRepository _ordersRepository = OrdersRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  final Set<String> _updatingOrderNumbers = {};
  bool _isLoadingDashboard = true;
  bool _isLoadingOrders = true;
  String? _dashboardError;
  String? _ordersError;
  String? _partnerDisplayName;
  String? _partnerPhotoUrl;
  DashboardData? _dashboardData;
  List<DpOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData({bool forceRefreshProfile = false}) async {
    debugPrint('========== CURRENT AUTH TOKEN ==========');
    debugPrint('authToken: ${AuthSession.authToken}');
    debugPrint('========================================');

    setState(() {
      _isLoadingDashboard = true;
      _isLoadingOrders = true;
      _dashboardError = null;
      _ordersError = null;
    });

    final dashboardFuture = _loadDashboardSafe();
    final ordersFuture = _loadOrdersSafe();
    final profileFuture = _loadProfileSafe(forceRefresh: forceRefreshProfile);
    final dashboardResult = await dashboardFuture;
    final ordersResult = await ordersFuture;
    final profile = await profileFuture;

    if (!mounted) return;

    setState(() {
      final name = profile?.fullName.trim();
      _partnerDisplayName =
          name != null && name.isNotEmpty ? name : null;
      final photo = profile?.profilePhotoUrl?.trim();
      _partnerPhotoUrl =
          photo != null && photo.isNotEmpty ? photo : null;

      if (dashboardResult is DashboardData) {
        _dashboardData = dashboardResult;
        _dashboardError = null;
      } else {
        _dashboardError = dashboardResult?.toString() ?? 'Failed to load dashboard.';
      }
      _isLoadingDashboard = false;

      if (ordersResult is List<DpOrder>) {
        _orders = ordersResult;
        _ordersError = null;
      } else {
        _ordersError = ordersResult?.toString() ?? 'Failed to load orders.';
      }
      _isLoadingOrders = false;
    });
  }

  Future<Object?> _loadDashboardSafe() async {
    try {
      return await _dashboardRepository.getDashboardData();
    } catch (error) {
      return error;
    }
  }

  Future<Object?> _loadOrdersSafe() async {
    try {
      return await _ordersRepository.getDpOrders();
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

    setState(() => _updatingOrderNumbers.add(order.orderNumber));

    try {
      await _ordersRepository.updateOrderStatus(
        order: order,
        status: 'start',
      );
      if (!mounted) return;
      final refreshed = await _ordersRepository.getDpOrders();
      if (!mounted) return;
      setState(() => _orders = refreshed);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingOrderNumbers.remove(order.orderNumber));
      }
    }
  }

  void _replaceOrder(DpOrder updated) {
    setState(() {
      _orders = _orders
          .map((item) =>
              item.orderNumber == updated.orderNumber ? updated : item)
          .toList();
    });
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
                    SizedBox(height: 24.h),
                    _buildStatsRow(),
              SizedBox(height: 32.h),
              Text(
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
        Column(
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
              style: CustomTextStyles.montserratBold.copyWith(
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const Spacer(),

        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: SvgPicture.asset(
            IconConstant.notification,
            width: 40.w,
            height: 40.w,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    if (_isLoadingDashboard) {
      return const HomeStatsShimmer();
    }

    if (_dashboardError != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColours.primary.withOpacity(0.3)),
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
    if (_isLoadingOrders) {
      return const HomeOrdersShimmer();
    }

    if (_ordersError != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColours.primary.withOpacity(0.3)),
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
            color: AppColours.primary.withOpacity(0.5),
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
          color: AppColours.primary.withOpacity(0.5),
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

  Widget _buildOrderItem({
    required DpOrder order,
    required bool isUpdating,
    required VoidCallback onAccept,
  }) {
    final orderIcon =
        order.isDeliveryOrderCard ? IconConstant.delivery : IconConstant.pickup;

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
              if (order.amount != null && ProfileRepository.showsPartnerEarning)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6C27A).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₹ ${order.amount}',
                    style: CustomTextStyles.openSansBold.copyWith(
                      fontSize: 14.fSize,
                      color: AppColours.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            order.orderNumber,
            style: CustomTextStyles.openSansRegular.copyWith(
              fontSize: 12.fSize,
              color: AppColours.secondary,
            ),
          ),
          if (order.pickupAddress != null) ...[
            SizedBox(height: 20.h),
            _buildLocationRow(
              Icons.location_on_outlined,
              'Pickup location',
              order.pickupAddress!,
              mapEnabled: true,
              onMapTap: () => _openMaps(
                latitude: order.pickupLatitude,
                longitude: order.pickupLongitude,
                address: order.pickupAddress!,
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
          if (order.scheduledTime != null) ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: AppColours.primary,
                  size: 16.h,
                ),
                SizedBox(width: 8.w),
                Text(
                  order.formattedScheduleTime,
                  style: CustomTextStyles.openSansSemiBold.copyWith(
                    fontSize: 14.fSize,
                    color: AppColours.primary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 24.h),
          Row(
            children: [
              Expanded(
                child: order.isAccepted
                    ? OutlinedButton(
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
                      )
                    : ElevatedButton(
                        onPressed: isUpdating
                            ? null
                            : () => _showAcceptDialog(context, onAccept),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE6C27A), Color(0xFFE6C27A)],
                            ),
                          ),
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
                                : const Text(
                                    'Accept',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open maps.')),
      );
    }
  }

  void _showAcceptDialog(BuildContext context, VoidCallback onAccept) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 28.h,
          ),

          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE6C27A).withOpacity(0.1),
            ),
            // boxShadow: [
            //   BoxShadow(
            //     color: const Color(0xFFE6C27A).withOpacity(0.12),
            //     blurRadius: 20,
            //     spreadRadius: 1,
            //   ),
            // ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              /// Title
              Text(
                'Accept the Order ?',
                style: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 16.fSize,
                  color: const Color(0xFFE6C27A),
                ),
              ),

              SizedBox(height: 30.h),

              /// Buttons
              Row(
                children: [

                  /// Back Button
                  Expanded(
                    child: SizedBox(
                      height: 44.h,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF3E6C9),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: CustomTextStyles.montserratBold.copyWith(
                            color: Colors.black,
                            fontSize: 14.fSize,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: 16.w),

                  /// Confirm Button
                  Expanded(
                    child: SizedBox(
                      height: 44.h,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onAccept();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6C27A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Yes, Confirm',
                          style: CustomTextStyles.montserratBold.copyWith(
                            color: Colors.black,
                            fontSize: 14.fSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
