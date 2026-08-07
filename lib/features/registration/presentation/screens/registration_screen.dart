import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nomoride/core/utils/size_utils.dart';


import '../../../../core/utils/icon_constant.dart';
import '../../../../routes/app_routes.dart';
import '../../../../theme/theme_helper.dart';
import 'package:nomoride/core/services/waitlist_session.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/features/registration/data/address_proof_type.dart';
import 'package:nomoride/features/registration/data/models/waitlist_status.dart';
import 'package:nomoride/features/registration/data/waitlist_service.dart';
import 'package:nomoride/features/registration/presentation/waitlist_navigation.dart';
import '../bloc/registration_bloc.dart';
import '../bloc/registration_event.dart';
import '../bloc/registration_state.dart';
import '../bloc/registration_status.dart';

class RegistrationScreen extends StatefulWidget {
  final bool isEditing;
  final bool restoreDraft;

  const RegistrationScreen({
    super.key,
    this.isEditing = false,
    this.restoreDraft = false,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  bool _addressProofMenuExpanded = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _syncControllersFromState(RegistrationState state) {
    if (_fullNameController.text != state.fullName) {
      _fullNameController.text = state.fullName;
    }
    if (_mobileController.text != state.mobileNumber) {
      _mobileController.text = state.mobileNumber;
    }
    if (_addressController.text != state.currentAddress) {
      _addressController.text = state.currentAddress;
    }
    if (_dobController.text != state.dob) {
      _dobController.text = state.dob;
    }
  }

  bool _canSubmit(RegistrationState state) {
    if (state.status == RegistrationStatus.loading || state.isUploadingFiles) {
      return false;
    }
    if (widget.isEditing) {
      return state.isEditFormValid;
    }
    return state.isFormValid;
  }

  String? _mobileErrorText(String mobileNumber) {
    final mobile = mobileNumber.trim();
    if (mobile.isEmpty) return null;
    if (mobile.length < 10) {
      return 'Mobile number must be 10 digits';
    }
    if (mobile.length > 10 || !RegExp(r'^\d{10}$').hasMatch(mobile)) {
      return 'Enter a valid 10-digit mobile number';
    }
    return null;
  }

  Future<void> _pickImage(BuildContext context, ImageSource source, Function(String) onPicked) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 35,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (pickedFile != null) {
      onPicked(pickedFile.path);
    }
  }

  void _showImageSourceDialog(BuildContext context, Function(String) onPicked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColours.primary),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.camera, onPicked);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColours.primary),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.gallery, onPicked);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColours.primary,
              onPrimary: Colors.black87,
              surface: Color(0xFF1A1A1F),
              onSurface: AppColours.secondary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColours.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !context.mounted) return;
    final formattedDate =
        "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
    _dobController.text = formattedDate;
    context.read<RegistrationBloc>().add(DobChanged(formattedDate));
  }

  Future<void> _persistWaitlistData(RegistrationState state) async {
    await WaitlistSession.saveFromRegistrationResponse(
      referenceId: state.referenceId,
      waitlistNumber: state.waitlistNumber,
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
  }

  Future<void> _handleAlreadyUnderReview(
    BuildContext context,
    RegistrationState state,
  ) async {
    final referenceId = (state.referenceId ?? WaitlistSession.referenceId)
        ?.trim();

    if (referenceId == null || referenceId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Your registration is already under review. '
            'Please contact support or try again later.',
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    await WaitlistSession.saveFromRegistrationResponse(
      referenceId: referenceId,
      waitlistNumber: state.waitlistNumber ?? WaitlistSession.waitlistNumber,
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

    try {
      final model = await WaitlistService().getStatus(referenceId);

      await WaitlistSession.saveFromRegistrationResponse(
        waitlistNumber: model.waitlistNumber,
        referenceId: model.referenceId ?? referenceId,
        mobileNumber: model.mobileNumber,
      );
      if (model.status == WaitlistStatus.rejected) {
        await WaitlistSession.saveFromApiFormData(model.formData);
      }

      if (!context.mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        WaitlistNavigation.routeForStatus(model),
        (route) => false,
        arguments: WaitlistNavigation.argumentsForStatus(model),
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Your registration is already under review. '
            'Please contact support or try again later.',
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = RegistrationBloc(
          isEditing: widget.isEditing,
          restoreDraft: widget.restoreDraft,
        );
        if (widget.isEditing) {
          bloc.add(const LoadProfileForEdit());
        }
        return bloc;
      },
      child: Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColours.primary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.isEditing ? 'Edit Profile' : 'Registration Form',
            style: CustomTextStyles.montserratBold.copyWith(color: AppColours.primary),
          ),
          centerTitle: true,
          bottom: PreferredSize(  preferredSize: const Size.fromHeight(2), // 🔥 important

              child:  Container(
                height: 2,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFFE6C27A).withValues(alpha: 0.15),
                      const Color(0xFFE6C27A),
                      const Color(0xFFE6C27A).withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),

          ),


        ),
        body: BlocConsumer<RegistrationBloc, RegistrationState>(
          listener: (context, state) async {
            if (state.status == RegistrationStatus.success) {
              if (widget.isEditing) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile Updated Successfully')),
                );
              } else {
                await _persistWaitlistData(state);
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.registrationSuccessScreen,
                  (route) => false,
                  arguments: {
                    'waitlisted': false,
                    'message': state.successMessage,
                  },
                );
              }
            } else if (state.status == RegistrationStatus.waitlisted) {
              await _persistWaitlistData(state);
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.registrationSuccessScreen,
                (route) => false,
                arguments: {
                  'waitlisted': true,
                  'message': state.successMessage,
                  'waitlistNumber': state.waitlistNumber,
                  'referenceId': state.referenceId,
                },
              );
            } else if (state.status == RegistrationStatus.underReview) {
              if (widget.restoreDraft) {
                // Re-upload success → Documents Under Review, stay there.
                await _persistWaitlistData(state);
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.registrationSuccessScreen,
                  (route) => false,
                  arguments: {
                    'waitlisted': false,
                    'underReview': true,
                    'fromWaitlistCheck': true,
                    'message': state.successMessage ??
                        'Your documents have been submitted and are being reviewed. This usually takes 24-48 hours.',
                    'waitlistNumber': state.waitlistNumber,
                    'referenceId': state.referenceId,
                  },
                );
              } else {
                await _handleAlreadyUnderReview(context, state);
              }
            } else if (state.status == RegistrationStatus.error) {
              if (widget.isEditing &&
                  state.fullName.isEmpty &&
                  state.mobileNumber.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      state.errorMessage ?? 'Failed to load profile',
                    ),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
              } else if (widget.restoreDraft) {
                // Stay on form and show API validation / network errors.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      state.errorMessage ?? 'Document re-upload failed',
                    ),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
              } else {
                Navigator.pushNamed(
                  context,
                  AppRoutes.rejectedScreen,
                  arguments: state.rejectionReasons.isNotEmpty
                      ? state.rejectionReasons
                      : [state.errorMessage ?? 'Registration failed'],
                );
              }
            } else if (state.errorMessage != null &&
                state.status == RegistrationStatus.initial) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: Colors.red.shade800,
                ),
              );
            }
          },
          builder: (context, state) {
            _syncControllersFromState(state);

            return Stack(
              children: [
                SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfilePhotoPicker(context, state),
                  SizedBox(height: 32.h),
                  _buildTextField(
                    label: 'FULL NAME *',
                    hint: 'Enter your full name',
                    controller: _fullNameController,
                    onChanged: (val) => context.read<RegistrationBloc>().add(FullNameChanged(val)),
                  ),
                  SizedBox(height: 20.h),
                  _buildTextField(
                    label: 'DATE OF BIRTH *',
                    hint: 'DD/MM/YYYY',
                    controller: _dobController,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, color: AppColours.primary),
                      onPressed: () => _selectDate(context),
                    ),
                    onChanged: (val) => context.read<RegistrationBloc>().add(DobChanged(val)),
                  ),
                  SizedBox(height: 20.h),
                  _buildGenderPicker(context, state),
                  SizedBox(height: 20.h),
                  _buildTextField(
                    label: 'MOBILE NUMBER *',
                    hint: 'Enter 10-digit Mobile Number',
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    errorText: _mobileErrorText(state.mobileNumber),
                    onChanged: (val) => context
                        .read<RegistrationBloc>()
                        .add(MobileNumberChanged(val)),
                  ),
                  SizedBox(height: 20.h),
                  _buildAddressProofDropdown(context, state),
                  if (state.addressProofType.isNotEmpty) ...[
                    SizedBox(height: 20.h),
                    Text(
                      'UPLOAD ${AddressProofTypes.labelFor(state.addressProofType).toUpperCase()} *',
                      style: CustomTextStyles.montserratBold.copyWith(color: AppColours.primary, fontSize: 12),
                    ),
                    SizedBox(height: 8.h),
                    _buildDualDocumentUpload(
                      context: context,
                      paths: state.addressProofImages,
                      remoteUrls: state.addressProofUrls,
                      uploading: state.addressProofUploading,
                      emptyLabel0: 'Front side',
                      emptyLabel1: 'Back side',
                      onPick: (slot, path) {
                        context.read<RegistrationBloc>().add(
                              AddressProofSlotUpdated(slotIndex: slot, path: path),
                            );
                      },
                      onRemove: (slot) {
                        context.read<RegistrationBloc>().add(AddressProofSlotCleared(slot));
                      },
                    ),
                  ],
                  SizedBox(height: 20.h),
                  Text(
                    'DRIVING LICENSE *',
                    style: CustomTextStyles.montserratBold.copyWith(color: AppColours.primary, fontSize: 12),
                  ),
                  SizedBox(height: 8.h),
                  _buildDualDocumentUpload(
                    context: context,
                    paths: state.drivingLicenseImages,
                    remoteUrls: state.drivingLicenseUrls,
                    uploading: state.drivingLicenseUploading,
                    emptyLabel0: 'Front side',
                    emptyLabel1: 'Back side',
                    onPick: (slot, path) {
                      context.read<RegistrationBloc>().add(
                            DrivingLicenseSlotUpdated(slotIndex: slot, path: path),
                          );
                    },
                    onRemove: (slot) {
                      context.read<RegistrationBloc>().add(DrivingLicenseSlotCleared(slot));
                    },
                  ),
                  SizedBox(height: 20.h),
                  _buildTextField(
                    label: 'ENTER CURRENT ADDRESS',
                    hint: 'Enter your current address',
                    controller: _addressController,
                    maxLines: 3,
                    onChanged: (val) => context.read<RegistrationBloc>().add(CurrentAddressChanged(val)),
                  ),
                  SizedBox(height: 48.h),
                  SizedBox(
                    width: double.infinity,
                    height: 56.h,
                    child: ElevatedButton(
                      onPressed: _canSubmit(state)
                          ? () => context.read<RegistrationBloc>().add(RegistrationSubmitted())
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColours.primary,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.grey,
                        disabledForegroundColor: Colors.black,
 
                      ),
                      child: Text(
                        state.status == RegistrationStatus.loading
                            ? 'SUBMITTING...'
                            : state.isUploadingFiles
                                ? 'UPLOADING IMAGES...'
                                : (widget.isEditing ? 'SAVE CHANGES' : 'SUBMIT'),
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w700, // 700 Bold
                          fontSize: 16,
                          height: 28 / 16, // line height
                          color: Color(0xFF0F0F14), // exact color
                        ),
                      ),
                    ),
                  ),                ],
              ),
            ),
                if (widget.isEditing && state.status == RegistrationStatus.loading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColours.primary),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfilePhotoPicker(BuildContext context, RegistrationState state) {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 120.h,
                width: 120.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColours.primary, width: 1),
                  color: Colors.black87,
                ),
                child: ClipOval(
                  child: _buildProfileImage(state),
                ),
              ),
              if (state.profilePhotoUploading)
                Container(
                  height: 120.h,
                  width: 120.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColours.primary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
          TextButton.icon(
            onPressed: state.profilePhotoUploading
                ? null
                : () => _showImageSourceDialog(context, (path) {
                      context.read<RegistrationBloc>().add(ProfilePhotoUpdated(path));
                    }),
            icon: SvgPicture.asset(
              IconConstant.iconEdit, // your svg path
              height: 16,
              width: 16,
              colorFilter: ColorFilter.mode(
                AppColours.primary,
                BlendMode.srcIn,
              ),
            ),


            label: Text(state.profilePhoto == null ? 'Upload Photo' : 'Change Photo',
                style: TextStyle(color: AppColours.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage(RegistrationState state) {
    if (state.profilePhoto != null) {
      return Image.file(
        File(state.profilePhoto!),
        fit: BoxFit.cover,
        width: 120.w,
        height: 120.h,
      );
    }
    final url = state.profilePhotoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: 120.w,
        height: 120.h,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.person,
          size: 60,
          color: Colors.white24,
        ),
      );
    }
    return const Icon(Icons.person, size: 60, color: Colors.white24);
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required Function(String) onChanged,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextEditingController? controller,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: CustomTextStyles.montserratBold.copyWith(color: AppColours.primary, fontSize: 12),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          inputFormatters: inputFormatters,
          style: const TextStyle(
            color: AppColours.secondary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColours.hintcolor,
              fontSize: 14,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
            suffixIcon: suffixIcon,
            errorText: errorText,
            errorStyle: TextStyle(
              color: Colors.redAccent,
              fontSize: 11.fSize,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColours.border1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColours.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderPicker(BuildContext context, RegistrationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GENDER *',
          style: CustomTextStyles.montserratBold.copyWith(color: AppColours.primary, fontSize: 12),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            _buildRadioButton(context, 'Male', state.gender == 'Male'),
            SizedBox(width: 20.w),
            _buildRadioButton(context, 'Female', state.gender == 'Female'),
          ],
        ),
      ],
    );
  }

  Widget _buildRadioButton(BuildContext context, String label, bool isSelected) {
    return InkWell(
      onTap: () => context.read<RegistrationBloc>().add(GenderChanged(label)),
      child: Row(
        children: [
          Container(
            height: 20,
            width: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColours.secondary, width: 2),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      height: 10,
                      width: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColours.secondary,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColours.secondary)),
        ],
      ),
    );
  }

  Widget _buildAddressProofRadioDot(bool selected) {
    return Container(
      height: 22,
      width: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColours.secondary, width: 2),
      ),
      child: selected
          ? Center(
              child: Container(
                height: 10,
                width: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColours.secondary,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAddressProofDropdown(BuildContext context, RegistrationState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADDRESS PROOF *',
          style: CustomTextStyles.montserratBold.copyWith(color: AppColours.primary, fontSize: 12),
        ),
        SizedBox(height: 8.h),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _addressProofMenuExpanded = !_addressProofMenuExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColours.primary),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.addressProofType.isEmpty
                          ? 'Select Address proof'
                          : AddressProofTypes.labelFor(state.addressProofType),
                      style: CustomTextStyles.openSansRegular.copyWith(
                        fontSize: 16,
                        color: state.addressProofType.isEmpty ? AppColours.hintcolor : AppColours.secondary,
                      ),
                    ),
                  ),
                  Icon(
                    _addressProofMenuExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: AppColours.primary,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _addressProofMenuExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 8.h),
                    Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F0F14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColours.primary),
                      ),
                      child: Column(
                        children: [
                          for (final option in AddressProofTypes.options)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  context.read<RegistrationBloc>().add(
                                        AddressProofTypeChanged(option.apiValue),
                                      );
                                  setState(() => _addressProofMenuExpanded = false);
                                },
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option.label,
                                          style: CustomTextStyles.openSansRegular.copyWith(
                                            fontSize: 16,
                                            color: AppColours.secondary,
                                          ),
                                        ),
                                      ),
                                      _buildAddressProofRadioDot(
                                        state.addressProofType == option.apiValue,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }


  Widget _buildGoldDocRemoveButton({required VoidCallback onTap}) {
    return Material(
      color: AppColours.primary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.close, color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Widget _buildDualDocumentUpload({
    required BuildContext context,
    required List<String?> paths,
    required List<String?> remoteUrls,
    required List<bool> uploading,
    required String emptyLabel0,
    required String emptyLabel1,
    required void Function(int slotIndex, String path) onPick,
    required void Function(int slotIndex) onRemove,
  }) {
    final String? path0 = paths.isNotEmpty ? paths[0] : null;
    final String? path1 = paths.length > 1 ? paths[1] : null;
    final String? url0 = remoteUrls.isNotEmpty ? remoteUrls[0] : null;
    final String? url1 = remoteUrls.length > 1 ? remoteUrls[1] : null;
    final uploading0 = uploading.isNotEmpty && uploading[0];
    final uploading1 = uploading.length > 1 && uploading[1];

    return DottedBorder(
      color: AppColours.primary,
      strokeWidth: 1.5,
      dashPattern: const [6, 4],
      borderType: BorderType.RRect,
      radius: const Radius.circular(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F14),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.all(12.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDocumentSlotCard(
                imagePath: path0,
                imageUrl: url0,
                isUploading: uploading0,
                emptyLabel: emptyLabel0,
                onTapPick: uploading0
                    ? null
                    : () {
                        _showImageSourceDialog(context, (picked) => onPick(0, picked));
                      },
                onRemove: (path0 != null || url0 != null) && !uploading0
                    ? () => onRemove(0)
                    : null,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildDocumentSlotCard(
                imagePath: path1,
                imageUrl: url1,
                isUploading: uploading1,
                emptyLabel: emptyLabel1,
                onTapPick: uploading1
                    ? null
                    : () {
                        _showImageSourceDialog(context, (picked) => onPick(1, picked));
                      },
                onRemove: (path1 != null || url1 != null) && !uploading1
                    ? () => onRemove(1)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSlotCard({
    required String? imagePath,
    required String? imageUrl,
    required bool isUploading,
    required String emptyLabel,
    required VoidCallback? onTapPick,
    VoidCallback? onRemove,
  }) {
    final hasImage = imagePath != null ||
        (imageUrl != null && imageUrl.trim().isNotEmpty);

    return AspectRatio(
      aspectRatio: 0.80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: !hasImage
            ? Material(
                color: const Color(0xFF3A3A42),
                child: InkWell(
                  onTap: onTapPick,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isUploading)
                        const CircularProgressIndicator(
                          color: AppColours.primary,
                          strokeWidth: 2,
                        )
                      else
                        SvgPicture.asset(IconConstant.upload),
                      SizedBox(height: 8.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Text(
                          isUploading ? 'Uploading...' : emptyLabel,
                          textAlign: TextAlign.center,
                          style: CustomTextStyles.openSansRegular.copyWith(
                            color: AppColours.hintcolor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Material(
                    color: const Color(0xFF0F0F14),
                    child: InkWell(
                      onTap: onTapPick,
                      child: imagePath != null
                          ? Image.file(
                              File(imagePath),
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            ),
                    ),
                  ),
                  if (isUploading)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColours.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  if (onRemove != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _buildGoldDocRemoveButton(onTap: onRemove),
                    ),
                ],
              ),
      ),
    );
  }
}
