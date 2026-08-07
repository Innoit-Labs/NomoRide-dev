import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:nomoride/core/utils/size_utils.dart';

import '../../../../core/utils/icon_constant.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/theme_helper.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({Key? key}) : super(key: key);

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Auto navigate to home after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.mainContainer,
          (route) => false,
        );
      }
    });


  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // 🔥 LOGO (bigger like design)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: child,
                  ),
                );
              },
              child: AppLogo(width: 200.w),
            ),

            const SizedBox(height: 50),

            // 🔥 SUCCESS CONTAINER with Blinking effect
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 15.h,
                      horizontal: 20.w,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6C279).withOpacity(0.1),

                      border: Border.all(
                        color: AppColours.primary.withOpacity(_pulseAnimation.value),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColours.primary.withOpacity(0.15 * _pulseAnimation.value),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: child,
                  ),
                );
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  // ✅ ICON with Pulse

                  SvgPicture.asset(IconConstant.success,width: 24,height: 24,),
                  SizedBox(width: 24,),

                  // ✅ TEXT
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "OTP Verified successfully",
                        style: CustomTextStyles.montserratBold.copyWith(color: AppColours.primary,fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Welcome to NomoRide",
                        style: CustomTextStyles.montserratBold.copyWith(color: AppColours.primary,fontSize: 14),

                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}