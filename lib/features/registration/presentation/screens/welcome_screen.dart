import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nomoride/core/utils/size_utils.dart';

import '../../../../core/widgets/app_logo.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/theme_helper.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => Navigator.pushNamed(
            context,
            AppRoutes.termsConditionsScreen,
          );
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => Navigator.pushNamed(
            context,
            AppRoutes.privacyPolicyScreen,
          );
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.background,
      body: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 30.w),
        child: Column(
          children: [
            const Spacer(flex: 1),
            AppLogo(width: 220.w),
            SizedBox(height: 48.h),
            Text(
              'Register / Login as a Delivery Partner',
              textAlign: TextAlign.center,
              style: CustomTextStyles.openSansBold.copyWith(
                fontSize: 14.fSize,
              ),
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.registrationScreen),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColours.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'REGISTER',
                  style: CustomTextStyles.montserratBold.copyWith(
                    fontSize: 14.fSize,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: OutlinedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.loginScreen),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0x4DF5E6C8), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'LOGIN',
                  style: CustomTextStyles.montserratBold.copyWith(
                    fontSize: 14.fSize,
                  ),
                ),
              ),
            ),
            SizedBox(height: 122.h),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: CustomTextStyles.openSansRegular.copyWith(fontSize: 12),
                children: [
                  const TextSpan(text: 'By continuing, you agree to our '),
                  TextSpan(
                    text: 'Terms & conditions',
                    style: CustomTextStyles.openSansRegular.copyWith(
                      fontSize: 12,
                      color: AppColours.primary,
                    ),
                    recognizer: _termsRecognizer,
                  ),
                  const TextSpan(text: '\nand '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(color: AppColours.primary),
                    recognizer: _privacyRecognizer,
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }
}
