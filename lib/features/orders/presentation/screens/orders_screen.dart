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
    _tabController = TabController(length: 5, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool? showLoader}) async {
    // Pull-to-refresh already shows RefreshIndicator — avoid a second overlay spinner.
    final useOverlayLoader = showLoader ?? _ordersData == null;
    setState(() {
      if (useOverlayLoader) _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _repository.getMyOrders(failedOrders: true);
      if (!mounted) return;
      setState(() => _ordersData = data);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            error is ApiException ? error.message : error.toString();
      });
    } finally {
      if (mounted && useOverlayLoader) setState(() => _isLoading = false);
    }
  }

  List<DpOrder> _ordersForTab(String type) {
    final data = _ordersData;
    if (data == null) return const [];

    final all = data.allOrders;
    final List<DpOrder> filtered;
    switch (type) {
      case 'Completed':
        filtered = all.where(_isCompletedOrder).toList();
        break;
      case 'In Transit':
        filtered = all
            .where((order) =>
                !_isCompletedOrder(order) && !order.isNotDelivered)
            .toList();
        break;
      case 'Not Delivered':
        // Delivery failures / RTO-done. Order Delivery stays here even when
        // the parent status is RETURN_FAILED.
        filtered = all
            .where((order) => order.isNotDelivered && !_isPickupFailedOrder(order))
            .toList();
        break;
      case 'Pickup Failed':
        // Only cards labeled Order Return. Order Delivery never belongs here.
        filtered = all.where(_isPickupFailedOrder).toList();
        break;
      default:
        filtered = List<DpOrder>.from(all);
    }
    return _sortLatestFirst(filtered);
  }

  /// Newest activity / assignment first across every My Orders tab.
  List<DpOrder> _sortLatestFirst(List<DpOrder> orders) {
    orders.sort((a, b) {
      final aTime = _orderSortTime(a);
      final bTime = _orderSortTime(b);
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return orders;
  }

  DateTime? _orderSortTime(DpOrder order) {
    DateTime? latest;
    for (final raw in [
      order.completedAt,
      order.rtoCompletedAt,
      order.returnedToIapAt,
      order.deliveredAt,
      order.arrivedAtDeliveryAt,
      order.inTransitAt,
      order.pickupConfirmedAt,
      order.arrivedAtIapAt,
      order.scheduledTime,
    ]) {
      final value = raw?.trim();
      if (value == null || value.isEmpty) continue;
      final parsed = DateTime.tryParse(value);
      if (parsed == null) continue;
      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }
    return latest;
  }

  bool _isNotDeliveredOrder(DpOrder order) => order.isNotDelivered;

  /// Pickup Failed tab is Order Return only (`flow_type: return`).
  bool _isPickupFailedOrder(DpOrder order) =>
      order.isReturnFailed && order.displayTitle == 'Order Return';

  bool _isCompletedOrder(DpOrder order) {
    // RTO-finished failed deliveries use status `returned_to_iap` but belong
    // under Not Delivered, not Completed.
    if (order.isNotDelivered) return false;
    final status = order.status.toLowerCase().trim();
    return status == 'completed' ||
        status == 'delivered' ||
        status == 'returned_to_iap';
  }

  String _myOrdersStatusLabel(DpOrder order) {
    if (_isPickupFailedOrder(order)) return 'Pickup Failed';
    if (order.isNotDelivered) return 'Not Delivered';
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
                      _buildOrderList('In Transit'),
                      _buildOrderList('Completed'),
                      _buildOrderList('Not Delivered'),
                      _buildOrderList('Pickup Failed'),
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
    return Center(
      child: _OrderStatusTabs(controller: _tabController),
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
      onRefresh: () => _loadOrders(showLoader: false),
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
    final isInTransit =
        !_isCompletedOrder(order) && !_isNotDeliveredOrder(order);
    final orderType = order.displayTitle;
    final dateText = _formatOrderDate(order);

    return InkWell(
      onTap: () async {
        final updated = await Navigator.pushNamed(
          context,
          AppRoutes.orderDetailsScreen,
          arguments: {
            'order': order,
            'isInTransit': isInTransit,
            'enableWorkflow': order.isUndeliveredReturnToHub,
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
            if (order.displayPartnerEarning != null &&
                ProfileRepository.showsPartnerEarning) ...[
              SizedBox(height: 8.h),
              Text(
                'Earning: ₹${order.displayPartnerEarning}',
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
    if (order.isReturnFlow &&
        order.formattedDeliverySchedule != 'Not scheduled') {
      return order.formattedDeliverySchedule;
    }
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

class _OrderStatusTabs extends StatefulWidget {
  const _OrderStatusTabs({required this.controller});

  final TabController controller;

  @override
  State<_OrderStatusTabs> createState() => _OrderStatusTabsState();
}

class _OrderStatusTabsState extends State<_OrderStatusTabs> {
  static const _labels = <String>[
    'All',
    'In Transit',
    'Completed',
    'Not Delivered',
    'Pickup Failed',
  ];

  /// Width of the first three tabs, including the 16px side padding and 12px gaps.
  static const _visibleWidth = 380.0;

  static const _labelColor = Color(0xFFF5E6C8);

  final List<GlobalKey> _tabKeys =
      List<GlobalKey>.generate(_labels.length, (_) => GlobalKey());

  int _visibleIndex = 0;

  @override
  void initState() {
    super.initState();
    _visibleIndex = widget.controller.index;
    widget.controller.addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant _OrderStatusTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTabChanged);
      widget.controller.addListener(_onTabChanged);
      _visibleIndex = widget.controller.index;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    final index = widget.controller.index;
    if (index == _visibleIndex) return;
    _visibleIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollSelectedIntoView(index);
    });
  }

  void _scrollSelectedIntoView(int index) {
    final target = _tabKeys[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: index == 0
          ? 0
          : (index == _labels.length - 1 ? 1 : 0.5),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context).width - 32;
    final width = viewport < _visibleWidth ? viewport : _visibleWidth;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final selectedIndex = widget.controller.index;
        return Container(
          width: width,
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F14),
            borderRadius: BorderRadius.circular(41),
            border: Border.all(
              color: const Color(0xFFE6C27A),
              width: 1,
            ),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            itemCount: _labels.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _buildTab(index, selectedIndex == index);
            },
          ),
        );
      },
    );
  }

  Widget _buildTab(int index, bool selected) {
    final isPrimarySlot = index < 3;
    return GestureDetector(
      key: _tabKeys[index],
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.controller.animateTo(index),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE6C27A).withValues(alpha: 0.20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(selected ? 36 : 24),
        ),
        child: SizedBox(
          width: isPrimarySlot ? (index == 2 ? 106 : 109) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: selected || !isPrimarySlot ? 16 : 8,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _labels[index],
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: CustomTextStyles.openSansSemiBold.copyWith(
                    fontSize: 14,
                    height: 24 / 14,
                    letterSpacing: 0,
                    color: _labelColor.withValues(
                      alpha: selected ? 1 : 0.35,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
