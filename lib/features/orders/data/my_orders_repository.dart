import 'dart:convert';
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

  Future<MyOrdersData> getMyOrders() async {
    _ensureLoggedIn();
    final uri = ApiConfig.myOrdersUri;
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
        final payload = _ordersPayload(json);
        if (payload != null) {
          debugPrint('[ORDER DEBUG] myorders response received');
          final completed = payload['completedOrders'] ?? payload['completed_orders'];
          final intransit = payload['intransist_orders'] ?? payload['in_transit_orders'] ?? payload['inTransitOrders'];
          int totalItemsCount = 0;
          void countItems(dynamic ordersList) {
            if (ordersList is List) {
              for (final order in ordersList) {
                if (order is Map) {
                  final items = order['items'] ?? order['products'];
                  if (items is List) {
                    totalItemsCount += items.length;
                  }
                }
              }
            }
          }
          countItems(completed);
          countItems(intransit);
          debugPrint('[ORDER DEBUG] items count: $totalItemsCount');
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
        json['inTransitOrders'] != null) {
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

  void _logRequest(String method, Uri uri) {
    debugPrint('========== MY ORDERS API REQUEST ==========');
    debugPrint('$method: $uri');
    debugPrint('===========================================');
  }

  void _logResponse(int statusCode, String body) {
    debugPrint('========== MY ORDERS API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body: $body');
    debugPrint('============================================');
  }
}
