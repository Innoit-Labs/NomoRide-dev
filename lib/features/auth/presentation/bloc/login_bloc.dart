import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/features/auth/data/auth_repository.dart';

import 'login_event.dart';
import 'login_state.dart';
import 'login_status.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc({AuthRepository? repository})
      : _repository = repository ?? AuthRepository(),
        super(const LoginState()) {
    on<MobileNumberChangedEvent>(_onMobileNumberChanged);
    on<LoginSubmitEvent>(_onLoginSubmit);
    on<LoginOtpNavigationConsumed>(_onNavigationConsumed);
  }

  final AuthRepository _repository;

  void _onMobileNumberChanged(
    MobileNumberChangedEvent event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(
      mobileNumber: event.mobileNumber,
      isButtonEnabled: event.mobileNumber.length == 10,
      clearError: true,
    ));
  }

  Future<void> _onLoginSubmit(
    LoginSubmitEvent event,
    Emitter<LoginState> emit,
  ) async {
    if (!state.isButtonEnabled) return;

    emit(state.copyWith(
      status: LoginStatus.loading,
      clearError: true,
      clearOtpSession: true,
    ));

    try {
      final session = await _repository.login(state.mobileNumber);
      emit(state.copyWith(
        status: LoginStatus.otpSent,
        otpSession: session,
      ));
    } on ApiException catch (error) {
      emit(state.copyWith(
        status: LoginStatus.failure,
        errorMessage: error.message,
      ));
    }
  }

  void _onNavigationConsumed(
    LoginOtpNavigationConsumed event,
    Emitter<LoginState> emit,
  ) {
    emit(state.copyWith(
      status: LoginStatus.initial,
      clearOtpSession: true,
    ));
  }
}
