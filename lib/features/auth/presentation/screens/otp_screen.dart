import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomoride/core/utils/size_utils.dart';
import 'package:nomoride/features/auth/data/models/otp_session.dart';

import '../../../../core/widgets/app_logo.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/theme_helper.dart';
import '../bloc/otp_bloc.dart';
import '../bloc/otp_event.dart';
import '../bloc/otp_state.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({Key? key}) : super(key: key);

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  OtpSession? _session;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _session ??= OtpSession.fromArguments(
      ModalRoute.of(context)?.settings.arguments,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _clearControllers() {
    for (var controller in _controllers) {
      controller.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session ?? const OtpSession(
      mobileNumber: '',
      userToken: '',
      partnerId: '',
    );

    return BlocProvider(
      create: (context) => OtpBloc(session: session),
      child: BlocConsumer<OtpBloc, OtpState>(
        listener: (context, state) {
          if (state.isSuccess) {
            Navigator.pushReplacementNamed(context, AppRoutes.successScreen);
          } else if (state.errorMessage != null &&
              !state.hasError &&
              !state.isLoading) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: AppColours.black,
            body: SafeArea(
              child: SingleChildScrollView(
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                  width: double.maxFinite,
                  child: Column(
                    children: [
                      SizedBox(height: 100.h),
                      AppLogo(width: 180.w),
                      SizedBox(height: 10.h),
                      Text(
                        'Enter the 6-digit code sent to your\nMobile Number',
                        textAlign: TextAlign.center,
                        style: CustomTextStyles.openSansBold
                            .copyWith(fontSize: 14),
                      ),
                      if (session.mobileNumber.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Text(
                          session.mobileNumber,
                          style: CustomTextStyles.openSansSemiBold.copyWith(
                            color: AppColours.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      SizedBox(height: 40.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (index) => _buildOtpBox(context, index, state),
                        ),
                      ),
                      SizedBox(height: 15.h),
                      if (!state.hasError) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: state.secondsRemaining > 0
                              ? Text(
                                  'OTP expires in ${state.secondsRemaining} seconds',
                                  style: CustomTextStyles.openSansSemiBold
                                      .copyWith(
                                    fontSize: 14,
                                    color: AppColours.primary,
                                  ),
                                )
                              : Row(
                                  children: [
                                    Text(
                                      'Didn’t receive the code? ',
                                      style: CustomTextStyles.openSansRegular
                                          .copyWith(
                                        color: AppColours.hintcolor,
                                        fontSize: 14,
                                      ),
                                    ),
                                    _buildResendText(context, state),
                                  ],
                                ),
                        ),
                        SizedBox(height: 24.h),
                        _buildVerifyButton(context, state),
                      ] else ...[
                        SizedBox(height: 40.h),
                        _buildVerifyButton(context, state),
                        SizedBox(height: 20.h),
                        _buildResendText(context, state),
                        SizedBox(height: 40.h),
                        _buildErrorBox(state),
                      ],
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResendText(BuildContext context, OtpState state) {
    return GestureDetector(
      onTap: state.isLoading
          ? null
          : () {
              _clearControllers();
              context.read<OtpBloc>().add(ResendOtpEvent());
            },
      child: Text(
        'Resend OTP',
        style: CustomTextStyles.openSansSemiBold.copyWith(
          fontSize: 14,
          color: state.isLoading ? AppColours.hintcolor : AppColours.primary,
        ),
      ),
    );
  }

  Widget _buildVerifyButton(BuildContext context, OtpState state) {
    return SizedBox(
      width: double.maxFinite,
      height: 44.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColours.primary,
          disabledBackgroundColor: const Color(0xFF8E836F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        onPressed: (state.isButtonEnabled && !state.isLoading)
            ? () => context.read<OtpBloc>().add(VerifyOtpEvent())
            : null,
        child: state.isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'VERIFY',
                style: CustomTextStyles.montserratBold.copyWith(
                  color: state.isButtonEnabled
                      ? Colors.black
                      : Colors.black.withOpacity(0.5),
                  fontSize: 16.fSize,
                  letterSpacing: 1.6,
                ),
              ),
      ),
    );
  }

  Widget _buildErrorBox(OtpState state) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border.all(color: AppColours.primary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColours.primary, size: 28),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              state.errorMessage ??
                  'You have entered the wrong otp\nPlease try again.',
              style: CustomTextStyles.montserratBold.copyWith(
                color: AppColours.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBox(BuildContext context, int index, OtpState state) {
    return Container(
      width: 48.w,
      height: 60.h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        border: Border.all(color: AppColours.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (value) {
          var currentOtp = '';
          for (var controller in _controllers) {
            currentOtp += controller.text;
          }
          context.read<OtpBloc>().add(OtpChangedEvent(currentOtp));
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TextStyle(
          color: state.hasError ? Colors.red : AppColours.primary,
          fontSize: 22.fSize,
        ),
        decoration: InputDecoration(
          hintText: '-',
          hintStyle: TextStyle(color: AppColours.primary.withOpacity(0.5)),
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
