import 'package:equatable/equatable.dart';
import 'registration_status.dart';

class RegistrationState extends Equatable {
  const RegistrationState({
    this.status = RegistrationStatus.initial,
    this.currentStep = 0,
    this.fullName = '',
    this.dob = '',
    this.gender = 'Male',
    this.mobileNumber = '',
    this.addressProofType = '',
    this.currentAddress = '',
    this.profilePhoto,
    this.profilePhotoUrl,
    this.profilePhotoUploading = false,
    List<String?>? drivingLicenseImages,
    List<String?>? drivingLicenseUrls,
    List<bool>? drivingLicenseUploading,
    List<String?>? addressProofImages,
    List<String?>? addressProofUrls,
    List<bool>? addressProofUploading,
    this.rejectionReasons = const [],
    this.errorMessage,
    this.successMessage,
    this.referenceId,
    this.waitlistNumber,
  })  : drivingLicenseImages = drivingLicenseImages ?? const [null, null],
        drivingLicenseUrls = drivingLicenseUrls ?? const [null, null],
        drivingLicenseUploading = drivingLicenseUploading ?? const [false, false],
        addressProofImages = addressProofImages ?? const [null, null],
        addressProofUrls = addressProofUrls ?? const [null, null],
        addressProofUploading = addressProofUploading ?? const [false, false];

  final RegistrationStatus status;
  final int currentStep;

  final String fullName;
  final String dob;
  final String gender;
  final String mobileNumber;
  final String addressProofType;
  final String currentAddress;

  final String? profilePhoto;
  final String? profilePhotoUrl;
  final bool profilePhotoUploading;

  final List<String?> drivingLicenseImages;
  final List<String?> drivingLicenseUrls;
  final List<bool> drivingLicenseUploading;

  final List<String?> addressProofImages;
  final List<String?> addressProofUrls;
  final List<bool> addressProofUploading;

  final List<String> rejectionReasons;
  final String? errorMessage;
  final String? successMessage;
  final String? referenceId;
  final String? waitlistNumber;

  bool get isUploadingFiles =>
      profilePhotoUploading ||
      addressProofUploading.any((uploading) => uploading) ||
      drivingLicenseUploading.any((uploading) => uploading);

  bool get isFormValid =>
      fullName.trim().isNotEmpty &&
      dob.trim().isNotEmpty &&
      _isValidMobile(mobileNumber) &&
      currentAddress.trim().isNotEmpty &&
      addressProofType.trim().isNotEmpty &&
      (profilePhotoUrl?.trim().isNotEmpty ?? false) &&
      _slotPairComplete(addressProofUrls) &&
      _slotPairComplete(drivingLicenseUrls) &&
      !isUploadingFiles;

  bool get isEditFormValid =>
      fullName.trim().isNotEmpty &&
      dob.trim().isNotEmpty &&
      _isValidMobile(mobileNumber) &&
      currentAddress.trim().isNotEmpty &&
      addressProofType.trim().isNotEmpty &&
      (profilePhotoUrl?.trim().isNotEmpty ?? false) &&
      _hasFrontImage(addressProofUrls) &&
      _hasFrontImage(drivingLicenseUrls) &&
      !isUploadingFiles;

  static bool _isValidMobile(String value) {
    return RegExp(r'^\d{10}$').hasMatch(value.trim());
  }

  static bool _hasFrontImage(List<String?> slots) {
    if (slots.isEmpty) return false;
    return slots[0]?.trim().isNotEmpty ?? false;
  }

  static bool _slotPairComplete(List<String?> slots) {
    if (slots.length < 2) return false;
    return (slots[0]?.trim().isNotEmpty ?? false) &&
        (slots[1]?.trim().isNotEmpty ?? false);
  }

  RegistrationState copyWith({
    RegistrationStatus? status,
    int? currentStep,
    String? fullName,
    String? dob,
    String? gender,
    String? mobileNumber,
    String? addressProofType,
    String? currentAddress,
    String? profilePhoto,
    String? profilePhotoUrl,
    bool? profilePhotoUploading,
    bool clearProfilePhoto = false,
    bool clearProfilePhotoUrl = false,
    List<String?>? drivingLicenseImages,
    List<String?>? drivingLicenseUrls,
    List<bool>? drivingLicenseUploading,
    List<String?>? addressProofImages,
    List<String?>? addressProofUrls,
    List<bool>? addressProofUploading,
    List<String>? rejectionReasons,
    String? errorMessage,
    String? successMessage,
    String? referenceId,
    String? waitlistNumber,
  }) {
    return RegistrationState(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      fullName: fullName ?? this.fullName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      addressProofType: addressProofType ?? this.addressProofType,
      currentAddress: currentAddress ?? this.currentAddress,
      profilePhoto: clearProfilePhoto ? null : (profilePhoto ?? this.profilePhoto),
      profilePhotoUrl:
          clearProfilePhotoUrl ? null : (profilePhotoUrl ?? this.profilePhotoUrl),
      profilePhotoUploading:
          profilePhotoUploading ?? this.profilePhotoUploading,
      drivingLicenseImages: drivingLicenseImages ?? this.drivingLicenseImages,
      drivingLicenseUrls: drivingLicenseUrls ?? this.drivingLicenseUrls,
      drivingLicenseUploading:
          drivingLicenseUploading ?? this.drivingLicenseUploading,
      addressProofImages: addressProofImages ?? this.addressProofImages,
      addressProofUrls: addressProofUrls ?? this.addressProofUrls,
      addressProofUploading:
          addressProofUploading ?? this.addressProofUploading,
      rejectionReasons: rejectionReasons ?? this.rejectionReasons,
      errorMessage: errorMessage ?? this.errorMessage,
      successMessage: successMessage ?? this.successMessage,
      referenceId: referenceId ?? this.referenceId,
      waitlistNumber: waitlistNumber ?? this.waitlistNumber,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentStep,
        fullName,
        dob,
        gender,
        mobileNumber,
        addressProofType,
        currentAddress,
        profilePhoto,
        profilePhotoUrl,
        profilePhotoUploading,
        drivingLicenseImages,
        drivingLicenseUrls,
        drivingLicenseUploading,
        addressProofImages,
        addressProofUrls,
        addressProofUploading,
        rejectionReasons,
        errorMessage,
        successMessage,
        referenceId,
        waitlistNumber,
      ];
}
