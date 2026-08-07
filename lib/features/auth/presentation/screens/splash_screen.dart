import 'package:flutter/material.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/core/services/waitlist_session.dart';
import 'package:nomoride/core/utils/size_utils.dart';
import 'package:nomoride/features/registration/data/models/waitlist_status.dart';
import 'package:nomoride/features/registration/data/models/waitlist_status_model.dart';
import 'package:nomoride/features/registration/data/waitlist_service.dart';
import 'package:nomoride/features/registration/presentation/waitlist_navigation.dart';

import '../../../../core/widgets/app_logo.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/theme_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final WaitlistService _waitlistService = WaitlistService();

  bool _isChecking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final splashDelay = Future.delayed(const Duration(seconds: 3));

    // Ensure SharedPreferences values are loaded before any routing decision.
    await WaitlistSession.restore();

    final referenceId = WaitlistSession.referenceId?.trim();
    final waitlistNumber = WaitlistSession.waitlistNumber;
    final mobileNumber = WaitlistSession.mobileNumber;

    debugPrint('========== SPLASH ==========');
    debugPrint('reference_id: $referenceId');
    debugPrint('waitlist_number: $waitlistNumber');
    debugPrint('mobile_number: $mobileNumber');
    if (referenceId != null && referenceId.isNotEmpty) {
      debugPrint('Calling:');
      debugPrint('GET /waitlist/status/$referenceId');
    } else {
      debugPrint('Calling: (skipped — no reference_id)');
    }
    debugPrint('============================');

    if (AuthSession.isLoggedIn) {
      await splashDelay;
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.mainContainer);
      return;
    }

    if (referenceId == null || referenceId.isEmpty) {
      await splashDelay;
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.welcomeScreen);
      return;
    }

    if (mounted) {
      setState(() {
        _isChecking = true;
        _errorMessage = null;
      });
    }

    try {
      final model = await _waitlistService.getStatus(referenceId);
      await splashDelay;

      if (!mounted) return;
      await _navigateForModel(model);
    } on ApiException catch (error) {
      await splashDelay;
      if (!mounted) return;

      if (_isRecordNotFound(error.message)) {
        Navigator.pushReplacementNamed(context, AppRoutes.welcomeScreen);
        return;
      }

      setState(() {
        _isChecking = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      await splashDelay;
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  bool _isRecordNotFound(String message) {
    final lower = message.toLowerCase();
    return lower.contains('not found') || lower.contains('no waitlist');
  }

  Future<void> _navigateForModel(WaitlistStatusModel model) async {
    // Keep existing reference_id if status response omits it.
    await WaitlistSession.saveFromRegistrationResponse(
      referenceId: model.referenceId ?? WaitlistSession.referenceId,
      waitlistNumber: model.waitlistNumber ?? WaitlistSession.waitlistNumber,
      mobileNumber: model.mobileNumber ?? WaitlistSession.mobileNumber,
    );
    if (model.status == WaitlistStatus.rejected) {
      await WaitlistSession.saveFromApiFormData(model.formData);
    }

    if (!mounted) return;

    final route = WaitlistNavigation.routeForStatus(model);
    final arguments = WaitlistNavigation.argumentsForStatus(model);

    Navigator.pushReplacementNamed(
      context,
      route,
      arguments: arguments,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.black,
      body: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLogo(width: 220.w),
            if (_isChecking) ...[
              SizedBox(height: 32.h),
              const CircularProgressIndicator(color: AppColours.primary),
            ],
            if (_errorMessage != null) ...[
              SizedBox(height: 24.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: CustomTextStyles.openSansSemiBold.copyWith(
                    fontSize: 12,
                    color: AppColours.secondary,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: _bootstrap,
                child: Text(
                  'RETRY',
                  style: CustomTextStyles.montserratBold.copyWith(
                    fontSize: 14,
                    color: AppColours.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  ThemeData get theme => ThemeHelper.themeDataData;
}
