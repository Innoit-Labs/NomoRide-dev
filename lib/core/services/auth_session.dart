import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nomoride/core/services/onesignal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  AuthSession._();

  static const _keyAuthToken = 'auth_token';
  static const _keyPartnerId = 'partner_id';
  static const _keyMobileNumber = 'mobile_number';
  static const _keyRefreshToken = 'refresh_token';

  static String? authToken;
  static String? partnerId;
  static String? mobileNumber;
  static String? refreshToken;

  /// Restores session from disk and clears it if the access token is expired.
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString(_keyAuthToken);
    partnerId = prefs.getString(_keyPartnerId);
    mobileNumber = prefs.getString(_keyMobileNumber);
    refreshToken = prefs.getString(_keyRefreshToken);

    if (!_hasNonEmptyToken) {
      await _clearMemoryOnly();
      return;
    }

    if (isAccessTokenExpired(authToken!)) {
      debugPrint('[AuthSession] Stored token expired — clearing session');
      await clear();
    }
  }

  static Future<void> save({
    required String token,
    String? partner,
    String? mobile,
    String? refresh,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      await clear();
      return;
    }

    authToken = trimmed;
    if (partner != null) partnerId = partner;
    if (mobile != null) mobileNumber = mobile;
    if (refresh != null) refreshToken = refresh.trim();

    await prefs.setString(_keyAuthToken, trimmed);
    if (partner != null) {
      await prefs.setString(_keyPartnerId, partner);
    }
    if (mobile != null) {
      await prefs.setString(_keyMobileNumber, mobile);
    }
    if (refresh != null && refresh.trim().isNotEmpty) {
      await prefs.setString(_keyRefreshToken, refresh.trim());
    }

    debugPrint('========== AUTH TOKEN ==========');
    debugPrint('authToken: [REDACTED]');
    debugPrint('partnerId: $partnerId');
    debugPrint('mobileNumber: $mobileNumber');
    debugPrint('hasRefreshToken: ${refreshToken?.trim().isNotEmpty == true}');
    debugPrint('================================');
  }

  /// Clears JWT/session data and related auth prefs. Does not wipe waitlist.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await _clearMemoryOnly();

    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyPartnerId);
    await prefs.remove(_keyMobileNumber);
    await prefs.remove(_keyRefreshToken);

    await OneSignalService.logout();
  }

  static Future<void> _clearMemoryOnly() async {
    authToken = null;
    partnerId = null;
    mobileNumber = null;
    refreshToken = null;
  }

  static bool get _hasNonEmptyToken {
    final token = authToken?.trim();
    return token != null && token.isNotEmpty;
  }

  /// True only when a non-empty, non-expired access token exists.
  static bool get hasValidSession {
    final token = authToken?.trim();
    if (token == null || token.isEmpty) return false;
    return !isAccessTokenExpired(token);
  }

  /// Alias for [hasValidSession] — never treat cached profile as logged-in.
  static bool get isLoggedIn => hasValidSession;

  static Map<String, String> get authHeaders {
    if (!hasValidSession) return const {};
    final token = authToken!.trim();
    return {'Authorization': 'Bearer $token'};
  }

  /// Returns true when [token] is a JWT past `exp` (with small clock skew).
  /// Opaque / non-JWT tokens are treated as not expired locally (server 401 applies).
  static bool isAccessTokenExpired(
    String token, {
    Duration clockSkew = const Duration(seconds: 30),
  }) {
    final parts = token.trim().split('.');
    if (parts.length != 3) {
      // Opaque session token — cannot validate locally.
      return false;
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadJson);
      if (payload is! Map) return true;

      final exp = payload['exp'];
      if (exp is! num) {
        // JWT without exp — treat as valid; rely on API 401.
        return false;
      }

      final expiryUtc = DateTime.fromMillisecondsSinceEpoch(
        (exp * 1000).round(),
        isUtc: true,
      );
      final now = DateTime.now().toUtc().add(clockSkew);
      return !now.isBefore(expiryUtc);
    } catch (error) {
      debugPrint('[AuthSession] Failed to parse JWT exp: $error');
      return true;
    }
  }
}
