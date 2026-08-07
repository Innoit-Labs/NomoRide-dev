import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nomoride/core/utils/size_utils.dart';
import 'package:nomoride/features/registration/data/models/waitlist_status.dart';
import 'package:nomoride/features/registration/presentation/bloc/waitlist_cubit.dart';
import 'package:nomoride/features/registration/presentation/bloc/waitlist_state.dart';
import 'package:nomoride/features/registration/presentation/waitlist_navigation.dart';
import 'package:nomoride/features/registration/presentation/waitlist_refresh.dart';

import '../../../../core/utils/icon_constant.dart';
import '../../../../theme/theme_helper.dart';
import '../../../../routes/app_routes.dart';

class SuccessScreen extends StatefulWidget {
  const SuccessScreen({
    super.key,
    this.waitlisted = false,
    this.underReview = false,
    this.fromWaitlistCheck = false,
    this.message,
    this.waitlistNumber,
    this.referenceId,
  });

  final bool waitlisted;
  final bool underReview;
  final bool fromWaitlistCheck;
  final String? message;
  final String? waitlistNumber;
  final String? referenceId;

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen> {
  @override
  void initState() {
    super.initState();

    // Added to Waitlist → after a short delay, go to Documents Under Review
    // and remain there (do not go to Register/Login).
    if (widget.waitlisted) {
      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.registrationSuccessScreen,
          (route) => false,
          arguments: {
            'waitlisted': false,
            'underReview': true,
            'fromWaitlistCheck': true,
            'message':
                'Your documents have been submitted and are being reviewed. This usually takes 24-48 hours.',
            'waitlistNumber': widget.waitlistNumber,
            'referenceId': widget.referenceId,
          },
        );
      });
      return;
    }

    // Documents Under Review / Submitted for Verification: stay on this screen.
    // Register/Login is only reached via Splash when status == APPROVED,
    // or via Refresh when status changes to APPROVED.
  }

  void _handleWaitlistState(WaitlistState state) {
    if (!widget.fromWaitlistCheck || !widget.underReview) return;

    final model = state.model;
    if (state.cubitStatus != WaitlistCubitStatus.loaded || model == null) {
      return;
    }

    // Stay on this screen while still under review.
    if (model.status == WaitlistStatus.underReview) return;

    final route = WaitlistNavigation.routeForStatus(model);
    final arguments = WaitlistNavigation.argumentsForStatus(model);

    Navigator.pushNamedAndRemoveUntil(
      context,
      route,
      (route) => false,
      arguments: arguments,
    );
  }

  @override
  Widget build(BuildContext context) {
    final waitlisted = widget.waitlisted;
    final underReview = widget.underReview;
    final title = waitlisted
        ? 'ADDED TO WAITLIST'
        : underReview
            ? 'REQUEST UNDER REVIEW'
            : 'SUBMITTED FOR VERIFICATION';

    final body = waitlisted
        ? (widget.message?.trim().isNotEmpty == true
            ? widget.message!.trim()
            : 'Your request has been submitted to the waitlist pending Super Admin approval.')
        : (widget.message?.trim().isNotEmpty == true
            ? widget.message!.trim()
            : underReview
                ? 'Already submitted. Your request is under review.'
                : 'Your documents have been submitted and are being reviewed. This usually takes 24-48 hours.');

    Widget content = Center(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Container(
          padding: EdgeInsets.all(32.w),
          decoration: BoxDecoration(
            border: Border.all(color: AppColours.primary, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(IconConstant.submitted),
              SizedBox(height: 24.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: CustomTextStyles.montserratBold.copyWith(
                  fontSize: 14,
                  color: AppColours.primary,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                body,
                textAlign: TextAlign.center,
                style: CustomTextStyles.openSansSemiBold.copyWith(
                  fontSize: 12,
                ),
              ),
              if (waitlisted &&
                  (widget.waitlistNumber != null ||
                      widget.referenceId != null)) ...[
                SizedBox(height: 24.h),
                if (widget.waitlistNumber != null)
                  _buildReferenceRow(
                    'Waitlist Number',
                    widget.waitlistNumber!,
                  ),
                if (widget.waitlistNumber != null &&
                    widget.referenceId != null)
                  SizedBox(height: 12.h),
                if (widget.referenceId != null)
                  _buildReferenceRow(
                    'Reference ID',
                    widget.referenceId!,
                  ),
              ],
              if (widget.fromWaitlistCheck && underReview) ...[
                SizedBox(height: 24.h),
                BlocBuilder<WaitlistCubit, WaitlistState>(
                  builder: (context, state) {
                    final isLoading =
                        state.cubitStatus == WaitlistCubitStatus.loading;
                    return SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () => context.refreshWaitlistStatus(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE6C27A),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                width: 22.w,
                                height: 22.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                'REFRESH',
                                style: CustomTextStyles.montserratBold.copyWith(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (widget.fromWaitlistCheck && widget.underReview) {
      content = BlocListener<WaitlistCubit, WaitlistState>(
        listener: (context, state) {
          _handleWaitlistState(state);
          if (state.cubitStatus == WaitlistCubitStatus.error &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red.shade800,
              ),
            );
          }
        },
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColours.black,
      body: content,
    );
  }

  Widget _buildReferenceRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColours.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: CustomTextStyles.openSansRegular.copyWith(
              fontSize: 10,
              color: AppColours.hintcolor,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: CustomTextStyles.montserratBold.copyWith(
              fontSize: 14,
              color: AppColours.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
