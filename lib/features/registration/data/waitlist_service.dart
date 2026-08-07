import 'package:nomoride/features/registration/data/models/registration_response.dart';
import 'package:nomoride/features/registration/data/models/waitlist_status_model.dart';
import 'package:nomoride/features/registration/data/waitlist_repository.dart';
import 'package:nomoride/features/registration/presentation/bloc/registration_state.dart';

class WaitlistService {
  WaitlistService({WaitlistRepository? repository})
      : _repository = repository ?? WaitlistRepository();

  final WaitlistRepository _repository;

  Future<WaitlistStatusModel> getStatus(String idOrNumber) {
    return _repository.getStatus(idOrNumber);
  }

  Future<RegistrationResponse> reuploadDocuments({
    required String idOrNumber,
    required RegistrationState state,
  }) {
    return _repository.reuploadDocuments(
      idOrNumber: idOrNumber,
      state: state,
    );
  }
}
