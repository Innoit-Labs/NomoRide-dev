import 'package:flutter/foundation.dart';
import 'package:nomoride/core/services/onesignal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  AuthSession._();

  static const _keyAuthToken = 'auth_token';
  static const _keyPartnerId = 'partner_id';
  static const _keyMobileNumber = 'mobile_number';

  static String? authToken;
  static String? partnerId;
  static String? mobileNumber;

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString(_keyAuthToken);
    partnerId = prefs.getString(_keyPartnerId);
    mobileNumber = prefs.getString(_keyMobileNumber);
  }

  static Future<void> save({
    required String token,
    String? partner,
    String? mobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    authToken = token;
    if (partner != null) partnerId = partner;
    if (mobile != null) mobileNumber = mobile;

    await prefs.setString(_keyAuthToken, token);
    if (partner != null) {
      await prefs.setString(_keyPartnerId, partner);
    }
    if (mobile != null) {
      await prefs.setString(_keyMobileNumber, mobile);
    }

    debugPrint('========== AUTH TOKEN ==========');
    debugPrint('authToken: [REDACTED]');
    debugPrint('partnerId: $partnerId');
    debugPrint('mobileNumber: $mobileNumber');
    debugPrint('================================');
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    authToken = null;
    partnerId = null;
    mobileNumber = null;

    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyPartnerId);
    await prefs.remove(_keyMobileNumber);

    await OneSignalService.logout();
  }

  static bool get isLoggedIn =>
      authToken != null && authToken!.trim().isNotEmpty;

  static Map<String, String> get authHeaders {
    final token = authToken?.trim();
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }
}
