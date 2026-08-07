import 'package:equatable/equatable.dart';

abstract class LoginEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class MobileNumberChangedEvent extends LoginEvent {
  final String mobileNumber;
  MobileNumberChangedEvent(this.mobileNumber);

  @override
  List<Object?> get props => [mobileNumber];
}

class LoginSubmitEvent extends LoginEvent {}

class LoginOtpNavigationConsumed extends LoginEvent {}
