import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/profile/data/models/earnings_data.dart';
import 'package:nomoride/features/profile/data/models/withdrawal_request.dart';

class EarningsRepository {
  EarningsRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// GET /mobile/v1/delivery_partners/earnings
  /// Auth Bearer only — no body, no query, no order_ids.
  Future<EarningsData> getEarnings() async {
    _ensureLoggedIn();
    final uri = ApiConfig.earningsUri;
    _logEarningsRequest(
      method: 'GET',
      uri: uri,
      queryParameters: uri.queryParameters,
      body: null,
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          ...AuthSession.authHeaders,
        },
      );

      _logEarningsResponse(response.statusCode, response.body);
      await SessionGuard.ensureAuthorized(response);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if (response.statusCode == 200 && success) {
        final data = json?['data'];
        if (data is Map) {
          // Parse off the UI isolate to reduce main-thread frame drops.
          final map = data.map((key, value) => MapEntry(key.toString(), value));
          return await compute(_parseEarningsData, map);
        }
        throw const ApiException('Invalid earnings response from server.');
      }

      throw ApiException(
        json?['message']?.toString() ??
            'Failed to load earnings (${response.statusCode})',
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

  /// GET /mobile/v1/delivery_partners/withdrawal-requests
  Future<List<WithdrawalRequest>> getWithdrawalRequests() async {
    _ensureLoggedIn();
    final uri = ApiConfig.withdrawalRequestsUri;
    _logWithdrawalRequest(
      method: 'GET',
      uri: uri,
      queryParameters: uri.queryParameters,
      body: null,
    );

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          ...AuthSession.authHeaders,
        },
      );

      _logWithdrawalResponse(response.statusCode, response.body);
      await SessionGuard.ensureAuthorized(response);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if (response.statusCode == 200 && success) {
        final data = json?['data'];
        if (data is List) {
          return data
              .whereType<Map>()
              .map(
                (item) => WithdrawalRequest.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .where((item) => item.id.isNotEmpty)
              .toList();
        }
        if (data is Map) {
          final map = data.map((key, value) => MapEntry(key.toString(), value));
          final items = map['requests'] ?? map['withdrawals'];
          if (items is List) {
            return items
                .whereType<Map>()
                .map(
                  (item) => WithdrawalRequest.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .where((item) => item.id.isNotEmpty)
                .toList();
          }
        }
        return const [];
      }

      throw ApiException(
        json?['message']?.toString() ??
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

  /// POST /mobile/v1/delivery_partners/withdrawal-requests
  ///
  /// Backend validates `order_ids` (array). Singular `order_id` is ignored by
  /// the live API and returns: "Order id's is required".
  ///
  /// Modes:
  /// - order-based: `{ order_ids: [...], pay_to, notes }`
  /// - custom amount: `{ amount, pay_to, notes }`
  Future<WithdrawalRequest> createWithdrawalRequest({
    required String payTo,
    String? notes,
    String? orderId,
    List<String>? orderIds,
    double? amount,
  }) async {
    _ensureLoggedIn();

    final normalizedPayTo = payTo.trim().toLowerCase();
    if (normalizedPayTo != 'bank' && normalizedPayTo != 'upi') {
      throw const ApiException('pay_to must be bank or upi.');
    }

    final cleanedOrderIds = <String>[
      if (orderId != null && orderId.trim().isNotEmpty) orderId.trim(),
      ...?(orderIds
          ?.map((id) => id.trim())
          .where((id) => id.isNotEmpty)),
    ];
    // Preserve order, drop duplicates.
    final uniqueOrderIds = <String>[];
    for (final id in cleanedOrderIds) {
      if (!uniqueOrderIds.contains(id)) uniqueOrderIds.add(id);
    }

    final payload = <String, dynamic>{
      'pay_to': normalizedPayTo,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    if (uniqueOrderIds.isNotEmpty) {
      // Always send plural `order_ids` — including for a single order.
      payload['order_ids'] = uniqueOrderIds;
    } else if (amount != null) {
      if (amount <= 0) {
        throw const ApiException('Amount must be greater than 0.');
      }
      payload['amount'] = amount;
    } else {
      throw const ApiException(
        'Provide order_ids or amount for withdrawal.',
      );
    }

    final uri = ApiConfig.withdrawalRequestsUri;
    final body = jsonEncode(payload);
    _logWithdrawalRequest(
      method: 'POST',
      uri: uri,
      queryParameters: uri.queryParameters,
      body: body,
    );

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

      _logWithdrawalResponse(response.statusCode, response.body);
      await SessionGuard.ensureAuthorized(response);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          success) {
        final data = json?['data'];
        if (data is Map) {
          return WithdrawalRequest.fromJson(
            data.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
        return WithdrawalRequest(
          id: json?['data']?.toString() ??
              json?['reference_id']?.toString() ??
              '',
          amount: amount ?? 0,
          status: 'pending',
          payTo: normalizedPayTo,
          notes: notes,
          orderIds: uniqueOrderIds,
        );
      }

      throw ApiException(
        json?['message']?.toString() ??
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
    if (!AuthSession.hasValidSession) {
      throw const ApiException('Please login to view earnings.');
    }
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

  void _logEarningsRequest({
    required String method,
    required Uri uri,
    required Map<String, String> queryParameters,
    required String? body,
  }) {
    debugPrint('========== EARNINGS API REQUEST ==========');
    debugPrint('Method: $method');
    debugPrint('URL: $uri');
    debugPrint(
      'Query Parameters: ${queryParameters.isEmpty ? '(none)' : queryParameters}',
    );
    debugPrint('Body: ${body ?? '(none)'}');
    debugPrint('==========================================');
  }

  void _logEarningsResponse(int statusCode, String body) {
    debugPrint('========== EARNINGS API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body: $body');
    debugPrint('===========================================');
  }

  void _logWithdrawalRequest({
    required String method,
    required Uri uri,
    required Map<String, String> queryParameters,
    required String? body,
  }) {
    debugPrint('========== WITHDRAWAL API REQUEST ==========');
    debugPrint('Method: $method');
    debugPrint('URL: $uri');
    debugPrint(
      'Query Parameters: ${queryParameters.isEmpty ? '(none)' : queryParameters}',
    );
    debugPrint('Body: ${body ?? '(none)'}');
    debugPrint('============================================');
  }

  void _logWithdrawalResponse(int statusCode, String body) {
    debugPrint('========== WITHDRAWAL API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body: $body');
    debugPrint('=============================================');
  }
}

EarningsData _parseEarningsData(Map<String, dynamic> json) {
  return EarningsData.fromJson(json);
}
