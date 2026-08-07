import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WaitlistSession {
  WaitlistSession._();

  static const _keyWaitlistNumber = 'waitlist_number';
  static const _keyReferenceId = 'waitlist_reference_id';
  static const _keyMobileNumber = 'waitlist_mobile_number';
  static const _keyRegistrationDraft = 'registration_draft_json';

  static String? waitlistNumber;
  static String? referenceId;
  static String? mobileNumber;

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    waitlistNumber = prefs.getString(_keyWaitlistNumber);
    referenceId = prefs.getString(_keyReferenceId);
    mobileNumber = prefs.getString(_keyMobileNumber);

    debugPrint('========== WAITLIST SESSION RESTORE ==========');
    debugPrint('reference_id: $referenceId');
    debugPrint('waitlist_number: $waitlistNumber');
    debugPrint('mobile_number: $mobileNumber');
    debugPrint('=============================================');
  }

  /// Lookup key for `GET /waitlist/status/:id` — always `reference_id` only.
  static String? get statusLookupId {
    final reference = referenceId?.trim();
    if (reference != null && reference.isNotEmpty) return reference;
    return null;
  }

  static Future<void> saveReferenceId(String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    referenceId = trimmed;
    await prefs.setString(_keyReferenceId, trimmed);
  }

  static Future<void> saveWaitlistNumber(String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    waitlistNumber = trimmed;
    await prefs.setString(_keyWaitlistNumber, trimmed);
  }

  static Future<void> saveMobileNumber(String? value) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    mobileNumber = trimmed;
    await prefs.setString(_keyMobileNumber, trimmed);
  }

  /// Persists waitlist identifiers. Null/empty values are skipped (never wipe).
  static Future<void> saveIdentifiers({
    String? waitlistNumberValue,
    String? referenceIdValue,
    String? mobileNumberValue,
  }) async {
    await saveReferenceId(referenceIdValue);
    await saveWaitlistNumber(waitlistNumberValue);
    await saveMobileNumber(mobileNumberValue);

    debugPrint('========== WAITLIST SAVE ==========');
    debugPrint('reference_id: $referenceId');
    debugPrint('waitlist_number: $waitlistNumber');
    debugPrint('mobile_number: $mobileNumber');
    debugPrint('===================================');
  }

  static Future<void> saveFromRegistrationResponse({
    required String? referenceId,
    required String? waitlistNumber,
    required String? mobileNumber,
  }) async {
    await saveReferenceId(referenceId);
    await saveWaitlistNumber(waitlistNumber);
    await saveMobileNumber(mobileNumber);

    debugPrint('========== WAITLIST SAVE ==========');
    debugPrint('reference_id: ${WaitlistSession.referenceId}');
    debugPrint('waitlist_number: ${WaitlistSession.waitlistNumber}');
    debugPrint('mobile_number: ${WaitlistSession.mobileNumber}');
    debugPrint('===================================');
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    waitlistNumber = null;
    referenceId = null;
    mobileNumber = null;

    await prefs.remove(_keyWaitlistNumber);
    await prefs.remove(_keyReferenceId);
    await prefs.remove(_keyMobileNumber);
    await prefs.remove(_keyRegistrationDraft);
  }

  static Future<void> saveRegistrationDraft(
    Map<String, dynamic> draft,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRegistrationDraft, jsonEncode(draft));
  }

  static Future<Map<String, dynamic>?> loadRegistrationDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyRegistrationDraft);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  static Future<void> saveFromApiFormData(Map<String, dynamic>? formData) async {
    if (formData == null || formData.isEmpty) return;
    await saveRegistrationDraft(_normalizeDraft(formData));
  }

  static Map<String, dynamic> draftFromRegistrationState({
    required String fullName,
    required String dob,
    required String gender,
    required String mobileNumber,
    required String addressProofType,
    required String currentAddress,
    String? profilePhotoUrl,
    List<String?>? addressProofUrls,
    List<String?>? drivingLicenseUrls,
  }) {
    return {
      'fullName': fullName,
      'dob': dob,
      'gender': gender,
      'mobileNumber': mobileNumber,
      'addressProofType': addressProofType,
      'currentAddress': currentAddress,
      'profilePhotoUrl': profilePhotoUrl,
      'addressProofUrls': addressProofUrls ?? const [null, null],
      'drivingLicenseUrls': drivingLicenseUrls ?? const [null, null],
    };
  }

  static Map<String, dynamic> _normalizeDraft(Map<String, dynamic> formData) {
    String? readString(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      return text.isEmpty ? null : text;
    }

    String readGender() {
      return readString(formData['gender']) ?? 'Male';
    }

    String readDob() {
      final apiDob = readString(
        formData['dateOfBirth'] ??
            formData['date_of_birth'] ??
            formData['dob'],
      );
      if (apiDob == null) return '';

      final parts = apiDob.split('-');
      if (parts.length != 3) return apiDob;

      final year = parts[0];
      final month = parts[1];
      final day = parts[2];
      return '$day/$month/$year';
    }

    List<String?> readUrlPair(String frontKey, String backKey) {
      return [
        readString(formData[frontKey]),
        readString(formData[backKey]),
      ];
    }

    return {
      'fullName': readString(formData['fullName'] ?? formData['full_name']) ??
          '',
      'dob': readDob(),
      'gender': readGender(),
      'mobileNumber': readString(
            formData['mobileNumber'] ??
                formData['mobile_number'] ??
                formData['profilePhone'] ??
                formData['profile_phone'],
          ) ??
          '',
      'addressProofType': readString(
            formData['addressProofType'] ?? formData['address_proof_type'],
          ) ??
          '',
      'currentAddress': readString(
            formData['currentAddress'] ?? formData['current_address'],
          ) ??
          '',
      'profilePhotoUrl': readString(
        formData['profilePhoto'] ?? formData['profile_photo'],
      ),
      'addressProofUrls': readUrlPair(
        'addressProofImage',
        'addressProofBackImage',
      ),
      'drivingLicenseUrls': readUrlPair(
        'drivingLicenseImage',
        'drivingLicenseBackImage',
      ),
    };
  }
}
