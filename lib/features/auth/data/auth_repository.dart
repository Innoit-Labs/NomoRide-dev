import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/features/auth/data/models/otp_session.dart';

class AuthRepository {
  AuthRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<OtpSession> login(String mobileNumber) async {
    final body = await _post(
      uri: ApiConfig.loginUri,
      label: 'LOGIN',
      payload: {'mobileNumber': mobileNumber.trim()},
    );

    final data = _readData(body);
    final userToken = data['userToken']?.toString();
    final partnerId =
        data['partner_id']?.toString() ?? data['partnerId']?.toString();

    if (userToken == null || userToken.isEmpty) {
      throw const ApiException('Invalid login response from server.');
    }
    if (partnerId == null || partnerId.isEmpty) {
      throw const ApiException('Partner ID missing in login response.');
    }

    return OtpSession(
      mobileNumber: mobileNumber.trim(),
      userToken: userToken,
      partnerId: partnerId,
    );
  }

  Future<String> verifyOtp({
    required String userToken,
    required String otp,
    required String partnerId,
  }) async {
    final body = await _post(
      uri: ApiConfig.verifyOtpUri,
      label: 'VERIFY OTP',
      payload: {
        'userToken': userToken,
        'otp': otp.trim(),
        'partnerId': partnerId,
      },
    );

    final data = _readData(body);
    final authToken = data['authToken']?.toString();
    if (authToken == null || authToken.isEmpty) {
      throw const ApiException('Invalid verify OTP response from server.');
    }
    return authToken;
  }

  Future<String> resendOtp({
    required String mobileNumber,
    required String partnerId,
  }) async {
    final body = await _post(
      uri: ApiConfig.resendOtpUri,
      label: 'RESEND OTP',
      payload: {
        'mobileNumber': mobileNumber.trim(),
        'partnerId': partnerId,
      },
    );

    final data = _readData(body);
    final userToken = data['userToken']?.toString();
    if (userToken == null || userToken.isEmpty) {
      throw const ApiException('Invalid resend OTP response from server.');
    }
    return userToken;
  }

  Future<Map<String, dynamic>> _post({
    required Uri uri,
    required String label,
    required Map<String, dynamic> payload,
  }) async {
    _logRequest(label, uri, payload);

    try {
      final response = await _client.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      _logResponse(label, response.statusCode, response.body);

      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          success) {
        return json ?? <String, dynamic>{'success': true};
      }

      final message = json?['message'] as String? ??
          'Request failed (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  static Map<String, dynamic> _readData(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    throw const ApiException('Invalid server response.');
  }

  static Map<String, dynamic>? _tryParseJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  void _logRequest(String label, Uri uri, Map<String, dynamic> payload) {
    debugPrint('========== $label API REQUEST ==========');
    debugPrint('URL: $uri');
    debugPrint('Body: ${jsonEncode(payload)}');
    debugPrint('========================================');
  }

  void _logResponse(String label, int statusCode, String body) {
    debugPrint('========== $label API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body: $body');
    debugPrint('=========================================');
  }
}
