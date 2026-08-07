import 'package:equatable/equatable.dart';

class OtpState extends Equatable {
  final String otp;
  final bool isButtonEnabled;
  final int secondsRemaining;
  final bool hasError;
  final bool isSuccess;
  final bool isLoading;
  final String? errorMessage;

  const OtpState({
    this.otp = '',
    this.isButtonEnabled = false,
    this.secondsRemaining = 30,
    this.hasError = false,
    this.isSuccess = false,
    this.isLoading = false,
    this.errorMessage,
  });

  OtpState copyWith({
    String? otp,
    bool? isButtonEnabled,
    int? secondsRemaining,
    bool? hasError,
    bool? isSuccess,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return OtpState(
      otp: otp ?? this.otp,
      isButtonEnabled: isButtonEnabled ?? this.isButtonEnabled,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      hasError: hasError ?? this.hasError,
      isSuccess: isSuccess ?? this.isSuccess,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        otp,
        isButtonEnabled,
        secondsRemaining,
        hasError,
        isSuccess,
        isLoading,
        errorMessage,
      ];
}
