import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/core/services/waitlist_session.dart';
import 'package:nomoride/core/utils/icon_constant.dart';
import 'package:nomoride/features/profile/data/models/delivery_partner_profile.dart';
import 'package:nomoride/features/profile/data/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../theme/theme_helper.dart';
import '../../../../core/utils/size_utils.dart';
import '../../../../routes/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();

  bool _isLoading = true;
  String? _errorMessage;
  DeliveryPartnerProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _repository.getProfile(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            error is ApiException ? error.message : error.toString();
        _profile = ProfileRepository.cachedProfile;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _displayName {
    final name = _profile?.fullName.trim();
    if (name != null && name.isNotEmpty) return name;
    return AuthSession.mobileNumber ?? 'Partner';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Profile',
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
          RefreshIndicator(
            color: AppColours.primary,
            onRefresh: () => _loadProfile(forceRefresh: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
              child: Column(
                children: [
                  SizedBox(height: 16.h),
                  if (_errorMessage != null && _profile == null)
                    _buildErrorBanner()
                  else
                    _buildProfileHeader(),
                  SizedBox(height: 16.h),
                  _buildProfileItem(
                    context,
                    IconConstant.edit1,
                    'Edit Profile',
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        AppRoutes.editProfileScreen,
                      );
                      if (mounted) _loadProfile(forceRefresh: true);
                    },
                  ),
                  _buildProfileItem(
                    context,
                    IconConstant.bankAccountUpi,
                    'Bank Account / UPI',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.bankAccountScreen),
                  ),
                  _buildProfileItem(
                    context,
                    IconConstant.myEarnings,
                    'My Earnings',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.earningsScreen),
                  ),
                  _buildProfileItem(
                    context,
                    IconConstant.iconMyOrders,
                    'My orders',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.ordersScreen),
                  ),
                  _buildProfileItem(
                    context,
                    IconConstant.iconAboutUs,
                    'About us',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.aboutUsScreen),
                  ),
                  _buildProfileItem(
                    context,
                    IconConstant.iconHelpSupport,
                    'Help & Support',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.helpSupportScreen),
                  ),
                  _buildProfileItem(
                    context,
                    IconConstant.iconPrivacyPolicy,
                    'Privacy Policy',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.privacyPolicyScreen,
                    ),
                  ),
                  _buildProfileItem(
                    context,
                    IconConstant.iconTermsConditions,
                    'Terms & conditions',
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.termsConditionsScreen,
                    ),
                  ),
                  _buildProfileItem(
                    context,
                    IconConstant.delete,
                    'Delete Account',
                    onTap: () => _showDeleteAccountDialog(context),
                  ),
                  SizedBox(height: 58.h),
                  _buildLogoutButton(context),
                  SizedBox(height: 100.h),
                ],
              ),
            ),
          ),
          if (_isLoading)
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

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            _errorMessage ?? 'Failed to load profile.',
            textAlign: TextAlign.center,
            style: CustomTextStyles.openSansRegular.copyWith(
              color: AppColours.secondary,
            ),
          ),
          SizedBox(height: 12.h),
          TextButton(
            onPressed: () => _loadProfile(forceRefresh: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final photoUrl = _profile?.profilePhotoUrl?.trim();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 15.h),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColours.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColours.primary, width: 1.5),
            ),
            child: CircleAvatar(
              radius: 60.w,
              backgroundColor: Colors.white12,
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? const Icon(Icons.person, size: 48, color: Colors.white24)
                  : null,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            _displayName,
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 22.fSize,
            ),
          ),
          // if ((_profile?.mobileNumber ?? '').isNotEmpty) ...[
          //   SizedBox(height: 8.h),
          //   Text(
          //     _profile!.mobileNumber,
          //     style: CustomTextStyles.openSansRegular.copyWith(
          //       fontSize: 14.fSize,
          //       color: AppColours.hintcolor,
          //     ),
          //   ),
          // ],
        ],
      ),
    );
  }

  Widget _buildProfileItem(
    BuildContext context,
    String iconPath,
    String label, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColours.primary),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              height: 24.h,
              width: 24.h,
              colorFilter: const ColorFilter.mode(
                AppColours.primary,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 16.w),
            Text(
              label,
              style: CustomTextStyles.openSansSemiBold.copyWith(
                fontSize: 14.fSize,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: AppColours.primary, size: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 30.0, right: 30),
      child: SizedBox(
        width: double.infinity,
        height: 56.h,
        child: OutlinedButton(
          onPressed: () => _showLogoutDialog(context),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColours.primary.withValues(alpha: 0.1),
            side: const BorderSide(color: AppColours.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                IconConstant.iconLogout,
                height: 20.h,
                width: 20.w,
                colorFilter: const ColorFilter.mode(
                  AppColours.primary,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                'LOGOUT',
                style: CustomTextStyles.montserratBold.copyWith(
                  color: AppColours.primary,
                  fontSize: 14.fSize,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _buildStyledDialog(
        dialogContext,
        icon: SvgPicture.asset(
          IconConstant.delete,
          height: 24.h,
          width: 24.w,
          colorFilter: const ColorFilter.mode(
            Color(0xFFE6C279),
            BlendMode.srcIn,
          ),
        ),
        title: 'Are you sure you want Delete Account',
        onConfirm: () async {
          Navigator.pop(dialogContext);
          await _deleteAccount(context);
        },
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColours.primary),
      ),
    );

    try {
      await _repository.deleteAccount();
      await _clearAllLocalData();

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.welcomeScreen,
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (error.statusCode == 401) {
        await _clearAllLocalData();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.red.shade800,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.loginScreen,
          (route) => false,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Something went wrong. Please try again.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _clearAllLocalData() async {
    await AuthSession.clear();
    await WaitlistSession.clear();
    ProfileRepository.clearCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    AuthSession.authToken = null;
    AuthSession.partnerId = null;
    AuthSession.mobileNumber = null;
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _buildStyledDialog(
        context,
        icon: SvgPicture.asset(
          IconConstant.iconLogout,
          height: 24.h,
          width: 24.w,
          colorFilter: const ColorFilter.mode(
            Color(0xFFE6C279),
            BlendMode.srcIn,
          ),
        ),
        title: 'Are you sure you want to Logout?',
        onConfirm: () async {
          await AuthSession.clear();
          ProfileRepository.clearCache();
          if (!context.mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.loginScreen,
            (route) => false,
          );
        },
      ),
    );
  }

  Widget _buildStyledDialog(
    BuildContext context, {
    required Widget icon,
    required String title,
    required VoidCallback onConfirm,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 18.w),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 18.w,
          vertical: 28.h,
        ),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFE6C279).withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24.h,
              width: 24.w,
              child: icon,
            ),
            SizedBox(height: 14.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE6C279),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 46.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E4BF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onConfirm,
                    child: Container(
                      height: 46.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6C279),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Yes, Confirm',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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
    );
  }
}
