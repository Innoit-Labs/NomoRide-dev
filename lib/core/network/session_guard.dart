import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/profile/data/profile_repository.dart';
import 'package:nomoride/routes/app_routes.dart';

/// Centralized session expiry / 401 handling for the Delivery Partner app.
class SessionGuard {
  SessionGuard._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _isHandlingUnauthorized = false;

  /// Call after every authenticated API response.
  /// On HTTP 401: clears session/cache and routes to Login.
  static Future<void> ensureAuthorized(http.Response response) async {
    if (response.statusCode != 401) return;

    final message = _readMessage(response.body) ??
        'Session expired. Please login again.';
    await handleUnauthorized(message: message);
    throw ApiException(message, statusCode: 401);
  }

  /// Clears auth state and navigates to Login, clearing the navigation stack.
  static Future<void> handleUnauthorized({String? message}) async {
    if (_isHandlingUnauthorized) return;
    _isHandlingUnauthorized = true;

    try {
      await AuthSession.clear();
      ProfileRepository.clearCache();

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      navigator.pushNamedAndRemoveUntil(
        AppRoutes.loginScreen,
        (route) => false,
      );
    } finally {
      _isHandlingUnauthorized = false;
    }
  }

  /// Explicit logout path used by Profile → Logout.
  static Future<void> logoutToLogin() async {
    await AuthSession.clear();
    ProfileRepository.clearCache();

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushNamedAndRemoveUntil(
      AppRoutes.loginScreen,
      (route) => false,
    );
  }

  static String? _readMessage(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        final text = decoded['message'].toString().trim();
        if (text.isNotEmpty) return text;
      }
    } catch (_) {}
    return null;
  }
}
