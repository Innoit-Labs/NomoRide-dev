import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nomoride/core/utils/size_utils.dart';

import '../../../../core/utils/icon_constant.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/theme_helper.dart';


class RejectedScreen extends StatefulWidget {
  final List<String> reasons;
  final bool restoreDraft;

  const RejectedScreen({
    super.key,
    this.reasons = const ['Aadhar Verification Failed'],
    this.restoreDraft = false,
  });

  @override
  State<RejectedScreen> createState() => _RejectedScreenState();
}

class _RejectedScreenState extends State<RejectedScreen> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColours.border1, width: 1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     SvgPicture.asset(IconConstant.close),
                    SizedBox(height: 24.h),
                    Text(
                      'SUBMISSION REQUEST REJECTED',
                      textAlign: TextAlign.center,
                      style: CustomTextStyles.montserratBold.copyWith(fontSize: 14,color: AppColours.primary),


                    ),
                    SizedBox(height: 12.h),
                     Text(
                      'Your Verification Request Has Been Failed. Please Re Upload Documents',
                      textAlign: TextAlign.center,
                      style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 12),


                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.registrationScreen,
                            (route) => false,
                            arguments: const {'restoreDraft': true},
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6C27A), // 🔥 gold
                          foregroundColor: Colors.black,           // 🔥 black text
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // 🔥 rounded
                          ),
                        ),
                        child: Text(
                          'RE-UPLOAD DOCUMENTS',
                          style: CustomTextStyles.montserratBold.copyWith(
                            color: Colors.black,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              _buildReasonDropdown(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonDropdown() {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reason for Rejection',
                  style: CustomTextStyles.montserratBold.copyWith(
                    color: AppColours.primary,
                    fontSize: 14,
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColours.primary,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded)
          Column(
            children: widget.reasons.map((reason) => _buildReasonItem(reason)).toList(),
          ),
      ],
    );
  }

  Widget _buildReasonItem(String reason) {
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColours.border1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            IconConstant.close1,
            width: 16.w,
            height: 16.h,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              reason,
              style: CustomTextStyles.openSansSemiBold.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
