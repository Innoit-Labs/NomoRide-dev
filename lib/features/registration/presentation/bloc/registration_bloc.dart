import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/core/services/waitlist_session.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/features/profile/data/models/delivery_partner_profile.dart';
import 'package:nomoride/features/profile/data/profile_repository.dart';
import 'package:nomoride/features/registration/data/delivery_partner_repository.dart';
import 'package:nomoride/features/registration/data/file_upload_repository.dart';
import 'package:nomoride/features/registration/data/waitlist_service.dart';
import 'package:nomoride/features/registration/presentation/bloc/registration_status.dart';
import 'registration_event.dart';
import 'registration_state.dart';

class RegistrationBloc extends Bloc<RegistrationEvent, RegistrationState> {
  RegistrationBloc({
    DeliveryPartnerRepository? repository,
    FileUploadRepository? uploadRepository,
    ProfileRepository? profileRepository,
    WaitlistService? waitlistService,
    this.isEditing = false,
    this.restoreDraft = false,
  })  : _repository = repository ?? DeliveryPartnerRepository(),
        _uploadRepository = uploadRepository ?? FileUploadRepository(),
        _profileRepository = profileRepository ?? ProfileRepository(),
        _waitlistService = waitlistService ?? WaitlistService(),
        super(const RegistrationState()) {
    on<FullNameChanged>((event, emit) {
      emit(state.copyWith(fullName: event.fullName));
    });

    on<DobChanged>((event, emit) {
      emit(state.copyWith(dob: event.dob));
    });

    on<GenderChanged>((event, emit) {
      emit(state.copyWith(gender: event.gender));
    });

    on<MobileNumberChanged>((event, emit) {
      final digitsOnly = event.mobileNumber.replaceAll(RegExp(r'\D'), '');
      final mobile = digitsOnly.length > 10
          ? digitsOnly.substring(0, 10)
          : digitsOnly;
      emit(state.copyWith(mobileNumber: mobile));
    });

    on<AddressProofTypeChanged>((event, emit) {
      emit(state.copyWith(
        addressProofType: event.type,
        addressProofImages: const [null, null],
        addressProofUrls: const [null, null],
        addressProofUploading: const [false, false],
      ));
    });

    on<CurrentAddressChanged>((event, emit) {
      emit(state.copyWith(currentAddress: event.address));
    });

    on<ProfilePhotoUpdated>(_onProfilePhotoUpdated);
    on<AddressProofSlotUpdated>(_onAddressProofSlotUpdated);
    on<AddressProofSlotCleared>(_onAddressProofSlotCleared);
    on<DrivingLicenseSlotUpdated>(_onDrivingLicenseSlotUpdated);
    on<DrivingLicenseSlotCleared>(_onDrivingLicenseSlotCleared);

    on<NextStepRequested>((event, emit) {
      emit(state.copyWith(currentStep: state.currentStep + 1));
    });

    on<PreviousStepRequested>((event, emit) {
      if (state.currentStep > 0) {
        emit(state.copyWith(currentStep: state.currentStep - 1));
      }
    });

    on<RegistrationSubmitted>(_onRegistrationSubmitted);
    on<LoadProfileForEdit>(_onLoadProfileForEdit);
    on<LoadSavedRegistrationDraft>(_onLoadSavedRegistrationDraft);

    if (restoreDraft && !isEditing) {
      add(const LoadSavedRegistrationDraft());
    }
  }

  final DeliveryPartnerRepository _repository;
  final FileUploadRepository _uploadRepository;
  final ProfileRepository _profileRepository;
  final WaitlistService _waitlistService;
  final bool isEditing;
  final bool restoreDraft;

