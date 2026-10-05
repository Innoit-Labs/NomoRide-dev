import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomoride/core/utils/size_utils.dart';

import '../../../../core/widgets/app_logo.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/theme_helper.dart';
import '../bloc/login_bloc.dart';
import '../bloc/login_event.dart';
import '../bloc/login_state.dart';
import '../bloc/login_status.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LoginBloc(),
      child: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state.status == LoginStatus.otpSent && state.otpSession != null) {
            Navigator.pushNamed(
              context,
              AppRoutes.otpScreen,
              arguments: state.otpSession!.toArguments(),
            );
            context.read<LoginBloc>().add(LoginOtpNavigationConsumed());
          } else if (state.status == LoginStatus.failure &&
              state.errorMessage != null) {
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
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                  width: double.maxFinite,
                  child: Column(
                    children: [
                      SizedBox(height: 100.h),
                      AppLogo(width: 200.w),
                      SizedBox(height: 40.h),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Login with Mobile Number',
                          style: CustomTextStyles.openSansBold
                              .copyWith(fontSize: 14),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      TextField(
                        onChanged: (value) {
                          context
                              .read<LoginBloc>()
                              .add(MobileNumberChangedEvent(value));
                        },
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Mobile Number',
                          hintStyle: CustomTextStyles.openSansRegular.copyWith(
                            fontSize: 16,
                            color: AppColours.hintcolor,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColours.primary),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColours.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'We will send an OTP to this mobile number.',
                          style: CustomTextStyles.openSansSemiBold.copyWith(
                            color: AppColours.hintcolor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: double.maxFinite,
                        height: 44.h,
                        child: ElevatedButton(
                          onPressed: state.isButtonEnabled && !state.isLoading
                              ? () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  context
                                      .read<LoginBloc>()
                                      .add(LoginSubmitEvent());
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColours.primary,
                            disabledBackgroundColor: const Color(0xFF8E836F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
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
                                  'LOGIN',
                                  style:
                                      CustomTextStyles.montserratBold.copyWith(
                                    color: state.isButtonEnabled
                                        ? Colors.black
                                        : Colors.black.withOpacity(0.5),
                                    fontSize: 16.fSize,
                                  ),
                                ),
                        ),
                      ),
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
}
