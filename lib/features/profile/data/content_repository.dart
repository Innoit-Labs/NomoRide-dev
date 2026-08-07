import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/profile/data/models/app_content.dart';

class ContentRepository {
  ContentRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AppContent> getContentByKey(
    String key, {
    String fallbackTitle = '',
  }) async {
    final policyKey = key.trim();
    if (policyKey.isEmpty) {
      throw const ApiException('Content key is missing.');
    }

    final uri = ApiConfig.contentKeyUri(policyKey);
    _logRequest('GET', uri);

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (AuthSession.isLoggedIn) ...AuthSession.authHeaders,
        },
      );

      _logResponse(response.statusCode, response.body);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? response.statusCode == 200;

      if (response.statusCode == 200 && success) {
        final payload = _contentPayload(json, policyKey);
        if (payload != null) {
          return AppContent.fromJson(
            payload,
            fallbackKey: policyKey,
            fallbackTitle: fallbackTitle,
          );
        }
        throw const ApiException('Invalid content response from server.');
      }

      throw ApiException(
        json?['message'] as String? ??
            'Failed to load content (${response.statusCode})',
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

  static Map<String, dynamic>? _contentPayload(
    Map<String, dynamic>? json,
    String requestedKey,
  ) {
    if (json == null) return null;

    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is List) {
      final target = requestedKey.trim().toLowerCase();
      Map<String, dynamic>? firstItem;

      for (final item in data) {
        if (item is! Map) continue;
        final map = item.map((key, value) => MapEntry(key.toString(), value));
        firstItem ??= map;

        final policyKey = map['policy_key']?.toString().trim().toLowerCase();
        final key = map['key']?.toString().trim().toLowerCase();
        if (policyKey == target || key == target) {
          return map;
        }
      }

      // Fallback so the UI still renders something if key matching fails.
      return firstItem;
    }
    if (data is String && data.trim().isNotEmpty) {
      return {'content': data.trim()};
    }

    if (json['content'] != null ||
        json['body'] != null ||
        json['html'] != null ||
        json['content_html'] != null ||
        json['policy_html'] != null ||
        json['policy_value'] != null ||
        json['text'] != null) {
      return json;
    }

    return null;
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
    debugPrint('========== CONTENT API REQUEST ==========');
    debugPrint('$method: $uri');
    debugPrint('=========================================');
  }

  void _logResponse(int statusCode, String body) {
    debugPrint('========== CONTENT API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body: $body');
    debugPrint('==========================================');
  }
}
