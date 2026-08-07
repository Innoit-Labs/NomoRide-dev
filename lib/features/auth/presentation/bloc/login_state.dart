import 'package:equatable/equatable.dart';
import 'package:nomoride/features/auth/data/models/otp_session.dart';
import 'login_status.dart';

class LoginState extends Equatable {
  final String mobileNumber;
  final bool isButtonEnabled;
  final LoginStatus status;
  final OtpSession? otpSession;
  final String? errorMessage;

  const LoginState({
    this.mobileNumber = '',
    this.isButtonEnabled = false,
    this.status = LoginStatus.initial,
    this.otpSession,
    this.errorMessage,
  });

  bool get isLoading => status == LoginStatus.loading;

  LoginState copyWith({
    String? mobileNumber,
    bool? isButtonEnabled,
    LoginStatus? status,
    OtpSession? otpSession,
    String? errorMessage,
    bool clearOtpSession = false,
    bool clearError = false,
  }) {
    return LoginState(
      mobileNumber: mobileNumber ?? this.mobileNumber,
      isButtonEnabled: isButtonEnabled ?? this.isButtonEnabled,
      status: status ?? this.status,
      otpSession: clearOtpSession ? null : (otpSession ?? this.otpSession),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        mobileNumber,
        isButtonEnabled,
        status,
        otpSession,
        errorMessage,
      ];
}
