import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/core/services/onesignal_service.dart';
import 'package:nomoride/features/auth/data/auth_repository.dart';
import 'package:nomoride/features/auth/data/models/otp_session.dart';

import 'otp_event.dart';
import 'otp_state.dart';

class OtpBloc extends Bloc<OtpEvent, OtpState> {
  OtpBloc({
    required OtpSession session,
    AuthRepository? repository,
  })  : _session = session,
        _userToken = session.userToken,
        _repository = repository ?? AuthRepository(),
        super(const OtpState(secondsRemaining: 30)) {
    on<OtpChangedEvent>(_onOtpChanged);
    on<VerifyOtpEvent>(_onVerifyOtp);
    on<ResendOtpEvent>(_onResendOtp);
    on<TimerTickEvent>(_onTimerTick);

    _startTimer();
  }

  final OtpSession _session;
  final AuthRepository _repository;
  String _userToken;
  Timer? _timer;

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.secondsRemaining > 0) {
        add(TimerTickEvent(state.secondsRemaining - 1));
      } else {
        _timer?.cancel();
      }
    });
  }

  void _onTimerTick(TimerTickEvent event, Emitter<OtpState> emit) {
    emit(state.copyWith(secondsRemaining: event.secondsRemaining));
  }

  void _onOtpChanged(OtpChangedEvent event, Emitter<OtpState> emit) {
    emit(state.copyWith(
      otp: event.otp,
      isButtonEnabled: event.otp.length == 6,
      hasError: false,
      clearError: true,
    ));
  }

  Future<void> _onVerifyOtp(
    VerifyOtpEvent event,
    Emitter<OtpState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, hasError: false, clearError: true));

    try {
      final authToken = await _repository.verifyOtp(
        userToken: _userToken,
        otp: state.otp,
        partnerId: _session.partnerId,
      );

      debugPrint('[OTP DEBUG] Verify OTP response received');
      debugPrint('[OTP DEBUG] About to save AuthSession');

      await AuthSession.save(
        token: authToken,
        partner: _session.partnerId,
        mobile: _session.mobileNumber,
      );

      debugPrint('[OTP DEBUG] AuthSession.save completed');
      debugPrint('[OTP DEBUG] OneSignal partnerId: ${_session.partnerId}');
      debugPrint('[OTP DEBUG] About to initialize OneSignal');

      await OneSignalService.initialize(partnerId: _session.partnerId);

      debugPrint('[OTP DEBUG] OneSignal initialization call completed');
      debugPrint('[OTP DEBUG] About to continue existing navigation flow');

      emit(state.copyWith(isSuccess: true, isLoading: false));
    } on ApiException catch (error) {
      emit(state.copyWith(
        hasError: true,
        isLoading: false,
        errorMessage: error.message,
      ));
    }
  }

  Future<void> _onResendOtp(
    ResendOtpEvent event,
    Emitter<OtpState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, hasError: false, clearError: true));

    try {
      _userToken = await _repository.resendOtp(
        mobileNumber: _session.mobileNumber,
        partnerId: _session.partnerId,
      );

      emit(OtpState(
        secondsRemaining: 30,
        isLoading: false,
      ));
      _startTimer();
    } on ApiException catch (error) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: error.message,
      ));
    }
  }
}
