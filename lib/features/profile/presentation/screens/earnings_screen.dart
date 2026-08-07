import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/utils/icon_constant.dart';
import 'package:nomoride/features/profile/data/earnings_repository.dart';
import 'package:nomoride/features/profile/data/models/delivery_partner_profile.dart';
import 'package:nomoride/features/profile/data/models/earning_order.dart';
import 'package:nomoride/features/profile/data/models/earnings_data.dart';
import 'package:nomoride/features/profile/data/profile_repository.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/theme_helper.dart';
import '../../../../core/utils/size_utils.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final EarningsRepository _repository = EarningsRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  String _activeTab = 'All';
  bool _isLoading = true;
  bool _isSubmittingWithdrawal = false;
  bool _isCheckingPaymentDetails = false;
  String? _errorMessage;
  EarningsData? _earnings;
  final Set<String> _selectedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadEarnings();
  }

  Future<void> _loadEarnings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dataFuture = _repository.getEarnings();
      final profileFuture = _profileRepository.getProfile().then(
        (_) {},
        onError: (_) {},
      );
      final data = await dataFuture;
      await profileFuture;
      if (!mounted) return;
      setState(() {
        _earnings = data;
        _selectedOrderIds.removeWhere(
          (id) => !data.orders.any((order) => order.id == id),
        );
      });
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

  List<EarningOrder> get _filteredOrders {
    final orders = _earnings?.orders ?? [];
    switch (_activeTab) {
      case 'Pending':
        return orders.where((order) => order.isPaymentPending).toList();
      case 'Completed':
        return orders.where((order) => order.isPaymentCompleted).toList();
      default:
        return orders;
    }
  }

  List<EarningOrder> get _pendingOrders {
    return (_earnings?.orders ?? [])
        .where((order) => order.isPaymentPending)
        .toList();
  }

  bool get _isSelectAll {
    final pending = _pendingOrders;
    if (pending.isEmpty) return false;
    return pending.every((order) => _selectedOrderIds.contains(order.id));
  }

  bool get _canWithdraw => _selectedOrderIds.isNotEmpty;

  double get _selectedAmount {
    final orders = _earnings?.orders ?? [];
    return orders
        .where((order) => _selectedOrderIds.contains(order.id))
        .fold<double>(0, (sum, order) => sum + order.partnerEarning);
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isSelectAll) {
        _selectedOrderIds.clear();
      } else {
        _selectedOrderIds
          ..clear()
          ..addAll(_pendingOrders.map((order) => order.id));
      }
    });
  }

  void _toggleOrder(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColours.primary),
          onPressed: _isSubmittingWithdrawal ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Earnings',
          style: CustomTextStyles.montserratBold.copyWith(
            color: AppColours.primary,
            fontSize: 16.fSize,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
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
              Expanded(
                child: _errorMessage != null && _earnings == null
                    ? _buildErrorState()
                    : RefreshIndicator(
                        color: AppColours.primary,
                        onRefresh: _loadEarnings,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(24.w),
                          child: Column(
                            children: [
                              _buildTotalEarningsCard(),
                              SizedBox(height: 16.h),
                              _buildSubStatsRow(),
                              SizedBox(height: 32.h),
                              _buildFilterTabs(),
                              SizedBox(height: 24.h),
                              if (_activeTab == 'Pending') _buildSelectAllRow(),
                              _buildOrderList(),
                            ],
                          ),
                        ),
                      ),
              ),
              _buildWithdrawButton(),
            ],
          ),
          if (_isLoading || _isSubmittingWithdrawal || _isCheckingPaymentDetails)
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage ?? 'Failed to load earnings.',
              textAlign: TextAlign.center,
              style: CustomTextStyles.openSansRegular.copyWith(
                color: AppColours.secondary,
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadEarnings,
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

  Widget _buildTotalEarningsCard() {
    final total = _earnings?.totalEarnings ?? 0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 24.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColours.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            'Total Earnings',
            style: CustomTextStyles.openSansBold.copyWith(
              fontSize: 16.fSize,
              color: AppColours.primary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '₹${_formatAmount(total)}',
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 36.fSize,
              color: AppColours.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildSubStatCard(
            'Paid out',
            '₹${_formatAmount(_earnings?.paidOut ?? 0)}',
            IconConstant.payOut,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: _buildSubStatCard(
            'Pending',
            '₹${_formatAmount(_earnings?.pending ?? 0)}',
            IconConstant.pending,
          ),
        ),
      ],
    );
  }

  Widget _buildSubStatCard(String label, String amount, String iconPath) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColours.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                iconPath,
                height: 20,
                width: 20,
                colorFilter: const ColorFilter.mode(
                  AppColours.primary,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                label,
                style: CustomTextStyles.openSansSemiBold.copyWith(
                  fontSize: 14.fSize,
                  color: AppColours.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            amount,
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 24.fSize,
              color: AppColours.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildTabItem('All'),
        _buildTabItem('Pending'),
        _buildTabItem('Completed'),
      ],
    );
  }

  Widget _buildTabItem(String label) {
    final isActive = _activeTab == label;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isActive ? AppColours.primary : const Color(0x40E6C27A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: CustomTextStyles.openSansBold.copyWith(
            fontSize: 12.fSize,
            color: isActive ? Colors.black : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectAllRow() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Select all',
            style: CustomTextStyles.openSansSemiBold.copyWith(
              fontSize: 12.fSize,
              color: AppColours.primary,
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: _toggleSelectAll,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                border: Border.all(color: AppColours.primary, width: 1.5),
                borderRadius: BorderRadius.circular(4),
                color: _isSelectAll ? AppColours.primary : Colors.transparent,
              ),
              child: _isSelectAll
                  ? const Icon(Icons.check, size: 12, color: Colors.black)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    final orders = _filteredOrders;

    if (orders.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 32.h),
        child: Text(
          'No orders found.',
          style: CustomTextStyles.openSansRegular.copyWith(
            color: AppColours.hintcolor,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      separatorBuilder: (context, index) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        final order = orders[index];
        final showCheckbox =
            _activeTab == 'Pending' && order.isPaymentPending;
        return _buildOrderCard(order, showCheckbox);
      },
    );
  }

  Widget _buildOrderCard(EarningOrder order, bool showCheckbox) {
    final status = order.displayPaymentStatus;
    final statusColor = order.isPaymentCompleted
        ? Colors.green
        : const Color(0xFFE7A938);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
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
              Row(
                children: [
                  if (ProfileRepository.showsPartnerEarning)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x40E6C27A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '₹ ${_formatAmount(order.partnerEarning)}',
                        style: CustomTextStyles.openSansBold.copyWith(
                          fontSize: 12.fSize,
                          color: AppColours.primary,
                        ),
                      ),
                    ),
                  if (showCheckbox) ...[
                    if (ProfileRepository.showsPartnerEarning)
                      SizedBox(width: 12.w),
                    GestureDetector(
                      onTap: () => _toggleOrder(order.id),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColours.primary,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          color: _selectedOrderIds.contains(order.id)
                              ? AppColours.primary
                              : Colors.transparent,
                        ),
                        child: _selectedOrderIds.contains(order.id)
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.black,
                              )
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Order Type: ${order.displayOrderType}',
            style: CustomTextStyles.openSansSemiBold.copyWith(
              fontSize: 13.fSize,
            ),
          ),
          const Divider(color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Date: ${order.formattedDate}',
                  style: CustomTextStyles.openSansRegular.copyWith(
                    fontSize: 10.fSize,
                  ),
                ),
              ),
              Text(
                status,
                style: CustomTextStyles.openSansBold.copyWith(
                  fontSize: 11.fSize,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawButton() {
    final isWithdrawEnabled = _activeTab == 'All' || _activeTab == 'Pending';
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
      child: SizedBox(
        width: double.infinity,
        height: 56.h,
        child: ElevatedButton(
          onPressed: isWithdrawEnabled && !_isSubmittingWithdrawal
              ? _handleWithdrawPressed
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColours.primary,
            disabledBackgroundColor: const Color(0xFF6E5F3D).withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            'Withdraw',
            style: CustomTextStyles.montserratBold.copyWith(
              color: isWithdrawEnabled ? Colors.black : Colors.white24,
              fontSize: 16.fSize,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleWithdrawPressed() async {
    if (_activeTab == 'All') {
      setState(() => _activeTab = 'Pending');
      return;
    }

    if (!_canWithdraw) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one order')),
      );
      return;
    }

    setState(() => _isCheckingPaymentDetails = true);
    DeliveryPartnerProfile? profile;
    try {
      profile = await _profileRepository.getProfile();
      if (!mounted) return;

      if (!profile.hasPaymentDetails) {
        final configured = await Navigator.pushNamed(
          context,
          AppRoutes.bankAccountScreen,
          arguments: const {'forWithdrawSetup': true},
        );
        if (configured != true || !mounted) return;

        profile = await _profileRepository.getProfile();
        if (!mounted) return;
        if (!profile.hasPaymentDetails) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please add bank account or UPI details to withdraw.'),
            ),
          );
          return;
        }
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
      return;
    } finally {
      if (mounted) setState(() => _isCheckingPaymentDetails = false);
    }

    if (!mounted) return;

    final paymentProfile = profile;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final result = await showDialog<_WithdrawFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WithdrawDialog(
        profile: paymentProfile,
        initialAmount: _formatAmount(_selectedAmount),
      ),
    );

    if (result == null || !mounted) return;
    await _submitWithdrawal(result, paymentProfile);
  }

  Future<void> _submitWithdrawal(
    _WithdrawFormResult result,
    DeliveryPartnerProfile profile,
  ) async {
    setState(() => _isSubmittingWithdrawal = true);
    try {
      await _repository.createWithdrawalRequest(
        amount: result.amount,
        payTo: result.payTo,
        notes: result.notes,
        upiId: result.payTo == 'upi' ? profile.upiId?.trim() : null,
        bankAccountNumber:
            result.payTo == 'bank' ? profile.bankAccountNumber?.trim() : null,
        bankIfsc: result.payTo == 'bank' ? profile.bankIfsc?.trim() : null,
        bankAccountName:
            result.payTo == 'bank' ? profile.bankAccountName?.trim() : null,
      );

      if (!mounted) return;
      setState(() {
        _selectedOrderIds.clear();
        _activeTab = 'All';
      });
      await _loadEarnings();
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _showSuccessDialog();
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
      if (mounted) setState(() => _isSubmittingWithdrawal = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(const Duration(seconds: 3), () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        });

        return Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: AppColours.black,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(IconConstant.success1),
              SizedBox(height: 12.h),
              Text(
                'WITHDRAW REQUEST SUCCESS!',
                textAlign: TextAlign.center,
                style: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 18.fSize,
                  letterSpacing: 1,
                  color: AppColours.secondary,
                ),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                child: Text(
                  'Your withdrawal request has been submitted successfully. Our team will contact you shortly.',
                  textAlign: TextAlign.center,
                  style: CustomTextStyles.openSansRegular.copyWith(
                    fontSize: 13.fSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      },
    );
  }
}

class _WithdrawFormResult {
  const _WithdrawFormResult({
    required this.amount,
    required this.payTo,
    this.notes,
  });

  final double amount;
  final String payTo;
  final String? notes;
}

class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog({
    required this.profile,
    required this.initialAmount,
  });

  final DeliveryPartnerProfile profile;
  final String initialAmount;

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late String _payTo;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.initialAmount);
    _notesController = TextEditingController();
    _payTo = widget.profile.hasUpiDetails ? 'upi' : 'bank';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Enter a valid amount.');
      return;
    }
    if (_payTo == 'upi' && !widget.profile.hasUpiDetails) {
      setState(() => _errorMessage = 'UPI details not configured.');
      return;
    }
    if (_payTo == 'bank' && !widget.profile.hasBankDetails) {
      setState(() => _errorMessage = 'Bank details not configured.');
      return;
    }

    final notes = _notesController.text.trim();
    Navigator.of(context).pop(
      _WithdrawFormResult(
        amount: amount,
        payTo: _payTo,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;

    return Dialog(
      backgroundColor: const Color(0xFF0F0F14),
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Withdraw Earnings',
                style: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 16.fSize,
                  color: AppColours.primary,
                ),
              ),
            ),
            SizedBox(height: 20.h),
            _buildField(
              'Amount *',
              _amountController,
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 12.h),
            Text(
              'Pay to *',
              style: CustomTextStyles.montserratBold.copyWith(
                fontSize: 12.fSize,
                color: AppColours.primary,
              ),
            ),
            SizedBox(height: 8.h),
            if (profile.hasUpiDetails && profile.hasBankDetails)
              Row(
                children: [
                  Expanded(
                    child: _buildPayToChip(
                      label: 'UPI',
                      selected: _payTo == 'upi',
                      onTap: () => setState(() {
                        _payTo = 'upi';
                        _errorMessage = null;
                      }),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildPayToChip(
                      label: 'Bank',
                      selected: _payTo == 'bank',
                      onTap: () => setState(() {
                        _payTo = 'bank';
                        _errorMessage = null;
                      }),
                    ),
                  ),
                ],
              ),
            SizedBox(height: 12.h),
            _buildPaymentSummary(profile, _payTo),
            SizedBox(height: 12.h),
            _buildField('Notes', _notesController, maxLines: 3),
            if (_errorMessage != null) ...[
              SizedBox(height: 12.h),
              Text(
                _errorMessage!,
                style: CustomTextStyles.openSansRegular.copyWith(
                  color: Colors.red.shade300,
                  fontSize: 12.fSize,
                ),
              ),
            ],
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5E6C8),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Back'),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColours.primary,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: CustomTextStyles.montserratBold.copyWith(
            fontSize: 11.fSize,
            color: AppColours.primary,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: AppColours.secondary),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1A1F),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColours.primary.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColours.primary.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColours.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPayToChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: selected ? AppColours.primary : const Color(0xFF1A1A1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColours.primary.withValues(alpha: 0.4)),
        ),
        child: Center(
          child: Text(
            label,
            style: CustomTextStyles.montserratBold.copyWith(
              color: selected ? Colors.black : AppColours.secondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSummary(DeliveryPartnerProfile profile, String payTo) {
    final String summary;
    if (payTo == 'upi') {
      summary = profile.upiId ?? '';
    } else {
      final accountNumber = profile.bankAccountNumber ?? '';
      final maskedAccount = accountNumber.length > 4
          ? '****${accountNumber.substring(accountNumber.length - 4)}'
          : accountNumber;
      summary =
          '${profile.bankAccountName ?? ''} · $maskedAccount · ${profile.bankIfsc ?? ''}';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColours.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        summary,
        style: CustomTextStyles.openSansRegular.copyWith(
          color: AppColours.secondary,
          fontSize: 13.fSize,
        ),
      ),
    );
  }
}
