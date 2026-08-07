import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/registration/data/models/registration_response.dart';
import 'package:nomoride/features/registration/presentation/bloc/registration_state.dart';

class DeliveryPartnerRepository {
  DeliveryPartnerRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<RegistrationResponse> registerDeliveryPartner(
    RegistrationState state,
  ) async {
    final payload = _buildJsonPayload(state);
    final uri = ApiConfig.createDeliveryPartnerUri;

    _logRequest(uri, payload);

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: jsonEncode(payload),
      );

      _logResponse(response.statusCode, response.body);

      final body = _tryParseJson(response.body);
      final statusCode = response.statusCode;

      if (body != null) {
        final parsed = RegistrationResponse.fromJson(body);

        debugPrint('========== REGISTRATION PARSED IDS ==========');
        debugPrint('waitlisted: ${parsed.waitlisted}');
        debugPrint('underReview: ${parsed.underReview}');
        debugPrint('reference_id: ${parsed.referenceId}');
        debugPrint('waitlist_number: ${parsed.waitlistNumber}');
        debugPrint('=============================================');

        // Fresh registration / waitlist success.
        if ((statusCode == 200 || statusCode == 201) &&
            (parsed.success || parsed.waitlisted)) {
          return parsed;
        }

        // Duplicate submit while documents are still under review.
        if (parsed.underReview) {
          return parsed;
        }
      }

      final message = body?['message'] as String? ??
          'Registration failed ($statusCode)';
      throw ApiException(message, statusCode: statusCode);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  Map<String, dynamic> _buildJsonPayload(RegistrationState state) {
    final mobile = state.mobileNumber.trim();
    final fullName = state.fullName.trim();
    final apiDob = _toApiDate(state.dob);

    final addressProofType = state.addressProofType.trim();

    final payload = <String, dynamic>{
      'profilePhone': mobile,
      'fullName': fullName,
      'full_name': fullName,
      'mobileNumber': mobile,
      'gender': state.gender.trim(),
      'addressProofType': addressProofType,
      'address_proof_type': addressProofType,
      'currentAddress': state.currentAddress.trim(),
      'current_address': state.currentAddress.trim(),
    };

    if (apiDob != null) {
      payload['dateOfBirth'] = apiDob;
      payload['date_of_birth'] = apiDob;
    }

    _attachUrl(payload, 'profilePhoto', state.profilePhotoUrl);
    _attachUrl(payload, 'profile_photo', state.profilePhotoUrl);
    _attachUrl(
      payload,
      'addressProofImage',
      _urlAt(state.addressProofUrls, 0),
    );
    _attachUrl(
      payload,
      'address_proof_image',
      _urlAt(state.addressProofUrls, 0),
    );
    _attachUrl(
      payload,
      'addressProofBackImage',
      _urlAt(state.addressProofUrls, 1),
    );
    _attachUrl(
      payload,
      'address_proof_back_image',
      _urlAt(state.addressProofUrls, 1),
    );
    _attachUrl(
      payload,
      'drivingLicenseImage',
      _urlAt(state.drivingLicenseUrls, 0),
    );
    _attachUrl(
      payload,
      'driving_license_image',
      _urlAt(state.drivingLicenseUrls, 0),
    );
    _attachUrl(
      payload,
      'drivingLicenseBackImage',
      _urlAt(state.drivingLicenseUrls, 1),
    );
    _attachUrl(
      payload,
      'driving_license_back_image',
      _urlAt(state.drivingLicenseUrls, 1),
    );

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

  static String? _urlAt(List<String?> urls, int index) {
    if (index < 0 || index >= urls.length) return null;
    return urls[index];
  }

  static String? _toApiDate(String value) {
    final parts = value.trim().split('/');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;

    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  static Map<String, dynamic>? _tryParseJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  void _logRequest(Uri uri, Map<String, dynamic> payload) {
    debugPrint('========== REGISTRATION API REQUEST ==========');
    debugPrint('URL: $uri');
    debugPrint('Method: POST');
    debugPrint('Content-Type: application/json');
    debugPrint('Auth: ${AuthSession.isLoggedIn ? 'present' : 'none'}');
    debugPrint('Body: ${jsonEncode(payload)}');
    debugPrint('==============================================');
  }

  void _logResponse(int statusCode, String body) {
    debugPrint('========== REGISTRATION API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body: $body');
    debugPrint('===============================================');
  }
}
