import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/profile/data/models/earnings_data.dart';
import 'package:nomoride/features/profile/data/models/withdrawal_request.dart';

class EarningsRepository {
  EarningsRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<EarningsData> getEarnings() async {
    _ensureLoggedIn();
    final uri = ApiConfig.earningsUri;
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
          return EarningsData.fromJson(data);
        }
        throw const ApiException('Invalid earnings response from server.');
      }

      throw ApiException(
        json?['message'] as String? ??
            'Failed to load earnings (${response.statusCode})',
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

  Future<List<WithdrawalRequest>> getWithdrawalRequests() async {
    _ensureLoggedIn();
    final uri = ApiConfig.withdrawalRequestsUri;
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
        if (data is List) {
          return data
              .whereType<Map<String, dynamic>>()
              .map(WithdrawalRequest.fromJson)
              .where((item) => item.id.isNotEmpty)
              .toList();
        }
        if (data is Map<String, dynamic>) {
          final items = data['requests'] ?? data['withdrawals'];
          if (items is List) {
            return items
                .whereType<Map<String, dynamic>>()
                .map(WithdrawalRequest.fromJson)
                .where((item) => item.id.isNotEmpty)
                .toList();
          }
        }
        return const [];
      }

      throw ApiException(
        json?['message'] as String? ??
            'Failed to load withdrawal requests (${response.statusCode})',
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

  Future<WithdrawalRequest> createWithdrawalRequest({
    required double amount,
    required String payTo,
    String? notes,
    String? upiId,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankAccountName,
  }) async {
    _ensureLoggedIn();

    final normalizedPayTo = payTo.trim().toLowerCase();

    final payload = <String, dynamic>{
      'amount': amount,
      'pay_to': normalizedPayTo,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    if (normalizedPayTo == 'upi') {
      payload['upi_id'] = upiId?.trim();
    } else if (normalizedPayTo == 'bank') {
      payload['bank_account_number'] = bankAccountNumber?.trim();
      payload['bank_ifsc'] = bankIfsc?.trim();
      payload['bank_account_name'] = bankAccountName?.trim();
    }

    final uri = ApiConfig.withdrawalRequestsUri;
    final body = jsonEncode(payload);
    _logRequest('POST', uri, body: body);

    try {
      final response = await _client.post(
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
          return WithdrawalRequest.fromJson(data);
        }
        return WithdrawalRequest(
          id: json?['reference_id']?.toString() ?? '',
          amount: amount,
          status: 'pending',
          payTo: payTo,
          notes: notes,
        );
      }

      throw ApiException(
        json?['message'] as String? ??
            'Failed to submit withdrawal (${response.statusCode})',
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

  void _ensureLoggedIn() {
    final token = AuthSession.authToken?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException('Please login to view earnings.');
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
    debugPrint('========== EARNINGS API REQUEST ==========');
    debugPrint('$method: $uri');
    if (body != null) debugPrint('Body: $body');
    debugPrint('==========================================');
  }

  void _logResponse(int statusCode, String body) {
    debugPrint('========== EARNINGS API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body: $body');
    debugPrint('===========================================');
  }
}
