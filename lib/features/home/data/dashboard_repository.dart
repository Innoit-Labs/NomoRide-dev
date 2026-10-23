import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/home/data/models/dashboard_data.dart';

class DashboardRepository {
  DashboardRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<DashboardData> getDashboardData({bool log = true}) async {
    if (!AuthSession.hasValidSession) {
      throw const ApiException('Please login to view dashboard data.');
    }

    final uri = ApiConfig.dashboardUri;
    if (log) {
      debugPrint('========== DASHBOARD API REQUEST ==========');
      debugPrint('URL: $uri');
      debugPrint('Method: GET');
      debugPrint('===========================================');
    }

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          ...AuthSession.authHeaders,
        },
      );

      if (log) {
        debugPrint('========== DASHBOARD API RESPONSE ==========');
        debugPrint('Status: ${response.statusCode}');
        debugPrint('Body: ${response.body}');
        debugPrint('============================================');
      }
      await SessionGuard.ensureAuthorized(response);

      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if (response.statusCode == 200 && success) {
        final data = json?['data'];
        if (data is Map<String, dynamic>) {
          return DashboardData.fromJson(data);
        }
        throw const ApiException('Invalid dashboard response from server.');
      }

      final message = json?['message'] as String? ??
          'Failed to load dashboard (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
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

}