  Future<void> _onLoadProfileForEdit(
    LoadProfileForEdit event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
      status: RegistrationStatus.loading,
      errorMessage: null,
    ));

    try {
      final profile = await _profileRepository.getProfile();
      emit(state.copyWith(
        status: RegistrationStatus.initial,
        fullName: profile.fullName,
        dob: profile.displayDob,
        gender: profile.gender,
        mobileNumber: profile.mobileNumber.isNotEmpty
            ? profile.mobileNumber
            : (AuthSession.mobileNumber ?? ''),
        addressProofType: profile.addressProofType,
        currentAddress: profile.currentAddress,
        profilePhotoUrl: profile.profilePhotoUrl,
        addressProofUrls: [
          profile.addressProofImageUrl,
          profile.addressProofBackImageUrl,
        ],
        drivingLicenseUrls: [
          profile.drivingLicenseImageUrl,
          profile.drivingLicenseBackImageUrl,
        ],
      ));
    } on ApiException catch (error) {
      emit(state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: error.message,
        rejectionReasons: [error.message],
      ));
    }
  }

  Future<void> _onLoadSavedRegistrationDraft(
    LoadSavedRegistrationDraft event,
    Emitter<RegistrationState> emit,
  ) async {
    final draft = await WaitlistSession.loadRegistrationDraft();
    if (draft == null || draft.isEmpty) return;

    List<String?> readUrlPair(dynamic value) {
      if (value is! List) return const [null, null];
      final urls = value.map((item) {
        final text = item?.toString().trim() ?? '';
        return text.isEmpty ? null : text;
      }).toList();
      if (urls.isEmpty) return const [null, null];
      if (urls.length == 1) return [urls[0], null];
      return [urls[0], urls[1]];
    }

    emit(state.copyWith(
      fullName: draft['fullName']?.toString() ?? state.fullName,
      dob: draft['dob']?.toString() ?? state.dob,
      gender: draft['gender']?.toString() ?? state.gender,
      mobileNumber: draft['mobileNumber']?.toString() ?? state.mobileNumber,
      addressProofType:
          draft['addressProofType']?.toString() ?? state.addressProofType,
      currentAddress:
          draft['currentAddress']?.toString() ?? state.currentAddress,
      profilePhotoUrl: draft['profilePhotoUrl']?.toString(),
      addressProofUrls: readUrlPair(draft['addressProofUrls']),
      drivingLicenseUrls: readUrlPair(draft['drivingLicenseUrls']),
    ));
  }

  DeliveryPartnerProfile _profileFromState() {
    return DeliveryPartnerProfile(
      fullName: state.fullName,
      mobileNumber: state.mobileNumber,
      gender: state.gender,
      dateOfBirth: state.dob,
      addressProofType: state.addressProofType,
      currentAddress: state.currentAddress,
      profilePhotoUrl: state.profilePhotoUrl,
      addressProofImageUrl:
          state.addressProofUrls.isNotEmpty ? state.addressProofUrls[0] : null,
      addressProofBackImageUrl:
          state.addressProofUrls.length > 1 ? state.addressProofUrls[1] : null,
      drivingLicenseImageUrl: state.drivingLicenseUrls.isNotEmpty
          ? state.drivingLicenseUrls[0]
          : null,
      drivingLicenseBackImageUrl: state.drivingLicenseUrls.length > 1
          ? state.drivingLicenseUrls[1]
          : null,
    );
  }

  Future<void> _onProfilePhotoUpdated(
    ProfilePhotoUpdated event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
      profilePhoto: event.path,
      clearProfilePhotoUrl: true,
      profilePhotoUploading: true,
      errorMessage: null,
    ));

    try {
      final url = await _uploadRepository.uploadImage(
        filePath: event.path,
        fieldName: 'file',
      );
      emit(state.copyWith(
        profilePhotoUrl: url,
        profilePhotoUploading: false,
      ));
    } on ApiException catch (error) {
      emit(state.copyWith(
        profilePhotoUploading: false,
        clearProfilePhoto: true,
        clearProfilePhotoUrl: true,
        errorMessage: error.message,
      ));
    }
  }

  Future<void> _onAddressProofSlotUpdated(
    AddressProofSlotUpdated event,
    Emitter<RegistrationState> emit,
  ) async {
    if (event.slotIndex < 0 || event.slotIndex > 1) return;

    final paths = _copySlotList(state.addressProofImages);
    final urls = _copySlotList(state.addressProofUrls);
    final uploading = _copyUploadingList(state.addressProofUploading);

    paths[event.slotIndex] = event.path;
    urls[event.slotIndex] = null;
    uploading[event.slotIndex] = true;

    emit(state.copyWith(
      addressProofImages: paths,
      addressProofUrls: urls,
      addressProofUploading: uploading,
      errorMessage: null,
    ));

    try {
      final url = await _uploadRepository.uploadImage(
        filePath: event.path,
        fieldName: 'file',
      );
      final nextUrls = _copySlotList(state.addressProofUrls);
      final nextUploading = _copyUploadingList(state.addressProofUploading);
      nextUrls[event.slotIndex] = url;
      nextUploading[event.slotIndex] = false;
      emit(state.copyWith(
        addressProofUrls: nextUrls,
        addressProofUploading: nextUploading,
      ));
    } on ApiException catch (error) {
      final nextPaths = _copySlotList(state.addressProofImages);
      final nextUrls = _copySlotList(state.addressProofUrls);
      final nextUploading = _copyUploadingList(state.addressProofUploading);
      nextPaths[event.slotIndex] = null;
      nextUrls[event.slotIndex] = null;
      nextUploading[event.slotIndex] = false;
      emit(state.copyWith(
        addressProofImages: nextPaths,
        addressProofUrls: nextUrls,
        addressProofUploading: nextUploading,
        errorMessage: error.message,
      ));
    }
  }

  void _onAddressProofSlotCleared(
    AddressProofSlotCleared event,
    Emitter<RegistrationState> emit,
  ) {
    if (event.slotIndex < 0 || event.slotIndex > 1) return;

    final paths = _copySlotList(state.addressProofImages);
    final urls = _copySlotList(state.addressProofUrls);
    final uploading = _copyUploadingList(state.addressProofUploading);
    paths[event.slotIndex] = null;
    urls[event.slotIndex] = null;
    uploading[event.slotIndex] = false;

    emit(state.copyWith(
      addressProofImages: paths,
      addressProofUrls: urls,
      addressProofUploading: uploading,
    ));
  }

  Future<void> _onDrivingLicenseSlotUpdated(
    DrivingLicenseSlotUpdated event,
    Emitter<RegistrationState> emit,
  ) async {
    if (event.slotIndex < 0 || event.slotIndex > 1) return;

    final paths = _copySlotList(state.drivingLicenseImages);
    final urls = _copySlotList(state.drivingLicenseUrls);
    final uploading = _copyUploadingList(state.drivingLicenseUploading);

    paths[event.slotIndex] = event.path;
    urls[event.slotIndex] = null;
    uploading[event.slotIndex] = true;

    emit(state.copyWith(
      drivingLicenseImages: paths,
      drivingLicenseUrls: urls,
      drivingLicenseUploading: uploading,
      errorMessage: null,
    ));

    try {
      final url = await _uploadRepository.uploadImage(
        filePath: event.path,
        fieldName: 'file',
      );
      final nextUrls = _copySlotList(state.drivingLicenseUrls);
      final nextUploading = _copyUploadingList(state.drivingLicenseUploading);
      nextUrls[event.slotIndex] = url;
      nextUploading[event.slotIndex] = false;
      emit(state.copyWith(
        drivingLicenseUrls: nextUrls,
        drivingLicenseUploading: nextUploading,
      ));
    } on ApiException catch (error) {
      final nextPaths = _copySlotList(state.drivingLicenseImages);
      final nextUrls = _copySlotList(state.drivingLicenseUrls);
      final nextUploading = _copyUploadingList(state.drivingLicenseUploading);
      nextPaths[event.slotIndex] = null;
      nextUrls[event.slotIndex] = null;
      nextUploading[event.slotIndex] = false;
      emit(state.copyWith(
        drivingLicenseImages: nextPaths,
        drivingLicenseUrls: nextUrls,
        drivingLicenseUploading: nextUploading,
        errorMessage: error.message,
      ));
    }
  }

  void _onDrivingLicenseSlotCleared(
    DrivingLicenseSlotCleared event,
    Emitter<RegistrationState> emit,
  ) {
    if (event.slotIndex < 0 || event.slotIndex > 1) return;

    final paths = _copySlotList(state.drivingLicenseImages);
    final urls = _copySlotList(state.drivingLicenseUrls);
    final uploading = _copyUploadingList(state.drivingLicenseUploading);
    paths[event.slotIndex] = null;
    urls[event.slotIndex] = null;
    uploading[event.slotIndex] = false;

    emit(state.copyWith(
      drivingLicenseImages: paths,
      drivingLicenseUrls: urls,
      drivingLicenseUploading: uploading,
    ));
  }

  Future<void> _onRegistrationSubmitted(
    RegistrationSubmitted event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
      status: RegistrationStatus.loading,
      errorMessage: null,
    ));

    if (isEditing) {
      try {
        await _profileRepository.updateProfile(_profileFromState());
        emit(state.copyWith(status: RegistrationStatus.success));
      } on ApiException catch (error) {
        emit(state.copyWith(
          status: RegistrationStatus.error,
          errorMessage: error.message,
          rejectionReasons: [error.message],
        ));
      }
      return;
    }

    // Re-upload from rejected flow — call waitlist reupload, not register.
    if (restoreDraft) {
      await _onReuploadSubmitted(emit);
      return;
    }

    try {
      final response = await _repository.registerDeliveryPartner(state);

      debugPrint('========== REGISTRATION RESPONSE PARSE ==========');
      debugPrint('success: ${response.success}');
      debugPrint('waitlisted: ${response.waitlisted}');
      debugPrint('underReview: ${response.underReview}');
      debugPrint('reference_id: ${response.referenceId}');
      debugPrint('waitlist_number: ${response.waitlistNumber}');
      debugPrint('================================================');

      // Waitlisted success must be handled before under-review.
      if (response.waitlisted) {
        await WaitlistSession.saveFromRegistrationResponse(
          referenceId: response.referenceId,
          waitlistNumber: response.waitlistNumber,
          mobileNumber: state.mobileNumber,
        );
        emit(state.copyWith(
          status: RegistrationStatus.waitlisted,
          successMessage: response.message,
          referenceId: response.referenceId ?? WaitlistSession.referenceId,
          waitlistNumber:
              response.waitlistNumber ?? WaitlistSession.waitlistNumber,
        ));
        return;
      }

      if (response.underReview) {
        // Keep any previously stored reference_id when API omits it.
        await WaitlistSession.saveFromRegistrationResponse(
          referenceId: response.referenceId ?? WaitlistSession.referenceId,
          waitlistNumber:
              response.waitlistNumber ?? WaitlistSession.waitlistNumber,
          mobileNumber: state.mobileNumber,
        );
        emit(state.copyWith(
          status: RegistrationStatus.underReview,
          successMessage: response.message,
          referenceId: response.referenceId ?? WaitlistSession.referenceId,
          waitlistNumber:
              response.waitlistNumber ?? WaitlistSession.waitlistNumber,
        ));
        return;
      }

      if (response.success) {
        await WaitlistSession.saveFromRegistrationResponse(
          referenceId: response.referenceId,
          waitlistNumber: response.waitlistNumber,
          mobileNumber: state.mobileNumber,
        );
        emit(state.copyWith(
          status: RegistrationStatus.success,
          successMessage: response.message,
          referenceId: response.referenceId,
          waitlistNumber: response.waitlistNumber,
        ));
        return;
      }

      emit(state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: response.message,
        rejectionReasons: [response.message],
      ));
    } on ApiException catch (error) {
      if (_isUnderReviewMessage(error.message)) {
        // HTTP 400 "Already submitted..." — reuse stored reference_id.
        await WaitlistSession.saveMobileNumber(state.mobileNumber);
        debugPrint('========== WAITLIST SAVE ==========');
        debugPrint('reference_id: ${WaitlistSession.referenceId}');
        debugPrint('waitlist_number: ${WaitlistSession.waitlistNumber}');
        debugPrint('mobile_number: ${WaitlistSession.mobileNumber}');
        debugPrint('(under-review error; kept existing reference_id)');
        debugPrint('===================================');
        emit(state.copyWith(
          status: RegistrationStatus.underReview,
          successMessage: error.message,
          referenceId: WaitlistSession.referenceId,
          waitlistNumber: WaitlistSession.waitlistNumber,
        ));
        return;
      }
      emit(state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: error.message,
        rejectionReasons: [error.message],
      ));
    }
  }

  Future<void> _onReuploadSubmitted(Emitter<RegistrationState> emit) async {
    final idOrNumber = WaitlistSession.waitlistNumber?.trim().isNotEmpty == true
        ? WaitlistSession.waitlistNumber!.trim()
        : WaitlistSession.referenceId?.trim();

    if (idOrNumber == null || idOrNumber.isEmpty) {
      emit(state.copyWith(
        status: RegistrationStatus.error,
        errorMessage:
            'Waitlist reference is missing. Please contact support or try again later.',
        rejectionReasons: const [
          'Waitlist reference is missing. Please contact support or try again later.',
        ],
      ));
      return;
    }

    try {
      final response = await _waitlistService.reuploadDocuments(
        idOrNumber: idOrNumber,
        state: state,
      );

      await WaitlistSession.saveFromRegistrationResponse(
        referenceId: response.referenceId ?? WaitlistSession.referenceId,
        waitlistNumber:
            response.waitlistNumber ?? WaitlistSession.waitlistNumber,
        mobileNumber: state.mobileNumber,
      );
      await WaitlistSession.saveRegistrationDraft(
        WaitlistSession.draftFromRegistrationState(
          fullName: state.fullName,
          dob: state.dob,
          gender: state.gender,
          mobileNumber: state.mobileNumber,
          addressProofType: state.addressProofType,
          currentAddress: state.currentAddress,
          profilePhotoUrl: state.profilePhotoUrl,
          addressProofUrls: state.addressProofUrls,
          drivingLicenseUrls: state.drivingLicenseUrls,
        ),
      );

      if (response.success) {
        emit(state.copyWith(
          status: RegistrationStatus.underReview,
          successMessage: response.message.isNotEmpty
              ? response.message
              : 'Documents and registration details re-uploaded successfully',
          referenceId: response.referenceId ?? WaitlistSession.referenceId,
          waitlistNumber:
              response.waitlistNumber ?? WaitlistSession.waitlistNumber,
        ));
        return;
      }

      emit(state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: response.message,
        rejectionReasons: [response.message],
      ));
    } on ApiException catch (error) {
      emit(state.copyWith(
        status: RegistrationStatus.error,
        errorMessage: error.message,
        rejectionReasons: [error.message],
      ));
    }
  }

  static bool _isUnderReviewMessage(String message) {
    final lower = message.toLowerCase();
    return lower.contains('under review') ||
        lower.contains('already submitted') ||
        (lower.contains('already') && lower.contains('review'));
  }

  List<String?> _copySlotList(List<String?> values) {
    return List<String?>.from(values);
  }

  List<bool> _copyUploadingList(List<bool> values) {
    return List<bool>.from(values);
  }
}
