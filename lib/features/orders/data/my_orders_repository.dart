import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';
import 'package:nomoride/features/orders/data/models/my_orders_data.dart';

class MyOrdersRepository {
  MyOrdersRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<DpOrder?> findOrder({
    String? orderNumber,
    String? orderId,
  }) async {
    final number = orderNumber?.trim();
    final id = orderId?.trim();
    if ((number == null || number.isEmpty) && (id == null || id.isEmpty)) {
      return null;
    }

    final data = await getMyOrders();
    for (final order in data.allOrders) {
      if (id != null && id.isNotEmpty && order.id == id) return order;
      if (number != null &&
          number.isNotEmpty &&
          order.orderNumber == number) {
        return order;
      }
    }
    return null;
  }

  Future<MyOrdersData> getMyOrders({bool failedOrders = false}) async {
    _ensureLoggedIn();
    final uri = failedOrders
        ? ApiConfig.myOrdersUri.replace(
            queryParameters: {'failedOrders': 'true'},
          )
        : ApiConfig.myOrdersUri;
    debugPrint('========== MY ORDERS API REQUEST ==========');
    debugPrint('GET: $uri');
    debugPrint('===========================================');

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          ...AuthSession.authHeaders,
        },
      );

      debugPrint('========== MY ORDERS API RESPONSE ==========');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Body:');
      try {
        final decoded = jsonDecode(response.body);
        final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
        for (final line in pretty.split('\n')) {
          debugPrint(line);
        }
      } catch (_) {
        debugPrint(response.body);
      }
      developer.log(response.body, name: 'MY_ORDERS_API');
      debugPrint('============================================');
      await SessionGuard.ensureAuthorized(response);
      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if (response.statusCode == 200 && success) {
        final payload = _ordersPayload(json);
        if (payload != null) {
          return MyOrdersData.fromJson(payload);
        }
        throw const ApiException('Invalid my orders response from server.');
      }

      throw ApiException(
        json?['message'] as String? ??
            'Failed to load orders (${response.statusCode})',
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

  static Map<String, dynamic>? _ordersPayload(Map<String, dynamic>? json) {
    if (json == null) return null;

    if (json['completedOrders'] != null ||
        json['completed_orders'] != null ||
        json['intransist_orders'] != null ||
        json['in_transit_orders'] != null ||
        json['inTransitOrders'] != null ||
        json['failedOrders'] != null ||
        json['failed_orders'] != null) {
      return json;
    }

    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  void _ensureLoggedIn() {
    if (!AuthSession.hasValidSession) {
      throw const ApiException('Please login to view orders.');
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
