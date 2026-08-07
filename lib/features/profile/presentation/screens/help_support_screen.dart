import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nomoride/core/utils/size_utils.dart';

import '../../../../core/utils/icon_constant.dart';
import '../../../../theme/theme_helper.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1012),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColours.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Help & Support",
          style: TextStyle(
            color: AppColours.primary,
            fontSize: 18.fSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child:    Container(
            height: 2,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFE6C27A).withOpacity(0.15),
                  Color(0xFFE6C27A),
                  Color(0xFFE6C27A).withOpacity(0.15),
                ],
              ),
            ),
          ),

        ),

      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 154.h),
          child: Column(
            children: [
              Container(
                width: double.maxFinite,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColours.primary,
                      width: 1
                  ),
                ),
                child: Column(
                  children: [
                    SvgPicture.asset(IconConstant.help),

                    SizedBox(height: 12.h),
                    Text(
                      "Help & Support",
                      style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 18),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Container(
                width: double.maxFinite,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 15.h),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColours.primary, width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SvgPicture.asset(IconConstant.phone1),
                        SizedBox(width: 16.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "CONTACT US",
                              style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 16),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              "+91 99999 99999",
                              style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 16),

                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.mail_outline, color: AppColours.primary, size: 24.w),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "EMAIL US",
                                style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 14),

                              ),
                              SizedBox(height: 4.h),
                              Text(
                                "CUSTOMER.SUPPORT@NOMOWEAR.COM",
                                style: CustomTextStyles.montserratSemiBold.copyWith(fontSize: 11),

                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
