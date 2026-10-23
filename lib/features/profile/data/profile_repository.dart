import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/profile/data/models/delivery_partner_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileRepository {
  ProfileRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _keyIsOnline = 'dp_is_online_status';
  static DeliveryPartnerProfile? _cachedProfile;
  static bool? _persistedIsOnline;

  static DeliveryPartnerProfile? get cachedProfile => _cachedProfile;

  /// The delivery partner's current availability status:
  /// - Returns the persisted status if saved in persistent storage (SharedPreferences).
  /// - Defaults to `false` (Offline) for fresh installations (when no status has ever been saved).
  static bool get currentOnlineStatus => _persistedIsOnline ?? false;

  /// Whether a status has ever been explicitly saved in persistent storage.
  static bool get hasSavedStatus => _persistedIsOnline != null;

  /// Restores online status from persistent storage (SharedPreferences).
  static Future<bool> restoreOnlineStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_keyIsOnline)) {
        _persistedIsOnline = prefs.getBool(_keyIsOnline);
      } else {
        _persistedIsOnline = null; // fresh install: no status has ever been saved
      }
      if (_cachedProfile != null) {
        _cachedProfile =
            _cachedProfile!.copyWith(isOnline: currentOnlineStatus);
      }
    } catch (_) {}
    return currentOnlineStatus;
  }

  /// Persists the online status to SharedPreferences and updates in-memory cache.
  static Future<void> saveOnlineStatus(bool online) async {
    _persistedIsOnline = online;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsOnline, online);
    } catch (_) {}
    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(isOnline: online);
    }
  }

  /// Clears persisted status (used in tests or fresh install reset).
  static Future<void> clearPersistedStatus() async {
    _persistedIsOnline = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyIsOnline);
    } catch (_) {}
  }

  /// External partners (`inhouse_delivery_partner == 0`) see partner earning.
  /// Defaults to visible until profile is loaded.
  static bool get showsPartnerEarning =>
      _cachedProfile?.showsPartnerEarning ?? true;

  static void clearCache() {
    _cachedProfile = null;
  }

  Future<DeliveryPartnerProfile> getProfile({bool forceRefresh = false}) async {
    if (!AuthSession.hasValidSession) {
      clearCache();
      throw const ApiException('Please login to view profile.');
    }

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
      await SessionGuard.ensureAuthorized(response);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if (response.statusCode == 200 && success) {
        final data = json?['data'];
        if (data is Map<String, dynamic>) {
          var profile = DeliveryPartnerProfile.fromJson(data);
          // Always preserve the saved availability status across API refreshes.
          // Do not automatically switch between Online and Offline on API refresh.
          profile = profile.copyWith(isOnline: currentOnlineStatus);
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

  Future<bool> updateIsOnline(bool isOnline) async {
    _ensureLoggedIn();
    final uri = ApiConfig.updateIsOnlineUri;
    final body = jsonEncode({'is_online': isOnline});
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
      await SessionGuard.ensureAuthorized(response);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          success) {
        final data = json?['data'];
        bool result = isOnline;
        if (data is Map) {
          final value = data['is_online'] ?? data['isOnline'];
          if (value is bool) {
            result = value;
          } else if (value is num) {
            result = value != 0;
          } else {
            final text = value?.toString().trim().toLowerCase();
            if (text == 'true' || text == '1') result = true;
            if (text == 'false' || text == '0') result = false;
          }
        }
        await saveOnlineStatus(result);
        return result;
      }

      throw ApiException(
        json?['message'] as String? ??
            'Failed to update online status (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (error) {
      if (error is ApiException) rethrow;
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  /// Synchronizes the backend availability status with the saved status.
  /// Does NOT overwrite the saved status with a default value.
  Future<void> syncSavedStatusWithBackend(DeliveryPartnerProfile profile) async {
    final targetStatus = currentOnlineStatus;
    // Only call backend API if the server status is known and differs from our saved status.
    if (profile.isOnline != null && profile.isOnline != targetStatus) {
      try {
        await updateIsOnline(targetStatus);
      } catch (_) {}
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
      await SessionGuard.ensureAuthorized(response);
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
      await SessionGuard.ensureAuthorized(response);
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
      await SessionGuard.ensureAuthorized(response);
      final json = _tryParseJson(response.body);

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
    if (!AuthSession.hasValidSession) {
      clearCache();
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
