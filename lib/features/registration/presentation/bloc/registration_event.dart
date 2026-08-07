import 'package:equatable/equatable.dart';

abstract class RegistrationEvent extends Equatable {
  const RegistrationEvent();

  @override
  List<Object?> get props => [];
}

class FullNameChanged extends RegistrationEvent {
  final String fullName;
  const FullNameChanged(this.fullName);
  @override
  List<Object?> get props => [fullName];
}

class DobChanged extends RegistrationEvent {
  final String dob;
  const DobChanged(this.dob);
  @override
  List<Object?> get props => [dob];
}

class GenderChanged extends RegistrationEvent {
  final String gender;
  const GenderChanged(this.gender);
  @override
  List<Object?> get props => [gender];
}

class MobileNumberChanged extends RegistrationEvent {
  final String mobileNumber;
  const MobileNumberChanged(this.mobileNumber);
  @override
  List<Object?> get props => [mobileNumber];
}

class AddressProofTypeChanged extends RegistrationEvent {
  final String type;
  const AddressProofTypeChanged(this.type);
  @override
  List<Object?> get props => [type];
}

class CurrentAddressChanged extends RegistrationEvent {
  final String address;
  const CurrentAddressChanged(this.address);
  @override
  List<Object?> get props => [address];
}

class ProfilePhotoUpdated extends RegistrationEvent {
  final String path;
  const ProfilePhotoUpdated(this.path);
  @override
  List<Object?> get props => [path];
}

class AddressProofSlotUpdated extends RegistrationEvent {
  final int slotIndex;
  final String path;
  const AddressProofSlotUpdated({required this.slotIndex, required this.path});
  @override
  List<Object?> get props => [slotIndex, path];
}

class AddressProofSlotCleared extends RegistrationEvent {
  final int slotIndex;
  const AddressProofSlotCleared(this.slotIndex);
  @override
  List<Object?> get props => [slotIndex];
}

class DrivingLicenseSlotUpdated extends RegistrationEvent {
  final int slotIndex;
  final String path;
  const DrivingLicenseSlotUpdated({required this.slotIndex, required this.path});
  @override
  List<Object?> get props => [slotIndex, path];
}

class DrivingLicenseSlotCleared extends RegistrationEvent {
  final int slotIndex;
  const DrivingLicenseSlotCleared(this.slotIndex);
  @override
  List<Object?> get props => [slotIndex];
}

class NextStepRequested extends RegistrationEvent {}
class PreviousStepRequested extends RegistrationEvent {}
class RegistrationSubmitted extends RegistrationEvent {}

class LoadProfileForEdit extends RegistrationEvent {
  const LoadProfileForEdit();
}

class LoadSavedRegistrationDraft extends RegistrationEvent {
  const LoadSavedRegistrationDraft();
}
