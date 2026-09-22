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

  /// Fetches all Delivery Partner policies from
  /// `GET /mobile/v1/policies/delivery-partner`.
  Future<List<AppContent>> getDeliveryPartnerPolicies({
    String fallbackTitle = '',
  }) async {
    final uri = ApiConfig.deliveryPartnerPoliciesUri;
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
        return _parsePoliciesList(
          json,
          fallbackTitle: fallbackTitle,
        );
      }

      throw ApiException(
        json?['message']?.toString() ??
            'Failed to load policies (${response.statusCode})',
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

  /// Loads a single policy by key from the Delivery Partner policies API.
  Future<AppContent> getContentByKey(
    String key, {
    String fallbackTitle = '',
  }) async {
    final policyKey = key.trim();
    if (policyKey.isEmpty) {
      throw const ApiException('Content key is missing.');
    }

    final policies = await getDeliveryPartnerPolicies(
      fallbackTitle: fallbackTitle,
    );

    if (policies.isEmpty) {
      throw const ApiException('No policies available right now.');
    }

    final target = policyKey.toLowerCase();
    for (final policy in policies) {
      final candidate = policy.key.trim().toLowerCase();
      if (candidate == target) {
        return AppContent(
          key: policy.key,
          title: policy.title.trim().isNotEmpty ? policy.title : fallbackTitle,
          body: policy.body,
        );
      }
    }

    // Soft aliases used across older / newer policy_key values.
    final aliases = _keyAliases(target);
    for (final policy in policies) {
      final candidate = policy.key.trim().toLowerCase();
      if (aliases.contains(candidate)) {
        return AppContent(
          key: policy.key,
          title: policy.title.trim().isNotEmpty ? policy.title : fallbackTitle,
          body: policy.body,
        );
      }
    }

    throw ApiException('Policy not found for key "$policyKey".');
  }

  static Set<String> _keyAliases(String key) {
    switch (key) {
      case 'terms':
      case 'terms_conditions':
      case 'terms-and-conditions':
      case 'terms_and_conditions':
        return {
          'terms',
          'terms_conditions',
          'terms-and-conditions',
          'terms_and_conditions',
        };
      case 'privacy':
      case 'privacy_policy':
      case 'privacy-policy':
        return {
          'privacy',
          'privacy_policy',
          'privacy-policy',
        };
      case 'about':
      case 'about_us':
      case 'about-us':
        return {
          'about',
          'about_us',
          'about-us',
        };
      default:
        return {key};
    }
  }

  static List<AppContent> _parsePoliciesList(
    Map<String, dynamic>? json, {
    required String fallbackTitle,
  }) {
    if (json == null) return const [];

    final data = json['data'] ?? json['policies'] ?? json['items'];

    if (data is List) {
      final items = <AppContent>[];
      for (final item in data) {
        if (item is! Map) continue;
        final map = item.map((key, value) => MapEntry(key.toString(), value));
        final content = AppContent.fromJson(
          map,
          fallbackKey: map['policy_key']?.toString() ??
              map['key']?.toString() ??
              '',
          fallbackTitle: fallbackTitle,
        );
        if (content.key.trim().isEmpty && content.body.trim().isEmpty) {
          continue;
        }
        items.add(content);
      }
      return items;
    }

    if (data is Map) {
      final map = data.map((key, value) => MapEntry(key.toString(), value));

      // Nested list forms: { data: { policies: [...] } }
      final nested = map['policies'] ?? map['items'] ?? map['list'];
      if (nested is List) {
        return _parsePoliciesList(
          {'data': nested},
          fallbackTitle: fallbackTitle,
        );
      }

      final content = AppContent.fromJson(
        map,
        fallbackKey: map['policy_key']?.toString() ??
            map['key']?.toString() ??
            'delivery_partner',
        fallbackTitle: fallbackTitle,
      );
      if (content.body.trim().isEmpty && content.key.trim().isEmpty) {
        return const [];
      }
      return [content];
    }

    if (data is String && data.trim().isNotEmpty) {
      return [
        AppContent(
          key: 'delivery_partner',
          title: fallbackTitle,
          body: data.trim(),
        ),
      ];
    }

    // Root-level content fields without a `data` wrapper.
    if (json['content'] != null ||
        json['body'] != null ||
        json['html'] != null ||
        json['policy_html'] != null) {
      return [
        AppContent.fromJson(
          json,
          fallbackKey: 'delivery_partner',
          fallbackTitle: fallbackTitle,
        ),
      ];
    }

    return const [];
  }

  static Map<String, dynamic>? _tryParseJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
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
