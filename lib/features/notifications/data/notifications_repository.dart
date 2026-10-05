import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/notifications/data/models/notification_model.dart';

class NotificationsRepository {
  NotificationsRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Fetches all notifications for the authenticated delivery partner.
  Future<List<NotificationModel>> getNotifications() async {
    _ensureLoggedIn();
    final uri = ApiConfig.notificationsUri;
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
        final rawData = json?['data'];
        if (rawData is List) {
          return rawData
              .whereType<Map<String, dynamic>>()
              .map(NotificationModel.fromJson)
              .toList();
        } else if (rawData is Map<String, dynamic> && rawData['notifications'] is List) {
          return (rawData['notifications'] as List)
              .whereType<Map<String, dynamic>>()
              .map(NotificationModel.fromJson)
              .toList();
        }
        return [];
      }

      throw ApiException(
        json?['message'] as String? ?? 'Failed to load notifications (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Something went wrong. Please try again: $e');
    }
  }

  /// Clears all notifications for the delivery partner.
  /// Uses DELETE and automatically falls back to POST if DELETE returns 405 Method Not Allowed.
  Future<bool> clearAllNotifications() async {
    _ensureLoggedIn();
    final uri = ApiConfig.clearAllNotificationsUri;
    _logRequest('DELETE', uri);

    try {
      http.Response response = await _client.delete(
        uri,
        headers: {
          'Accept': 'application/json',
          ...AuthSession.authHeaders,
        },
      );

      // Server accepts both DELETE and POST according to spec. If DELETE is disallowed by any proxy/server route, try POST:
      if (response.statusCode == 405) {
        _logRequest('POST (fallback)', uri);
        response = await _client.post(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            ...AuthSession.authHeaders,
          },
        );
      }

      _logResponse(response.statusCode, response.body);
      await SessionGuard.ensureAuthorized(response);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if ((response.statusCode == 200 || response.statusCode == 204) && success) {
        return true;
      }

      throw ApiException(
        json?['message'] as String? ?? 'Failed to clear notifications (${response.statusCode})',
        statusCode: response.statusCode,
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Something went wrong. Please try again: $e');
    }
  }

  void _ensureLoggedIn() {
    if (!AuthSession.hasValidSession) {
      throw const ApiException('Please login to view notifications.');
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

  void _logRequest(String method, Uri uri) {
    debugPrint('========== NOTIFICATIONS API REQUEST ==========');
    debugPrint('$method: $uri');
    debugPrint('===============================================');
  }

  void _logResponse(int statusCode, String body) {
    debugPrint('========== NOTIFICATIONS API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body:');
    try {
      final decoded = jsonDecode(body);
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      for (final line in pretty.split('\n')) {
        debugPrint(line);
      }
    } catch (_) {
      final pattern = RegExp('.{1,800}');
      for (final match in pattern.allMatches(body)) {
        debugPrint(match.group(0));
      }
    }
    developer.log(body, name: 'NOTIFICATIONS_API');
    debugPrint('================================================');
  }
}
