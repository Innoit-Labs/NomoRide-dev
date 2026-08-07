  import 'dart:io';
  import 'package:flutter/material.dart';
  import 'package:flutter_svg/flutter_svg.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:nomoride/core/network/api_exception.dart';
  import 'package:nomoride/core/services/location_service.dart';
  import 'package:nomoride/core/utils/icon_constant.dart';
  import 'package:nomoride/features/home/data/models/dp_order.dart';
  import 'package:nomoride/features/home/data/models/dp_order_product.dart';
  import 'package:nomoride/features/home/data/models/order_journey.dart';
  import 'package:nomoride/features/home/data/orders_repository.dart';
  import 'package:nomoride/features/profile/data/profile_repository.dart';
  import 'package:url_launcher/url_launcher.dart';
  import '../../../../theme/theme_helper.dart';
  import '../../../../routes/app_routes.dart';
  import '../../../../core/utils/size_utils.dart';
  import 'package:dotted_border/dotted_border.dart';

  class OrderDetailsScreen extends StatefulWidget {
    const OrderDetailsScreen({super.key});

    @override
    State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
  }

  class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
    final OrdersRepository _ordersRepository = OrdersRepository();

    bool _argsLoaded = false;
    bool _isRefreshing = false;
    bool _isUpdating = false;
    bool _preferHistorySource = false;
    bool _enableWorkflow = false;
    DpOrder? _order;
    late List<bool> _itemChecked;
    late List<String?> _photoProofs;
    final Set<int> _expandedProductIndexes = <int>{};

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      if (_argsLoaded) return;

      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final order = args['order'];
        if (order is DpOrder) {
          _order = order;
        }
        _preferHistorySource = args['isInTransit'] == false;
        _enableWorkflow = args['enableWorkflow'] == true;
      }

      _syncSelectionState(_order);
      _argsLoaded = true;

      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOrder());
    }

    void _syncSelectionState(DpOrder? order) {
      final products = order?.products ?? const [];
      final groupedAsKit = products.length > 1 &&
          products.every((product) => product.garments.isEmpty);
      // One checkbox per visible product card (grouped kit = 1 card).
      final checkboxCount = products.isEmpty
          ? 1
          : (groupedAsKit ? 1 : products.length);
      _itemChecked = List<bool>.filled(checkboxCount, false);
      _photoProofs = [null, null];
      _expandedProductIndexes.clear();
    }

    OrderJourney get _journey => OrderJourney(_order!);

    bool get _isReturnOrder => _order?.isReturnFlow ?? false;

    /// Order-type driven labels (Figma): pickup vs delivery assignment.
    bool get _isDeliveryOrderType =>
        !_isReturnOrder && (_order?.isDeliveryOrderCard ?? false);

    bool get _canConfirm {
      final hasPhoto = _photoProofs.any(
        (photo) => photo != null && photo.trim().isNotEmpty,
      );
      if (!hasPhoto) return false;

      // Single product / grouped kit: photo proof is enough to enable action.
      if (_itemChecked.length <= 1) return true;

      return _itemChecked.every((check) => check);
    }

    bool get _canPerformNextAction {
      final next = _journey.nextStep;
      if (next == null || _isUpdating) return false;
      if (_journey.requiresConfirmation) return _canConfirm;
      return true;
    }

    Future<void> _refreshOrder({bool showLoading = true}) async {
      final order = _order;
      if (order == null) return;

      if (showLoading) setState(() => _isRefreshing = true);
      try {
        final profileFuture = ProfileRepository().getProfile().then(
          (_) {},
          onError: (_) {},
        );
        final refreshed = await _ordersRepository.refreshOrderDetails(
          order,
          preferHistorySource: _preferHistorySource,
        );
        await profileFuture;
        if (mounted) {
          setState(() {
            _order = refreshed;
            _syncSelectionState(refreshed);
          });
        }
      } catch (error) {
        if (!mounted) return;
        final message =
            error is ApiException ? error.message : error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade800,
          ),
        );
      } finally {
        if (mounted && showLoading) setState(() => _isRefreshing = false);
      }
    }

    Future<void> _syncOrderAfterUpdate(DpOrder fallback) async {
      final refreshed = await _ordersRepository.refreshOrderDetails(
        fallback,
        preferHistorySource: _preferHistorySource,
      );
      if (!mounted) return;
      setState(() {
        _order = refreshed;
        _syncSelectionState(refreshed);
      });
    }

    Future<void> _updateStatus({
      required String status,
      String? rejectReason,
      List<String> photoProofPaths = const [],
    }) async {
      final order = _order;
      if (order == null || _isUpdating) return;

      setState(() => _isUpdating = true);

      try {
        double? latitude;
        double? longitude;
        if (LocationService.requiresLocationForStatus(status)) {
          final position = await LocationService.getCurrentPosition();
          latitude = position.latitude;
          longitude = position.longitude;
        }

        final updated = await _ordersRepository.updateOrderStatus(
          order: order,
          status: status,
          rejectReason: rejectReason,
          photoProofPaths: photoProofPaths,
          latitude: latitude,
          longitude: longitude,
        );

        if (!mounted) return;

        await _syncOrderAfterUpdate(updated);

        if (!mounted) return;

        final currentOrder = _order;
        if (currentOrder == null) return;

        if (status == 'delivery_success' || currentOrder.journey.isCompleted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.deliverySuccessScreen,
            (route) => route.settings.name == AppRoutes.mainContainer,
            arguments: {'isPickup': false, 'isReturn': _isReturnOrder},
          );
        }
      } catch (error) {
        if (!mounted) return;

        final message =
            error is ApiException ? error.message : error.toString();

        if (_shouldRefreshAfterStatusError(message)) {
          await _refreshOrder(showLoading: false);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade800,
          ),
        );
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }

    bool _shouldRefreshAfterStatusError(String message) {
      final lower = message.toLowerCase();
      const markers = [
        'arrived_at_iap',
        'arrived_at_customer',
        'arrived_at_delivery',
        'confirm_pickup',
        'pickup_confirmed',
        'confirm_delivery',
        'in_transit_to_delivery',
        'in_transit_to_customer',
        'in_transit_to_iap',
        'delivery_success',
        'returned_to_iap',
        'already',
      ];
      return markers.any(lower.contains);
    }

    Future<void> _handleNextAction() async {
      final next = _journey.nextStep;
      if (next == null) return;

      if (next.apiStatus == 'confirm_pickup' ||
          next.apiStatus == 'confirm_delivery') {
        if (_journey.requiresReturnConfirmation) {
          final isReturnPickup = next.apiStatus == 'confirm_pickup';
          final confirmed = await _showConfirmReturnDialog(
            context,
            isReturnPickup: isReturnPickup,
          );
          if (confirmed != true) return;
        } else {
          final isPickupConfirm = next.apiStatus == 'confirm_pickup';
          final confirmed = await _showConfirmPickupOrDeliveryDialog(
            context,
            isPickup: isPickupConfirm,
          );
          if (confirmed != true) return;
        }
      }

      await _updateStatus(
        status: next.apiStatus,
        photoProofPaths: _collectPhotoProofPaths(next.apiStatus),
      );
    }

    List<String> _collectPhotoProofPaths(String status) {
      if (status != 'confirm_pickup' && status != 'confirm_delivery') {
        return const [];
      }
      return _photoProofs
          .whereType<String>()
          .map((path) => path.trim())
          .where((path) => path.isNotEmpty)
          .toSet()
          .toList();
    }

    String get _locationAddress {
      final order = _order;
      if (order == null) return 'Address not available';
      if (_isReturnOrder) {
        if (_journey.currentPhase == OrderPhase.returnToIap) {
          return order.dropAddress ?? 'IAP / warehouse address not available';
        }
        return order.pickupAddress ?? 'Customer return address not available';
      }
      if (_isDeliveryOrderType) {
        return order.dropAddress ?? 'Delivery address not available';
      }
      return order.pickupAddress ?? 'Pickup address not available';
    }

    ({double? latitude, double? longitude}) get _locationCoordinates {
      final order = _order;
      if (order == null) return (latitude: null, longitude: null);
      if (_isReturnOrder) {
        if (_journey.currentPhase == OrderPhase.returnToIap) {
          return (
            latitude: order.deliveryLatitude,
            longitude: order.deliveryLongitude,
          );
        }
        return (
          latitude: order.pickupLatitude,
          longitude: order.pickupLongitude,
        );
      }
      if (_isDeliveryOrderType) {
        return (
          latitude: order.deliveryLatitude,
          longitude: order.deliveryLongitude,
        );
      }
      return (
        latitude: order.pickupLatitude,
        longitude: order.pickupLongitude,
      );
    }

    String get _instructionsText {
      final text = _order?.displayInstructions;
      if (text != null && text.isNotEmpty) return text;
      return 'No instructions provided';
    }

    String get _itemsSectionTitle {
      if (_enableWorkflow && _journey.requiresConfirmation) {
        return 'Select Items *';
      }
      if (_isReturnOrder) return 'Items To Return';
      return _isDeliveryOrderType ? 'Items To Deliver' : 'Items To Pickup';
    }

    String get _locationSectionTitle {
      if (_isReturnOrder) {
        return _journey.currentPhase == OrderPhase.returnToIap
            ? 'IAP / Warehouse'
            : 'Return Pickup Location';
      }
      return _isDeliveryOrderType ? 'Delivery Details' : 'Pickup Location';
    }

    String get _addressLabel {
      if (_isReturnOrder) {
        return _journey.currentPhase == OrderPhase.returnToIap
            ? 'IAP / WAREHOUSE ADDRESS'
            : 'CUSTOMER RETURN ADDRESS';
      }
      return _isDeliveryOrderType ? 'DELIVERY ADDRESS' : 'PICKUP ADDRESS';
    }

    String get _scheduleLabel {
      if (_isReturnOrder) return 'RETURN SCHEDULE';
      return _isDeliveryOrderType ? 'DELIVERY SCHEDULE' : 'PICKUP SCHEDULE';
    }

    String get _instructionsTitle {
      if (_isReturnOrder) return 'Return Instructions';
      return _isDeliveryOrderType
          ? 'Delivery Instructions'
          : 'Pickup Instructions';
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

      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open maps.')),
        );
      }
    }

    Future<void> _callCustomer() async {
      final phone = _order?.customerPhone?.trim();
      if (phone == null || phone.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer phone number is not available.')),
        );
        return;
      }

      final uri = Uri(scheme: 'tel', path: phone);
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to place the call.')),
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      if (_order == null) {
        return Scaffold(
          backgroundColor: AppColours.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColours.primary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Order Details',
              style: CustomTextStyles.montserratBold.copyWith(
                color: AppColours.primary,
                fontSize: 18.fSize,
              ),
            ),
            centerTitle: true,
          ),
          body: Center(
            child: Text(
              'Order details not available.',
              style: CustomTextStyles.openSansRegular.copyWith(
                fontSize: 14.fSize,
                color: AppColours.secondary,
              ),
            ),
          ),
        );
      }

      final order = _order!;
      return Scaffold(
        backgroundColor: AppColours.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColours.primary),
            onPressed: _isUpdating ? null : () => Navigator.pop(context, order),
          ),
          title: Text(
            'Order Details',
            style: CustomTextStyles.montserratBold.copyWith(
              color: AppColours.primary,
              fontSize: 18.fSize,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Container(
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
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
          padding: EdgeInsets.only(top: 16.h, bottom: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCustomerDetails(),
                    if (_journey.showCustomerDeliveryAddress) ...[
                      SizedBox(height: 16.h),
                      _buildHighlightedAddressCard(
                        title: _isReturnOrder
                            ? 'CUSTOMER RETURN ADDRESS'
                            : 'CUSTOMER DELIVERY ADDRESS',
                        address: _isReturnOrder
                            ? order.pickupAddress
                            : order.dropAddress,
                        fallback: _isReturnOrder
                            ? 'Customer return address not available'
                            : 'Delivery address not available',
                      ),
                    ],
                    if (_journey.showIapReturnAddress) ...[
                      SizedBox(height: 16.h),
                      _buildHighlightedAddressCard(
                        title: 'IAP / WAREHOUSE ADDRESS',
                        address: order.dropAddress,
                        fallback: 'IAP / warehouse address not available',
                      ),
                    ],
                    SizedBox(height: 24.h),
                    _buildSectionHeader(
                      _itemsSectionTitle,
                      order.itemsCountLabel,
                    ),
                    SizedBox(height: 16.h),
                    if (order.products.isEmpty)
                      _buildProductsUnavailable()
                    else
                      _buildProductsList(order),
                  ],
                ),
              ),
              SizedBox(height: 32.h),
              _buildGradientDivider(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),
                    _buildSectionHeader(_locationSectionTitle, ''),
                    SizedBox(height: 16.h),
                    _buildDeliveryDetail(
                      icon: Icons.location_on_outlined,
                      label: _addressLabel,
                      value: _locationAddress,
                      trailingIcon: Opacity(
                        opacity: 1,
                        child: SvgPicture.asset(
                          IconConstant.map,
                          width: 22,
                          height: 22,
                        ),
                      ),
                      onTrailingTap: () {
                        final coords = _locationCoordinates;
                        _openMaps(
                          latitude: coords.latitude,
                          longitude: coords.longitude,
                          address: _locationAddress,
                        );
                      },
                    ),
                    SizedBox(height: 24.h),
                    _buildDeliveryDetail(
                      icon: Icons.calendar_today_outlined,
                      label: _scheduleLabel,
                      value: order.formattedScheduleTime,
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
              _buildGradientDivider(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 32.h),
                    _buildInstructions(),
                    if (_enableWorkflow && _journey.requiresConfirmation) ...[
                      SizedBox(height: 32.h),
                      Text(
                        'Photo Proof *',
                        style: CustomTextStyles.montserratBold.copyWith(
                          fontSize: 14.fSize,
                          color: AppColours.primary,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(child: _buildPhotoUploadBox(0)),
                          SizedBox(width: 16.w),
                          Expanded(child: _buildPhotoUploadBox(1)),
                        ],
                      ),
                    ],
                    SizedBox(height: 48.h),
                    if (_enableWorkflow &&
                        !_journey.isCompleted &&
                        !_journey.isRejected) ...[
                      if (ProfileRepository.showsPartnerEarning) ...[
                        _buildTotalFare(order.amount ?? '0'),
                        SizedBox(height: 24.h),
                      ],
                      if (_journey.nextStep != null)
                        _buildPrimaryButton(
                          _isUpdating
                              ? 'Updating...'
                              : _journey.nextActionLabel,
                          onPressed:
                              _canPerformNextAction ? _handleNextAction : null,
                        ),
                      if (!_isReturnOrder &&
                          _journey.currentPhase == OrderPhase.delivery &&
                          _journey.nextStep != null &&
                          !_journey.isAwaitingDeliveryStart) ...[
                        SizedBox(height: 16.h),
                        _buildSecondaryButton(
                          'Not Delivered',
                          onPressed: _isUpdating
                              ? null
                              : () => _showNotDeliveredDialog(context),
                        ),
                      ],
                    ] else if (!_enableWorkflow &&
                        !_journey.isCompleted &&
                        !_journey.isRejected) ...[
                      if (ProfileRepository.showsPartnerEarning)
                        _buildTotalFare(order.amount ?? '0'),
                    ] else if (_journey.isCompleted) ...[
                      _buildCompletedBanner(),
                    ] else if (_journey.isRejected) ...[
                      _buildRejectedBanner(),
                    ],
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ],
          ),
        ),
            if (_isRefreshing || _isUpdating)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColours.primary),
                ),
              ),
          ],
        ),
      );
    }

    Widget _buildGradientDivider() {
      return Padding(
        padding: const EdgeInsets.only(left: 16.0,right: 16),
        child: Container(
          height: 1,
          color: const Color(0x1AE6C27A),
        ),
      );
    }

    Widget _buildHighlightedAddressCard({
      required String title,
      required String? address,
      required String fallback,
    }) {
      final value = address?.trim();
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColours.primary.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: CustomTextStyles.openSansRegular.copyWith(
                fontSize: 11.fSize,
                color: AppColours.hintcolor,
                letterSpacing: 0.8,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              value?.isNotEmpty == true ? value! : fallback,
              style: CustomTextStyles.openSansSemiBold.copyWith(
                fontSize: 14.fSize,
                color: AppColours.secondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildCustomerDetails() {
      final order = _order!;
      return Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColours.primary),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Details',
                    style: CustomTextStyles.openSansRegular.copyWith(
                      fontSize: 12.fSize,
                      color: AppColours.hintcolor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    order.customerDisplayName,
                    style: CustomTextStyles.montserratBold.copyWith(
                      fontSize: 16.fSize,
                      color: AppColours.secondary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _callCustomer,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: SvgPicture.asset(IconConstant.phone),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildCompletedBanner() {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColours.successBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColours.successBorder),
        ),
        child: Text(
          _completedBannerLabel,
          textAlign: TextAlign.center,
          style: CustomTextStyles.montserratBold.copyWith(
            fontSize: 14.fSize,
            color: AppColours.success,
          ),
        ),
      );
    }

    String get _completedBannerLabel {
      final status = _order?.status.toLowerCase().trim() ?? '';
      if (status == 'completed' || status == 'delivered') {
        return 'Delivery Success';
      }
      if (status == 'returned_to_iap') {
        return 'Return Success';
      }
      return _journey.statusSummary;
    }

    Widget _buildRejectedBanner() {
      final status = _order?.status.toLowerCase().trim();
      final label = status == 'not_delivered' ? 'Not Delivered' : 'Order Rejected';
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: CustomTextStyles.montserratBold.copyWith(
            fontSize: 14.fSize,
            color: Colors.redAccent,
          ),
        ),
      );
    }

    Widget _buildSectionHeader(String title, String trailing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 12.fSize,
              color: AppColours.primary,
            ),
          ),
          if (trailing.isNotEmpty)
            Text(
              trailing,
              style: CustomTextStyles.openSansRegular.copyWith(
                fontSize: 12.fSize,
              ),
            ),
        ],
      );
    }



    Widget _buildProductsUnavailable() {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColours.primary.withValues(alpha: 0.25)),
        ),
        child: Text(
          'Product details are not available for this order yet.',
          style: CustomTextStyles.openSansRegular.copyWith(
            fontSize: 12.fSize,
            color: AppColours.secondary,
            height: 1.4,
          ),
        ),
      );
    }

    Widget _buildProductsList(DpOrder order) {
      final products = order.products;
      final shouldGroupAsKit = products.length > 1 &&
          products.every((product) => product.garments.isEmpty);

      if (shouldGroupAsKit) {
        final images = <String>[
          for (final product in products) ...product.imageUrls,
        ];
        final garments = DpOrderGarment.mergeDuplicates(
          products
              .map(
                (product) => DpOrderGarment(
                  name: product.displayTitle ?? product.name,
                  quantity: product.quantity != null && product.quantity! > 0
                      ? product.quantity
                      : 1,
                  imageUrl: product.imageUrls.isNotEmpty
                      ? product.imageUrls.first
                      : null,
                ),
              )
              .toList(),
        );

        final totalGarments = garments.fold<int>(
          0,
          (sum, item) => sum + (item.quantity ?? 1),
        );

        final durationDays = products
            .map((p) => p.durationDays)
            .whereType<int>()
            .toList();
        final durationLabels = products
            .map((p) => p.durationLabel?.trim())
            .whereType<String>()
            .where((label) => label.isNotEmpty)
            .toList();

        final kit = DpOrderProduct(
          name: order.packageType ?? 'Wardrobe Kit',
          durationDays: durationDays.isEmpty ? null : durationDays.first,
          durationLabel: durationLabels.isEmpty ? null : durationLabels.first,
          garmentCount: totalGarments,
          imageUrls: images,
          garments: garments,
        );

        return _buildItemCard(0, kit);
      }

      return Column(
        children: [
          for (var index = 0; index < products.length; index++) ...[
            _buildItemCard(index, products[index]),
            if (index != products.length - 1) SizedBox(height: 16.h),
          ],
        ],
      );
    }

    Widget _buildItemCard(int index, DpOrderProduct product) {
      final title = product.displayTitle;
      final garmentLabel = product.garmentCountLabel;
      final expanded = _expandedProductIndexes.contains(index);
      final items = product.expandableItems;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildProductImage(product.imageUrls),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? 'Product details unavailable',
                      style: CustomTextStyles.openSansSemiBold.copyWith(
                        fontSize: 14.fSize,
                        color: AppColours.secondary,
                      ),
                    ),
                    if (garmentLabel != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        garmentLabel,
                        style: CustomTextStyles.openSansRegular.copyWith(
                          fontSize: 12.fSize,
                          color: AppColours.hintcolor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (expanded) {
                      _expandedProductIndexes.remove(index);
                    } else {
                      _expandedProductIndexes.add(index);
                    }
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(4.w),
                  child: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColours.primary,
                      size: 28.h,
                    ),
                  ),
                ),
              ),
              if (_enableWorkflow && _journey.requiresConfirmation) ...[
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () {
                    if (index >= _itemChecked.length) return;
                    setState(() => _itemChecked[index] = !_itemChecked[index]);
                  },
                  child: Container(
                    width: 16.w,
                    height: 16.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111217),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFE6C27A),
                        width: 1.6,
                      ),
                    ),
                    child: index < _itemChecked.length && _itemChecked[index]
                        ? const Center(
                            child: Icon(
                              Icons.check,
                              size: 11,
                              color: Color(0xFFE6C27A),
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildExpandedGarmentList(items),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      );
    }

    Widget _buildExpandedGarmentList(List<DpOrderGarment> items) {
      if (items.isEmpty) {
        return Padding(
          padding: EdgeInsets.only(top: 12.h, left: 8.w),
          child: Text(
            'Garment list is not available yet.',
            style: CustomTextStyles.openSansRegular.copyWith(
              fontSize: 12.fSize,
              color: AppColours.hintcolor,
            ),
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.only(top: 12.h),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _buildGarmentRow(items[i], i + 1),
              if (i != items.length - 1) SizedBox(height: 10.h),
            ],
          ],
        ),
      );
    }

    Widget _buildGarmentRow(DpOrderGarment garment, int index) {
      final detail = garment.detailLabel;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColours.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            _buildSingleGarmentImage(garment.imageUrl),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    garment.displayName,
                    style: CustomTextStyles.openSansSemiBold.copyWith(
                      fontSize: 13.fSize,
                      color: AppColours.secondary,
                    ),
                  ),
                  if (detail != null) ...[
                    SizedBox(height: 2.h),
                    Text(
                      detail,
                      style: CustomTextStyles.openSansRegular.copyWith(
                        fontSize: 11.fSize,
                        color: AppColours.hintcolor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '#$index',
              style: CustomTextStyles.openSansRegular.copyWith(
                fontSize: 11.fSize,
                color: AppColours.primary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildSingleGarmentImage(String? imageUrl) {
      return Container(
        width: 40.w,
        height: 40.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF1A1A1F),
          border: Border.all(color: AppColours.primary.withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrl == null || imageUrl.isEmpty
            ? Icon(
                Icons.checkroom_outlined,
                color: AppColours.primary.withValues(alpha: 0.45),
                size: 18.h,
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.checkroom_outlined,
                  color: AppColours.primary.withValues(alpha: 0.45),
                  size: 18.h,
                ),
              ),
      );
    }

    Widget _buildProductImage(List<String> imageUrls) {
      return Container(
        width: 56.w,
        height: 56.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1A1A1F),
          border: Border.all(color: AppColours.primary.withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageUrls.isEmpty
            ? Icon(
                Icons.image_outlined,
                color: AppColours.primary.withValues(alpha: 0.45),
                size: 22.h,
              )
            : imageUrls.length == 1
                ? Image.network(
                    imageUrls.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.image_outlined,
                      color: AppColours.primary.withValues(alpha: 0.45),
                      size: 22.h,
                    ),
                  )
                : GridView.count(
                    crossAxisCount: 2,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    mainAxisSpacing: 1,
                    crossAxisSpacing: 1,
                    children: imageUrls.take(4).map((url) {
                      return Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: const Color(0xFF111217),
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColours.primary.withValues(alpha: 0.35),
                            size: 12.h,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
      );
    }

    Widget _buildDeliveryDetail({
      required dynamic icon,
      required String label,
      required String value,
      dynamic trailingIcon,
      VoidCallback? onTrailingTap,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon is IconData)
            Icon(
              icon,
              color: AppColours.primary,
              size: 22,
            )
          else if (icon is Widget)
            SizedBox(height: 22, width: 22, child: icon)
          else
            const SizedBox(width: 22),

          SizedBox(width: 12.w),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: CustomTextStyles.openSansSemiBold.copyWith(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Colors.white54,
                  ),
                ),

                SizedBox(height: 6.h),

                Text(
                  value,
                  style: CustomTextStyles.openSansRegular.copyWith(
                    fontSize: 15,
                    color: AppColours.secondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 8.w),

          if (trailingIcon != null)
            GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: trailingIcon is IconData
                    ? Icon(
                        trailingIcon,
                        color: AppColours.primary,
                        size: 22,
                      )
                    : trailingIcon is Widget
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: trailingIcon,
                          )
                        : const SizedBox.shrink(),
              ),
            ),
        ],
      );
    }
    Widget _buildInstructions() {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: const Color(0xFF141419),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _instructionsTitle,
              style: CustomTextStyles.openSansSemiBold.copyWith(
                fontSize: 12.fSize,
                color: AppColours.primary,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              _instructionsText,
              style: CustomTextStyles.openSansRegular.copyWith(
                fontSize: 13.fSize,

              ),
            ),
          ],
        ),
      );
    }


    Widget _buildPhotoUploadBox(int index) {
      bool hasImage = _photoProofs[index] != null;

      return GestureDetector(
        onTap: () => _showImageSourceSheet(index),
        child: DottedBorder(
          color: AppColours.primary.withOpacity(0.6),
          strokeWidth: 1.5,
          dashPattern: const [6, 4], // dash length & gap
          borderType: BorderType.RRect,
          radius: const Radius.circular(16),
          child: Container(
            height: 100.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0F14), // dark background like image
              borderRadius: BorderRadius.circular(16),
            ),
            child: hasImage
                ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(_photoProofs[index]!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _photoProofs[index] = null),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
                : Center(
              child: Icon(
                Icons.add,
                color: AppColours.primary.withOpacity(0.6),
                size: 32.h,
              ),
            ),
          ),
        ),
      );
    }
    void _showImageSourceSheet(int index) {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1A1A1F),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => Container(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 24.h),
              Text('Capture or Upload Photo', style: CustomTextStyles.montserratBold.copyWith(fontSize: 16.fSize, color: Colors.white)),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(index, ImageSource.camera);
                      },
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: _buildSourceButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(index, ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      );
    }

    Widget _buildSourceButton({required IconData icon, required String label, required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColours.primary, size: 32.h),
              SizedBox(height: 12.h),
              Text(label, style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 14.fSize, color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    Future<void> _pickImage(int index, ImageSource source) async {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 35,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image != null) {
        setState(() {
          _photoProofs[index] = image.path;
          // Keep item selection in sync when photo proof is added.
          if (_itemChecked.length == 1) {
            _itemChecked[0] = true;
          }
        });
      }
    }

    Widget _buildTotalFare(String fare) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Fare:',
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 18.fSize,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE6C27A).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '₹ $fare',
              style: CustomTextStyles.openSansBold.copyWith(
                fontSize: 16.fSize,
                color: AppColours.primary
              ),
            ),
          ),
        ],
      );
    }

    Widget _buildPrimaryButton(String label, {VoidCallback? onPressed}) {
      return SizedBox(
        width: double.infinity,
        height: 44.h,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColours.primary,
            disabledBackgroundColor: Colors.grey.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            label,
            style: CustomTextStyles.montserratBold.copyWith(
              color: onPressed == null ? Colors.white24 : Colors.black,
              fontSize: 14.fSize,
            ),
          ),
        ),
      );
    }

    Widget _buildSecondaryButton(String label, {VoidCallback? onPressed}) {
      return SizedBox(
        width: double.infinity,
        height: 44.h,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF5E6C8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            label,
            style: CustomTextStyles.montserratBold.copyWith(
              color: Colors.black,
              fontSize: 14.fSize,
            ),
          ),
        ),
      );
    }

    Future<void> _showNotDeliveredDialog(BuildContext context) async {
      final reasonController = TextEditingController();

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColours.primary.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Mark as Not Delivered?',
                    style: CustomTextStyles.montserratBold.copyWith(
                      fontSize: 18.fSize,
                      color: AppColours.primary,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'REASON *',
                  style: CustomTextStyles.montserratBold.copyWith(
                    fontSize: 12.fSize,
                    color: AppColours.primary,
                  ),
                ),
                SizedBox(height: 12.h),
                DottedBorder(
                  color: const Color(0x99E6C27A),
                  strokeWidth: 1.2,
                  dashPattern: const [6, 4],
                  borderType: BorderType.RRect,
                  radius: const Radius.circular(12),
                  child: Container(
                    height: 120.h,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                    ),
                    child: TextField(
                      controller: reasonController,
                      maxLines: 5,
                      style: const TextStyle(
                        color: AppColours.secondary,
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Customer not responding to the calls',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryButton(
                        'Back',
                        onPressed: () => Navigator.pop(dialogContext, false),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildPrimaryButton(
                        'Yes, Confirm',
                        onPressed: () {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a rejection reason.'),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(dialogContext, true);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (confirmed == true && mounted) {
        await _updateStatus(
          status: 'not_delivered',
          rejectReason: reasonController.text.trim(),
        );
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.mainContainer,
            (route) => false,
          );
        }
      }

      reasonController.dispose();
    }

    Future<bool?> _showConfirmReturnDialog(
      BuildContext context, {
      required bool isReturnPickup,
    }) {
      final title = isReturnPickup
          ? 'Confirm Return Pickup'
          : 'Confirm Return Delivery';
      final message = isReturnPickup
          ? 'Have you collected the return package from the customer?'
          : 'Have you delivered the return package to the IAP / warehouse?';

      return showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.7),
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: const Color(0xFF070B14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColours.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: CustomTextStyles.montserratBold.copyWith(
                    fontSize: 16.fSize,
                    color: AppColours.primary,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: CustomTextStyles.openSansRegular.copyWith(
                    fontSize: 13.fSize,
                    color: AppColours.secondary,
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryButton(
                        'Cancel',
                        onPressed: () => Navigator.pop(dialogContext, false),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildPrimaryButton(
                        'Confirm',
                        onPressed: () => Navigator.pop(dialogContext, true),
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

    Future<bool?> _showConfirmPickupOrDeliveryDialog(
      BuildContext context, {
      required bool isPickup,
    }) {
      return showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.7),
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 22.h,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF070B14),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFE6C27A).withOpacity(0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPickup ? 'Confirm Pickup' : 'Confirm Delivery',
                  textAlign: TextAlign.center,
                  style: CustomTextStyles.montserratBold.copyWith(
                    fontSize: 18.fSize,
                    color: AppColours.primary,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 28.h),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF5E6C8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
                    SizedBox(width: 14.w),
                    Expanded(
                      child: SizedBox(
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE6C27A),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
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
  }
