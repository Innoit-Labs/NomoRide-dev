import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/profile/data/models/delivery_partner_profile.dart';

class ProfileRepository {
  ProfileRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static DeliveryPartnerProfile? _cachedProfile;

  static DeliveryPartnerProfile? get cachedProfile => _cachedProfile;

  /// External partners (`inhouse_delivery_partner == 0`) see partner earning.
  /// Defaults to visible until profile is loaded.
  static bool get showsPartnerEarning =>
      _cachedProfile?.showsPartnerEarning ?? true;

  static void clearCache() {
    _cachedProfile = null;
  }

  Future<DeliveryPartnerProfile> getProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProfile != null) {
      debugPrint('========== PROFILE ==========');
      debugPrint('API called: no');
      debugPrint('Image URL: ${_cachedProfile!.profilePhotoUrl}');
      debugPrint('Username: ${_cachedProfile!.fullName}');
      debugPrint('Source: Cache');
      debugPrint('=============================');
      return _cachedProfile!;
    }

    _ensureLoggedIn();
    final uri = ApiConfig.profileUri;
    _logRequest('GET', uri);

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          ...AuthSession.authHeaders,
        },
      );

      _logResponse(response.statusCode, response.body);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if (response.statusCode == 200 && success) {
        final data = json?['data'];
        if (data is Map<String, dynamic>) {
          final profile = DeliveryPartnerProfile.fromJson(data);
          _cachedProfile = profile;
          debugPrint('========== PROFILE ==========');
          debugPrint('API called: yes');
          debugPrint('Image URL: ${profile.profilePhotoUrl}');
          debugPrint('Username: ${profile.fullName}');
          debugPrint('Source: API');
          debugPrint('=============================');
          return profile;
        }
        throw const ApiException('Invalid profile response from server.');
      }

      throw ApiException(
        json?['message'] as String? ??
            'Failed to load profile (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  Future<DeliveryPartnerProfile> updateBankAccountDetails(
    Map<String, dynamic> payload,
  ) async {
    _ensureLoggedIn();
    final uri = ApiConfig.updateBankAccountDetailsUri;
    final body = jsonEncode(payload);
    _logRequest('PUT', uri, body: body);

    try {
      final response = await _client.put(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: body,
      );

      _logResponse(response.statusCode, response.body);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          success) {
        final data = json?['data'];
        if (data is Map<String, dynamic>) {
          final profile = DeliveryPartnerProfile.fromJson(data);
          _cachedProfile = profile;
          return profile;
        }
        clearCache();
        return await getProfile(forceRefresh: true);
      }

      throw ApiException(
        _extractErrorMessage(json, response.body) ??
            'Failed to update bank details (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  Future<DeliveryPartnerProfile> updateProfile(
    DeliveryPartnerProfile profile,
  ) async {
    _ensureLoggedIn();
    final uri = ApiConfig.updateProfileUri;
    final body = jsonEncode(profile.toUpdateJson());
    _logRequest('PUT', uri, body: body);

    try {
      final response = await _client.put(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: body,
      );

      _logResponse(response.statusCode, response.body);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          success) {
        final data = json?['data'];
        if (data is Map<String, dynamic>) {
          final updated = DeliveryPartnerProfile.fromJson(data);
          _cachedProfile = updated;
          return updated;
        }
        clearCache();
        return profile;
      }

      throw ApiException(
        _extractErrorMessage(json, response.body) ??
            'Failed to update profile (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  Future<void> deleteAccount() async {
    _ensureLoggedIn();
    final uri = ApiConfig.deleteAccountUri;
    _logRequest('DELETE', uri);

    try {
      final response = await _client
          .delete(
            uri,
            headers: {
              'Accept': 'application/json',
              ...AuthSession.authHeaders,
            },
          )
          .timeout(const Duration(seconds: 30));

      _logResponse(response.statusCode, response.body);
      final json = _tryParseJson(response.body);

      if (response.statusCode == 401) {
        throw ApiException(
          _extractErrorMessage(json, response.body) ??
              'Session expired. Please login again.',
          statusCode: 401,
        );
      }

      final success = json?['success'] as bool? ?? false;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (json == null || response.body.trim().isEmpty || success) {
          return;
        }
        throw ApiException(
          _extractErrorMessage(json, response.body) ??
              'Failed to delete account (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      throw ApiException(
        _extractErrorMessage(json, response.body) ??
            'Failed to delete account (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } on TimeoutException {
      throw const ApiException('Request timed out. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  static String? _extractErrorMessage(
    Map<String, dynamic>? json,
    String body,
  ) {
    final message = json?['message'];
    if (message != null && message.toString().trim().isNotEmpty) {
      return message.toString();
    }

    final preMatch = RegExp(r'<pre>(.*?)</pre>', dotAll: true).firstMatch(body);
    if (preMatch != null) {
      final text = preMatch.group(1)?.trim();
      if (text != null && text.isNotEmpty) return text;
    }

    return null;
  }

  void _ensureLoggedIn() {
    final token = AuthSession.authToken?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException('Please login to view profile.');
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

  void _logRequest(String method, Uri uri, {String? body}) {
    debugPrint('========== PROFILE API REQUEST ==========');
    debugPrint('$method: $uri');
    if (body != null) debugPrint('Body: $body');
    debugPrint('=========================================');
  }

  void _logResponse(int statusCode, String body) {
    debugPrint('========== PROFILE API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body: $body');
    debugPrint('==========================================');
  }
}
