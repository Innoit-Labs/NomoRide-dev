import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nomoride/core/utils/icon_constant.dart';
import '../../../../theme/theme_helper.dart';
import '../../../../routes/app_routes.dart';
import '../../../../core/utils/size_utils.dart';

class DeliverySuccessScreen extends StatefulWidget {
  const DeliverySuccessScreen({super.key});

  @override
  State<DeliverySuccessScreen> createState() => _DeliverySuccessScreenState();
}

class _DeliverySuccessScreenState extends State<DeliverySuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPickup = false;
  bool _isReturn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _isPickup = args['isPickup'] == true;
      _isReturn = args['isReturn'] == true;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isReturn
        ? 'RETURN SUCCESS!'
        : (_isPickup ? 'PICKUP SUCCESS!' : 'DELIVERY SUCCESS!');
    final subtitle = _isReturn
        ? 'Return has been completed successfully!'
        : (_isPickup
            ? 'Order has been picked up successfully!'
            : 'Order has been delivered successfully!');

    return Scaffold(
      backgroundColor: AppColours.black,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: SvgPicture.asset(IconConstant.success1),
              ),
              SizedBox(height: 12.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 22.fSize,
                  letterSpacing: 2,
                  color: AppColours.secondary,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: CustomTextStyles.openSansRegular.copyWith(
                  fontSize: 14.fSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
