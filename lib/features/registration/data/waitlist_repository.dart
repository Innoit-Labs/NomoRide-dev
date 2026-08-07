import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/registration/data/models/registration_response.dart';
import 'package:nomoride/features/registration/data/models/waitlist_status_model.dart';
import 'package:nomoride/features/registration/presentation/bloc/registration_state.dart';

class WaitlistRepository {
  WaitlistRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WaitlistStatusModel> getStatus(String idOrNumber) async {
    final lookup = idOrNumber.trim();
    if (lookup.isEmpty) {
      throw const ApiException('Waitlist lookup id is missing.');
    }

    final uri = ApiConfig.waitlistStatusUri(lookup);
    _logStatusRequest(uri);

    try {
      final response = await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );

      _logStatusResponse(response.statusCode, response.body);

      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          success &&
          json != null) {
        return WaitlistStatusModel.fromJson(json);
      }

      final message = json?['message'] as String? ??
          'Unable to fetch waitlist status (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  /// PUT /waitlist/reupload/:idOrNumber as multipart/form-data.
  Future<RegistrationResponse> reuploadDocuments({
    required String idOrNumber,
    required RegistrationState state,
  }) async {
    final lookup = idOrNumber.trim();
    if (lookup.isEmpty) {
      throw const ApiException(
        'Waitlist number is missing. Cannot re-upload documents.',
      );
    }

    final uri = ApiConfig.waitlistReuploadUri(lookup);
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Accept'] = 'application/json';
    request.headers.addAll(AuthSession.authHeaders);

    _addTextFields(request, state);
    await _attachLatestFiles(request, state);

    debugPrint('========== WAITLIST REUPLOAD API REQUEST ==========');
    debugPrint('URL: $uri');
    debugPrint('Method: PUT');
    debugPrint('Fields: ${request.fields}');
    debugPrint(
      'Files: ${request.files.map((f) => '${f.field}:${f.filename}').toList()}',
    );
    debugPrint('===================================================');

    try {
      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);

      debugPrint('========== WAITLIST REUPLOAD API RESPONSE ==========');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body: ${response.body}');
      debugPrint('====================================================');

      final json = _tryParseJson(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          json != null) {
        final success = json['success'] as bool? ?? false;
        if (success) {
          return RegistrationResponse.fromJson(json);
        }
      }

      final message = json?['message'] as String? ??
          'Document re-upload failed (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  void _addTextFields(
    http.MultipartRequest request,
    RegistrationState state,
  ) {
    final mobile = state.mobileNumber.trim();
    final fullName = state.fullName.trim();
    final addressProofType = state.addressProofType.trim();
    final apiDob = _toApiDate(state.dob);

    void field(String key, String? value) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) {
        request.fields[key] = text;
      }
    }

    field('fullName', fullName);
    field('full_name', fullName);
    field('mobileNumber', mobile);
    field('profilePhone', mobile);
    field('gender', state.gender.trim());
    field('currentAddress', state.currentAddress.trim());
    field('current_address', state.currentAddress.trim());
    field('addressProofType', addressProofType);
    field('address_proof_type', addressProofType);

    if (apiDob != null) {
      field('dateOfBirth', apiDob);
      field('date_of_birth', apiDob);
    }

    // Keep existing remote URLs when the user did not replace a file.
    field('profilePhotoUrl', state.profilePhotoUrl);
    field('profile_photo', state.profilePhotoUrl);
    field('addressProofImageUrl', _urlAt(state.addressProofUrls, 0));
    field('address_proof_image', _urlAt(state.addressProofUrls, 0));
    field('addressProofBackImageUrl', _urlAt(state.addressProofUrls, 1));
    field('address_proof_back_image', _urlAt(state.addressProofUrls, 1));
    field('drivingLicenseImageUrl', _urlAt(state.drivingLicenseUrls, 0));
    field('driving_license_image', _urlAt(state.drivingLicenseUrls, 0));
    field('drivingLicenseBackImageUrl', _urlAt(state.drivingLicenseUrls, 1));
    field('driving_license_back_image', _urlAt(state.drivingLicenseUrls, 1));
  }

  Future<void> _attachLatestFiles(
    http.MultipartRequest request,
    RegistrationState state,
  ) async {
    await _attachFileIfLocal(
      request,
      fieldName: 'profilePhoto',
      localPath: state.profilePhoto,
    );
    await _attachFileIfLocal(
      request,
      fieldName: 'addressProofImage',
      localPath: _pathAt(state.addressProofImages, 0),
    );
    await _attachFileIfLocal(
      request,
      fieldName: 'addressProofBackImage',
      localPath: _pathAt(state.addressProofImages, 1),
    );
    await _attachFileIfLocal(
      request,
      fieldName: 'drivingLicenseImage',
      localPath: _pathAt(state.drivingLicenseImages, 0),
    );
    await _attachFileIfLocal(
      request,
      fieldName: 'drivingLicenseBackImage',
      localPath: _pathAt(state.drivingLicenseImages, 1),
    );
  }

  Future<void> _attachFileIfLocal(
    http.MultipartRequest request, {
    required String fieldName,
    required String? localPath,
  }) async {
    final path = localPath?.trim();
    if (path == null || path.isEmpty) return;
    if (path.startsWith('http://') || path.startsWith('https://')) return;

    final file = File(path);
    if (!await file.exists()) return;

    final fileName = path.split(Platform.pathSeparator).last;
    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        path,
        filename: fileName,
        contentType: MediaType.parse(_mimeTypeFor(fileName)),
      ),
    );
  }

  static String? _pathAt(List<String?> paths, int index) {
    if (index < 0 || index >= paths.length) return null;
    return paths[index];
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

  static String _mimeTypeFor(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  static Map<String, dynamic>? _tryParseJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  void _logStatusRequest(Uri uri) {
    debugPrint('========== WAITLIST STATUS API REQUEST ==========');
    debugPrint('URL: $uri');
    debugPrint('Method: GET');
    debugPrint('=================================================');
  }

  void _logStatusResponse(int statusCode, String body) {
    debugPrint('========== WAITLIST STATUS API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body: $body');
    debugPrint('==================================================');
  }
}
