import 'package:nomoride/features/registration/data/address_proof_type.dart';

class DeliveryPartnerProfile {
  const DeliveryPartnerProfile({
    this.id,
    this.fullName = '',
    this.mobileNumber = '',
    this.gender = 'Male',
    this.dateOfBirth = '',
    this.addressProofType = '',
    this.currentAddress = '',
    this.profilePhotoUrl,
    this.addressProofImageUrl,
    this.addressProofBackImageUrl,
    this.drivingLicenseImageUrl,
    this.drivingLicenseBackImageUrl,
    this.upiId,
    this.bankAccountNumber,
    this.bankIfsc,
    this.bankAccountName,
    this.inhouseDeliveryPartner = 0,
  });

  final String? id;
  final String fullName;
  final String mobileNumber;
  final String gender;
  final String dateOfBirth;
  final String addressProofType;
  final String currentAddress;
  final String? profilePhotoUrl;
  final String? addressProofImageUrl;
  final String? addressProofBackImageUrl;
  final String? drivingLicenseImageUrl;
  final String? drivingLicenseBackImageUrl;
  final String? upiId;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? bankAccountName;

  /// `0` = external (show partner earning), `1` = in-house (hide partner earning).
  final int inhouseDeliveryPartner;

  bool get isInhouseDeliveryPartner => inhouseDeliveryPartner == 1;

  /// External partners see partner earning; in-house partners do not.
  bool get showsPartnerEarning => !isInhouseDeliveryPartner;

  bool get hasBankDetails =>
      (bankAccountName ?? '').trim().isNotEmpty &&
      (bankAccountNumber ?? '').trim().isNotEmpty &&
      (bankIfsc ?? '').trim().isNotEmpty;

  bool get hasUpiDetails => (upiId ?? '').trim().isNotEmpty;

  bool get hasPaymentDetails => hasBankDetails || hasUpiDetails;

  String get displayDob => _toDisplayDate(dateOfBirth);

  String get addressProofLabel =>
      AddressProofTypes.labelFor(addressProofType);

  static String _toDisplayDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.contains('/')) return trimmed;

    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;

    final date = parsed.toUtc();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String _toApiDate(String value) {
    final parts = value.trim().split('/');
    if (parts.length != 3) return value.trim();

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return value.trim();

    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toUpdateJson() {
    final apiDob = dateOfBirth.contains('/')
        ? _toApiDate(dateOfBirth)
        : dateOfBirth.trim();

    final payload = <String, dynamic>{
      'full_name': fullName.trim(),
      'mobile_number': mobileNumber.trim(),
      'gender': gender.trim(),
      'current_address': currentAddress.trim(),
    };

    if (apiDob.isNotEmpty) {
      payload['date_of_birth'] = apiDob;
    }

    final addressProofType = this.addressProofType.trim();
    if (addressProofType.isNotEmpty) {
      payload['address_proof_type'] = addressProofType;
    }

    _attachUrl(payload, 'profile_photo', profilePhotoUrl);
    _attachUrl(payload, 'address_proof_image', addressProofImageUrl);
    _attachUrl(payload, 'address_proof_back_image', addressProofBackImageUrl);
    _attachUrl(payload, 'driving_license_image', drivingLicenseImageUrl);
    _attachUrl(payload, 'driving_license_back_image', drivingLicenseBackImageUrl);

    return payload;
  }

  static void _attachUrl(
    Map<String, dynamic> payload,
    String key,
    String? url,
  ) {
    final value = url?.trim();
    if (value != null && value.isNotEmpty) {
      payload[key] = value;
    }
  }

  factory DeliveryPartnerProfile.fromJson(Map<String, dynamic> json) {
    return DeliveryPartnerProfile(
      id: _readString(json['id']),
      fullName: _readString(json['fullName'] ?? json['full_name']) ?? '',
      mobileNumber: _readString(
            json['mobileNumber'] ??
                json['mobile_number'] ??
                json['profilePhone'] ??
                json['profile_phone'],
          ) ??
          '',
      gender: _readString(json['gender']) ?? 'Male',
      dateOfBirth: _readString(
            json['dateOfBirth'] ??
                json['date_of_birth'] ??
                json['dob'],
          ) ??
          '',
      addressProofType: _readString(
            json['addressProofType'] ?? json['address_proof_type'],
          ) ??
          '',
      currentAddress: _readString(
            json['currentAddress'] ?? json['current_address'],
          ) ??
          '',
      profilePhotoUrl: _readString(
        json['profilePhoto'] ??
            json['profile_photo'] ??
            json['profilePhotoUrl'] ??
            json['profile_photo_url'],
      ),
      addressProofImageUrl: _readAddressProofFront(json),
      addressProofBackImageUrl: _readAddressProofBack(json),
      drivingLicenseImageUrl: _readString(
        json['drivingLicenseImage'] ?? json['driving_license_image'],
      ),
      drivingLicenseBackImageUrl: _readString(
        json['drivingLicenseBackImage'] ??
            json['driving_license_back_image'],
      ),
      upiId: _readString(json['upi_id'] ?? json['upiId']),
      bankAccountNumber: _readString(
        json['bank_account_number'] ?? json['bankAccountNumber'],
      ),
      bankIfsc: _readString(json['bank_ifsc'] ?? json['bankIfsc']),
      bankAccountName: _readString(
        json['bank_account_name'] ?? json['bankAccountName'],
      ),
      inhouseDeliveryPartner: _readInt(
            json['inhouse_delivery_partner'] ??
                json['inhouseDeliveryPartner'] ??
                json['in_house_delivery_partner'],
          ) ??
          0,
    );
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static String? _readAddressProofFront(Map<String, dynamic> json) {
    final images = json['address_proof_images'] ?? json['addressProofImages'];
    if (images is List && images.isNotEmpty) {
      return _readString(images[0]);
    }

    return _readString(
      json['addressProofImage'] ??
          json['address_proof_image'] ??
          json['address_proof_front_image'] ??
          json['addressProofFrontImage'],
    );
  }

  static String? _readAddressProofBack(Map<String, dynamic> json) {
    final images = json['address_proof_images'] ?? json['addressProofImages'];
    if (images is List && images.length > 1) {
      return _readString(images[1]);
    }

    return _readString(
      json['addressProofBackImage'] ??
          json['address_proof_back_image'] ??
          json['addressProofImageBack'] ??
          json['address_proof_image_back'],
    );
  }
}
