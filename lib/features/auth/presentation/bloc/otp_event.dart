import 'package:equatable/equatable.dart';

abstract class OtpEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class OtpChangedEvent extends OtpEvent {
  final String otp;
  OtpChangedEvent(this.otp);

  @override
  List<Object?> get props => [otp];
}

class VerifyOtpEvent extends OtpEvent {}

class ResendOtpEvent extends OtpEvent {}

class TimerTickEvent extends OtpEvent {
  final int secondsRemaining;
  TimerTickEvent(this.secondsRemaining);

  @override
  List<Object?> get props => [secondsRemaining];
}
