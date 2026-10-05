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

  /// Global reactive notifiers for unread notification status
  static final ValueNotifier<bool> hasUnreadNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  /// Updates reactive unread notifiers based on a list of notifications
  static void updateUnreadStatus(List<NotificationModel> notifications) {
    final unreadCount = notifications.where((n) => !n.isRead).length;
    unreadCountNotifier.value = unreadCount;
    hasUnreadNotifier.value = unreadCount > 0;
  }

  /// Clears reactive unread state locally
  static void markAllLocallyRead() {
    unreadCountNotifier.value = 0;
    hasUnreadNotifier.value = false;
  }

  /// Silently checks unread notifications and updates [hasUnreadNotifier].
  Future<bool> checkUnreadStatus() async {
    if (!AuthSession.hasValidSession) {
      hasUnreadNotifier.value = false;
      unreadCountNotifier.value = 0;
      return false;
    }
    try {
      final list = await getNotifications();
      return list.any((n) => !n.isRead);
    } catch (_) {
      return hasUnreadNotifier.value;
    }
  }

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
        List<NotificationModel> notifications = [];
        final rawData = json?['data'];
        if (rawData is List) {
          notifications = rawData
              .whereType<Map<String, dynamic>>()
              .map(NotificationModel.fromJson)
              .toList();
        } else if (rawData is Map<String, dynamic> && rawData['notifications'] is List) {
          notifications = (rawData['notifications'] as List)
              .whereType<Map<String, dynamic>>()
              .map(NotificationModel.fromJson)
              .toList();
        }
        updateUnreadStatus(notifications);
        return notifications;
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

  /// Marks one or more notifications as read for the logged-in Delivery Partner.
  ///
  /// Endpoint: `PUT /mobile/v1/delivery_partners/notifications/mark-read`
  ///
  /// Headers:
  /// ```http
  /// Authorization: Bearer <DELIVERY_PARTNER_JWT_TOKEN>
  /// Content-Type: application/json
  /// ```
  /// Body:
  /// ```json
  /// { "notificationIds": ["..."] }
  /// ```
  Future<bool> markNotificationsAsRead(List<String> notificationIds) async {
    _ensureLoggedIn();
    final validIds = notificationIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    if (validIds.isEmpty) return true;

    final uri = ApiConfig.markReadNotificationsUri;
    _logRequest('PUT', uri);

    final payload = jsonEncode({'notificationIds': validIds});

    try {
      final response = await _client.put(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: payload,
      );

      _logResponse(response.statusCode, response.body);
      await SessionGuard.ensureAuthorized(response);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? (response.statusCode >= 200 && response.statusCode < 300);

      if (response.statusCode == 200 && success) {
        final currentCount = unreadCountNotifier.value;
        final newCount = (currentCount - validIds.length).clamp(0, 999999);
        unreadCountNotifier.value = newCount;
        hasUnreadNotifier.value = newCount > 0;
        return true;
      }

      throw ApiException(
        json?['message'] as String? ?? 'Failed to mark notifications as read (${response.statusCode})',
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
        markAllLocallyRead();
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
