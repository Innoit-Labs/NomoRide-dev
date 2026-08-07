import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/waitlist_session.dart';
import 'package:nomoride/features/registration/data/models/waitlist_status.dart';
import 'package:nomoride/features/registration/data/models/waitlist_status_model.dart';
import 'package:nomoride/features/registration/data/waitlist_service.dart';

import 'waitlist_state.dart';

class WaitlistCubit extends Cubit<WaitlistState> {
  WaitlistCubit({WaitlistService? service})
      : _service = service ?? WaitlistService(),
        super(const WaitlistState());

  final WaitlistService _service;

  Future<void> checkStatus({String? idOrNumber}) async {
    await _fetchStatus(
      idOrNumber ?? WaitlistSession.referenceId ?? WaitlistSession.statusLookupId,
    );
  }

  Future<void> refresh() => checkStatus();

  Future<void> _fetchStatus(String? idOrNumber) async {
    final lookup = idOrNumber?.trim();
    if (lookup == null || lookup.isEmpty) {
      emit(state.copyWith(
        cubitStatus: WaitlistCubitStatus.error,
        errorMessage: 'No saved waitlist reference found.',
        clearModel: true,
      ));
      return;
    }

    emit(state.copyWith(
      cubitStatus: WaitlistCubitStatus.loading,
      clearError: true,
    ));

    try {
      final model = await _service.getStatus(lookup);
      await _persistFromModel(model);

      emit(state.copyWith(
        cubitStatus: WaitlistCubitStatus.loaded,
        model: model,
        clearError: true,
      ));
    } on ApiException catch (error) {
      emit(state.copyWith(
        cubitStatus: WaitlistCubitStatus.error,
        errorMessage: error.message,
      ));
    }
  }

  Future<void> _persistFromModel(WaitlistStatusModel model) async {
    await WaitlistSession.saveFromRegistrationResponse(
      waitlistNumber: model.waitlistNumber,
      referenceId: model.referenceId,
      mobileNumber: model.mobileNumber,
    );

    if (model.status == WaitlistStatus.rejected) {
      await WaitlistSession.saveFromApiFormData(model.formData);
    }
  }
}
