import 'package:flutter/material.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/utils/size_utils.dart';
import 'package:nomoride/features/profile/data/profile_repository.dart';
import '../../../../theme/theme_helper.dart';

class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({
    super.key,
    this.forWithdrawSetup = false,
  });

  final bool forWithdrawSetup;

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen>
    with SingleTickerProviderStateMixin {
  final ProfileRepository _repository = ProfileRepository();
  late final TabController _tabController;

  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _upiController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasBankDetails = false;
  bool _hasUpiId = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _repository.getProfile();
      if (!mounted) return;
      setState(() {
        _accountNameController.text = profile.bankAccountName ?? '';
        _accountNumberController.text = profile.bankAccountNumber ?? '';
        _ifscController.text = profile.bankIfsc ?? '';
        _upiController.text = profile.upiId ?? '';
        _hasBankDetails = _bankDetailsExist(
          profile.bankAccountName,
          profile.bankAccountNumber,
          profile.bankIfsc,
        );
        _hasUpiId = (profile.upiId ?? '').trim().isNotEmpty;
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

  Future<void> _saveBankDetails() async {
    final accountName = _accountNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final ifsc = _ifscController.text.trim();

    if (accountName.isEmpty || accountNumber.isEmpty || ifsc.isEmpty) {
      _showMessage('Please fill all bank account fields.');
      return;
    }

    await _save(
      {
        'bank_account_name': accountName,
        'bankAccountName': accountName,
        'bank_account_number': accountNumber,
        'bankAccountNumber': accountNumber,
        'bank_ifsc': ifsc.toUpperCase(),
        'bankIfsc': ifsc.toUpperCase(),
      },
      successMessage: _hasBankDetails
          ? 'Bank account details updated.'
          : 'Bank account details saved.',
    );
  }

  Future<void> _saveUpiDetails() async {
    final upiId = _upiController.text.trim();
    if (upiId.isEmpty) {
      _showMessage('Please enter your UPI ID.');
      return;
    }

    await _save(
      {
        'upi_id': upiId,
        'upiId': upiId,
      },
      successMessage:
          _hasUpiId ? 'UPI ID updated.' : 'UPI ID saved.',
    );
  }

  bool _bankDetailsExist(String? name, String? number, String? ifsc) {
    return (name ?? '').trim().isNotEmpty &&
        (number ?? '').trim().isNotEmpty &&
        (ifsc ?? '').trim().isNotEmpty;
  }

  Future<void> _save(
    Map<String, dynamic> payload, {
    required String successMessage,
  }) async {
    setState(() => _isSaving = true);
    try {
      final profile = await _repository.updateBankAccountDetails(payload);
      if (!mounted) return;
      final shouldReturnForWithdraw =
          widget.forWithdrawSetup && profile.hasPaymentDetails;

      setState(() {
        _accountNameController.text = profile.bankAccountName ?? '';
        _accountNumberController.text = profile.bankAccountNumber ?? '';
        _ifscController.text = profile.bankIfsc ?? '';
        _upiController.text = profile.upiId ?? '';
        _hasBankDetails = _bankDetailsExist(
          profile.bankAccountName,
          profile.bankAccountNumber,
          profile.bankIfsc,
        );
        _hasUpiId = (profile.upiId ?? '').trim().isNotEmpty;
        if (shouldReturnForWithdraw) {
          _isSaving = false;
        }
      });

      if (shouldReturnForWithdraw) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context).pop(true);
          }
        });
        return;
      }

      _showMessage(successMessage, isError: false);
    } catch (error) {
      if (!mounted) return;
      final message =
          error is ApiException ? error.message : error.toString();
      _showMessage(message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
      ),
    );
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
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          widget.forWithdrawSetup ? 'Add Payment Details' : 'Payment Details',
          style: CustomTextStyles.montserratBold.copyWith(
            color: AppColours.primary,
            fontSize: 16.fSize,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.h),
          child: Column(
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
              TabBar(
                controller: _tabController,
                indicatorColor: AppColours.primary,
                labelColor: AppColours.primary,
                unselectedLabelColor: Colors.white54,
                labelStyle: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 13.fSize,
                ),
                unselectedLabelStyle:
                    CustomTextStyles.openSansSemiBold.copyWith(
                  fontSize: 13.fSize,
                ),
                tabs: const [
                  Tab(text: 'Bank Account'),
                  Tab(text: 'UPI ID'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_errorMessage != null && !_isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: CustomTextStyles.openSansRegular.copyWith(
                        color: AppColours.secondary,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: _loadDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColours.primary,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            TabBarView(
              controller: _tabController,
              children: [
                _buildBankTab(),
                _buildUpiTab(),
              ],
            ),
          if (_isLoading || _isSaving)
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

  Widget _buildBankTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _hasBankDetails
                ? 'Update your bank account for withdrawals.'
                : 'Add your bank account for withdrawals.',
            style: CustomTextStyles.openSansRegular.copyWith(
              fontSize: 13.fSize,
              color: AppColours.hintcolor,
            ),
          ),
          SizedBox(height: 24.h),
          _buildField(
            label: 'ACCOUNT HOLDER NAME *',
            controller: _accountNameController,
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: 20.h),
          _buildField(
            label: 'ACCOUNT NUMBER *',
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 20.h),
          _buildField(
            label: 'IFSC CODE *',
            controller: _ifscController,
            textCapitalization: TextCapitalization.characters,
          ),
          SizedBox(height: 40.h),
          _buildSaveButton(
            _hasBankDetails ? 'Update Bank Details' : 'Save Bank Details',
            _saveBankDetails,
            isUpdating: _hasBankDetails,
          ),
        ],
      ),
    );
  }

  Widget _buildUpiTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _hasUpiId
                ? 'Update your UPI ID for quick withdrawals.'
                : 'Add your UPI ID for quick withdrawals.',
            style: CustomTextStyles.openSansRegular.copyWith(
              fontSize: 13.fSize,
              color: AppColours.hintcolor,
            ),
          ),
          SizedBox(height: 24.h),
          _buildField(
            label: 'UPI ID *',
            controller: _upiController,
            hint: 'example@upi',
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 40.h),
          _buildSaveButton(
            _hasUpiId ? 'Update UPI ID' : 'Save UPI ID',
            _saveUpiDetails,
            isUpdating: _hasUpiId,
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CustomTextStyles.montserratBold.copyWith(
            fontSize: 12.fSize,
            color: AppColours.primary,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: const TextStyle(color: AppColours.secondary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColours.hintcolor, fontSize: 14.fSize),
            filled: true,
            fillColor: const Color(0xFF1A1A1F),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColours.border1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColours.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(
    String label,
    VoidCallback onPressed, {
    bool isUpdating = false,
  }) {
    final loadingLabel = isUpdating ? 'Updating...' : 'Saving...';
    return SizedBox(
      height: 52.h,
      child: ElevatedButton(
        onPressed: _isSaving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColours.primary,
          disabledBackgroundColor: Colors.grey,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          _isSaving ? loadingLabel : label,
          style: CustomTextStyles.montserratBold.copyWith(
            fontSize: 14.fSize,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
