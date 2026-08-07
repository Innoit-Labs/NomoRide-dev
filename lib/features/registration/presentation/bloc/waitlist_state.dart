import 'package:equatable/equatable.dart';
import 'package:nomoride/features/registration/data/models/waitlist_status_model.dart';

enum WaitlistCubitStatus {
  initial,
  loading,
  loaded,
  error,
}

class WaitlistState extends Equatable {
  const WaitlistState({
    this.cubitStatus = WaitlistCubitStatus.initial,
    this.model,
    this.errorMessage,
  });

  final WaitlistCubitStatus cubitStatus;
  final WaitlistStatusModel? model;
  final String? errorMessage;

  WaitlistState copyWith({
    WaitlistCubitStatus? cubitStatus,
    WaitlistStatusModel? model,
    String? errorMessage,
    bool clearError = false,
    bool clearModel = false,
  }) {
    return WaitlistState(
      cubitStatus: cubitStatus ?? this.cubitStatus,
      model: clearModel ? null : (model ?? this.model),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [cubitStatus, model, errorMessage];
}
