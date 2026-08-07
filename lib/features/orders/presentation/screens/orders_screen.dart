import 'package:flutter/material.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';
import 'package:nomoride/features/orders/data/models/my_orders_data.dart';
import 'package:nomoride/features/orders/data/my_orders_repository.dart';
import 'package:nomoride/features/profile/data/profile_repository.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/theme_helper.dart';
import '../../../../core/utils/size_utils.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  final MyOrdersRepository _repository = MyOrdersRepository();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  MyOrdersData? _ordersData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dataFuture = _repository.getMyOrders();
      final profileFuture = ProfileRepository().getProfile().then(
        (_) {},
        onError: (_) {},
      );
      final data = await dataFuture;
      await profileFuture;
      if (!mounted) return;
      setState(() => _ordersData = data);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            error is ApiException ? error.message : error.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DpOrder> _ordersForTab(String type) {
    final data = _ordersData;
    if (data == null) return const [];

    final all = data.allOrders;
    switch (type) {
      case 'Completed':
        return all.where(_isCompletedOrder).toList();
      case 'In Transit':
        return all.where((order) => !_isCompletedOrder(order)).toList();
      default:
        return all;
    }
  }

  bool _isCompletedOrder(DpOrder order) {
    final status = order.status.toLowerCase().trim();
    return status == 'completed' ||
        status == 'delivered' ||
        status == 'returned_to_iap';
  }

  String _myOrdersStatusLabel(DpOrder order) {
    return _isCompletedOrder(order) ? 'Completed' : 'In Transit';
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppColours.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColours.primary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'My Orders',
          style: CustomTextStyles.montserratBold.copyWith(
            color: AppColours.primary,
            fontSize: 18.fSize,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
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
          ),
          SizedBox(height: 16.h),
          _buildTabBar(),
          Expanded(
            child: Stack(
              children: [
                if (_errorMessage != null && !_isLoading)
                  _buildErrorState()
                else
                  TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrderList('All'),
                      _buildOrderList('Completed'),
                      _buildOrderList('In Transit'),
                    ],
                  ),
                if (_isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColours.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage ?? 'Failed to load orders.',
              textAlign: TextAlign.center,
              style: CustomTextStyles.openSansRegular.copyWith(
                color: AppColours.secondary,
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColours.primary,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48.h,
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFE6C279),
          width: 1.2,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF3A3225),
          borderRadius: BorderRadius.circular(24),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFFF5E6C8),
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Completed'),
          Tab(text: 'In Transit'),
        ],
      ),
    );
  }

  Widget _buildOrderList(String type) {
    final orders = _ordersForTab(type);

    if (orders.isEmpty && !_isLoading) {
      return Center(
        child: Text(
          'No orders found.',
          style: CustomTextStyles.openSansRegular.copyWith(
            color: AppColours.hintcolor,
            fontSize: 14.fSize,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColours.primary,
      backgroundColor: AppColours.black,
      onRefresh: _loadOrders,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(24.w),
        itemCount: orders.length,
        separatorBuilder: (context, index) => SizedBox(height: 16.h),
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(DpOrder order) {
    final statusLabel = _myOrdersStatusLabel(order);
    final isInTransit = !_isCompletedOrder(order);
    final orderType = order.isReturnFlow ? 'Return' : order.displayTitle;
    final dateText = _formatOrderDate(order);

    return InkWell(
      onTap: () async {
        final updated = await Navigator.pushNamed(
          context,
          AppRoutes.orderDetailsScreen,
          arguments: {
            'order': order,
            'isInTransit': isInTransit,
            'enableWorkflow': false,
          },
        );
        if (updated is DpOrder) {
          _loadOrders();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColours.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order id: ${order.orderNumber}',
                    style: CustomTextStyles.montserratBold.copyWith(
                      fontSize: 14.fSize,
                      color: AppColours.primary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6C27A).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusLabel,
                    style: CustomTextStyles.openSansSemiBold.copyWith(
                      fontSize: 11.fSize,
                      color: AppColours.primary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Order Type: $orderType',
              style: CustomTextStyles.openSansSemiBold.copyWith(
                fontSize: 13.fSize,
              ),
            ),
            if (order.amount != null &&
                ProfileRepository.showsPartnerEarning) ...[
              SizedBox(height: 8.h),
              Text(
                'Earning: ₹${order.amount}',
                style: CustomTextStyles.openSansRegular.copyWith(
                  fontSize: 12.fSize,
                  color: AppColours.hintcolor,
                ),
              ),
            ],
            SizedBox(height: 16.h),
            Divider(color: AppColours.primary, thickness: 0.2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Date: $dateText',
                    style: CustomTextStyles.openSansRegular.copyWith(
                      fontSize: 11.fSize,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Order Details',
                      style: CustomTextStyles.openSansSemiBold.copyWith(
                        fontSize: 11.fSize,
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white38, size: 16.h),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatOrderDate(DpOrder order) {
    final raw = order.completedAt ?? order.scheduledTime;
    if (raw == null || raw.isEmpty) return 'Not available';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final date = parsed.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour > 12
        ? date.hour - 12
        : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/${date.year} , $hour:$minute $period';
  }
}
