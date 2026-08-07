import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';
import 'package:nomoride/features/orders/data/my_orders_repository.dart';

class OrdersRepository {
  OrdersRepository({
    http.Client? client,
    MyOrdersRepository? myOrdersRepository,
  })  : _client = client ?? http.Client(),
        _myOrdersRepository = myOrdersRepository ?? MyOrdersRepository();

  final http.Client _client;
  final MyOrdersRepository _myOrdersRepository;

  Future<List<DpOrder>> getDpOrders() async {
    final token = AuthSession.authToken?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException('Please login to view orders.');
    }

    final uri = ApiConfig.dpOrdersUri;
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
              .map(DpOrder.fromJson)
              .where(
                (order) =>
                    order.orderNumber.isNotEmpty &&
                    order.id != null &&
                    order.id!.isNotEmpty,
              )
              .toList();
        }
        throw const ApiException('Invalid orders response from server.');
      }

      final message = json?['message'] as String? ??
          'Failed to load orders (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  Future<DpOrder> getDpOrderByNumber(String orderNumber) async {
    final orders = await getDpOrders();
    return orders.firstWhere(
      (order) => order.orderNumber == orderNumber,
      orElse: () => throw const ApiException('Order not found.'),
    );
  }

  /// Resolves the freshest order for the details screen.
  /// Active assignments come from [getDpOrders]; completed/history orders
  /// prefer the my-orders API so a stale active snapshot cannot downgrade them.
  Future<DpOrder> refreshOrderDetails(
    DpOrder current, {
    bool preferHistorySource = false,
  }) async {
    final historyPreferred =
        preferHistorySource || current.journey.isCompleted;

    if (historyPreferred) {
      final fromMyOrders = await _findInMyOrders(current);
      if (fromMyOrders != null) return fromMyOrders;
      if (current.journey.isCompleted) return current;
    }

    try {
      final active = await getDpOrderByNumber(current.orderNumber);
      if (historyPreferred && !active.journey.isCompleted) {
        return current;
      }
      return active;
    } on ApiException {
      // Not in the active DP orders list — try my orders next.
    } catch (_) {
      return current;
    }

    final fromMyOrders = await _findInMyOrders(current);
    if (fromMyOrders != null) return fromMyOrders;

    return current;
  }

  Future<DpOrder?> _findInMyOrders(DpOrder current) async {
    try {
      return await _myOrdersRepository.findOrder(
        orderNumber: current.orderNumber,
        orderId: current.id,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DpOrder> updateOrderStatus({
    required DpOrder order,
    required String status,
    String? rejectReason,
    List<String> photoProofPaths = const [],
    double? latitude,
    double? longitude,
  }) async {
    final token = AuthSession.authToken?.trim();
    if (token == null || token.isEmpty) {
      throw const ApiException('Please login to update order status.');
    }

    final id = order.id?.trim();
    if (id == null || id.isEmpty) {
      throw const ApiException('Order id is missing.');
    }

    final orderNumber = order.orderNumber;
    final explicitFlow = order.flowType?.trim().toLowerCase();
    final flowType = (explicitFlow == 'return' || explicitFlow == 'delivery')
        ? explicitFlow!
        : (order.isReturnFlow ? 'return' : 'delivery');

    final validPhotos = photoProofPaths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList();

    if (validPhotos.isNotEmpty) {
      return _updateOrderStatusMultipart(
        id: id,
        orderNumber: orderNumber,
        status: status,
        flowType: flowType,
        rejectReason: rejectReason,
        photoProofPaths: validPhotos,
        latitude: latitude,
        longitude: longitude,
      );
    }

    return _updateOrderStatusJson(
      id: id,
      orderNumber: orderNumber,
      status: status,
      flowType: flowType,
      rejectReason: rejectReason,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Map<String, String> _statusFields({
    required String id,
    required String status,
    required String flowType,
    String? rejectReason,
    double? latitude,
    double? longitude,
  }) {
    final fields = <String, String>{
      'id': id.trim(),
      'status': status.trim(),
      'flow_type': flowType.trim(),
    };

    final reason = rejectReason?.trim();
    if (reason != null && reason.isNotEmpty) {
      fields['reject_reason'] = reason;
    }

    if (latitude != null && longitude != null) {
      final lat = latitude.toString();
      final lng = longitude.toString();
      fields['latitude'] = lat;
      fields['longitude'] = lng;
      fields['current_latitude'] = lat;
      fields['current_longitude'] = lng;
    }

    return fields;
  }

  Future<DpOrder> _updateOrderStatusJson({
    required String id,
    required String orderNumber,
    required String status,
    required String flowType,
    String? rejectReason,
    double? latitude,
    double? longitude,
  }) async {
    final uri = ApiConfig.orderStatusUpdateUri;
    final body = jsonEncode(
      _statusFields(
        id: id,
        status: status,
        flowType: flowType,
        rejectReason: rejectReason,
        latitude: latitude,
        longitude: longitude,
      ),
    );

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
      return _parseStatusUpdateResponse(
        orderNumber: orderNumber,
        status: status,
        statusCode: response.statusCode,
        body: response.body,
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  Future<DpOrder> _updateOrderStatusMultipart({
    required String id,
    required String orderNumber,
    required String status,
    required String flowType,
    String? rejectReason,
    required List<String> photoProofPaths,
    double? latitude,
    double? longitude,
  }) async {
    final uri = ApiConfig.orderStatusUpdateUri;
    final photoField = _photoFieldForStatus(status);
    final request = http.MultipartRequest('POST', uri);

    request.headers['Accept'] = 'application/json';
    request.headers.addAll(AuthSession.authHeaders);

    // Text fields first so multer can populate req.body before files.
    request.fields.addAll(
      _statusFields(
        id: id,
        status: status,
        flowType: flowType,
        rejectReason: rejectReason,
        latitude: latitude,
        longitude: longitude,
      ),
    );

    var addedFiles = 0;
    for (final path in photoProofPaths) {
      final added = await _addImageFile(request, photoField, path);
      if (added) addedFiles++;
    }

    if (addedFiles == 0) {
      return _updateOrderStatusJson(
        id: id,
        orderNumber: orderNumber,
        status: status,
        flowType: flowType,
        rejectReason: rejectReason,
        latitude: latitude,
        longitude: longitude,
      );
    }

    _logMultipartRequest(request);

    try {
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      _logResponse(response.statusCode, response.body);

      return _parseStatusUpdateResponse(
        orderNumber: orderNumber,
        status: status,
        statusCode: response.statusCode,
        body: response.body,
      );
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Something went wrong. Please try again.');
    }
  }

  Future<DpOrder> _parseStatusUpdateResponse({
    required String orderNumber,
    required String status,
    required int statusCode,
    required String body,
  }) async {
    if (statusCode == 413) {
      throw const ApiException(
        'Photo file is too large. Please use a smaller image.',
        statusCode: 413,
      );
    }

    final json = _tryParseJson(body);
    final success = json?['success'] as bool? ?? false;
    final message = _extractMessage(json);

    if (statusCode == 200 || statusCode == 201) {
      if (success || _isSuccessMessage(message)) {
        final data = json?['data'];
        if (data is Map<String, dynamic>) {
          return DpOrder.fromJson(data);
        }

        try {
          return await getDpOrderByNumber(orderNumber);
        } catch (_) {
          return DpOrder(
            orderNumber: orderNumber,
            status: status,
          );
        }
      }
    }

    throw ApiException(
      _sanitizeMessage(message) ??
          _messageFromHtmlBody(body) ??
          'Failed to update order status ($statusCode)',
      statusCode: statusCode,
    );
  }

  static bool _isSuccessMessage(String? message) {
    if (message == null || message.isEmpty) return false;
    final lower = message.toLowerCase();
    return lower.contains('success') ||
        lower.contains('confirmed') ||
        lower.contains('completed');
  }

  static String? _extractMessage(dynamic json) {
    if (json is! Map) return null;
    final message = json['message'] ?? json['error'] ?? json['msg'];
    if (message == null) return null;
    return message.toString();
  }

  static String? _sanitizeMessage(String? message) {
    if (message == null || message.isEmpty) return null;
    if (message == 'undefined' || message == 'null') {
      return 'Failed to update order status. Please try again.';
    }
    return message;
  }

  static String? _messageFromHtmlBody(String body) {
    if (!body.contains('PayloadTooLargeError')) return null;
    return 'Photo file is too large. Please use a smaller image.';
  }

  static Future<bool> _addImageFile(
    http.MultipartRequest request,
    String key,
    String path,
  ) async {
    final file = File(path);
    if (!await file.exists()) return false;

    final fileName = path.split(Platform.pathSeparator).last;
    request.files.add(
      await http.MultipartFile.fromPath(
        key,
        path,
        filename: fileName,
        contentType: MediaType.parse(_mimeTypeFor(fileName)),
      ),
    );
    return true;
  }

  static String _photoFieldForStatus(String status) {
    switch (status) {
      case 'confirm_pickup':
        return 'pickup_photo_proof';
      case 'confirm_delivery':
        return 'delivery_photo_proof';
      default:
        return 'photo_proof';
    }
  }

  static String _mimeTypeFor(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
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
    debugPrint('========== ORDERS API REQUEST ==========');
    debugPrint('URL: $uri');
    debugPrint('Method: $method');
    debugPrint('Headers: ${jsonEncode(AuthSession.authHeaders)}');
    if (body != null) debugPrint('Body: $body');
    debugPrint('========================================');
  }

  void _logMultipartRequest(http.MultipartRequest request) {
    debugPrint('========== ORDERS API REQUEST ==========');
    debugPrint('URL: ${request.url}');
    debugPrint('Method: POST');
    debugPrint('Content-Type: ${request.headers['content-type']}');
    debugPrint('Headers: ${jsonEncode(AuthSession.authHeaders)}');
    debugPrint('Fields: ${jsonEncode(request.fields)}');
    for (final file in request.files) {
      debugPrint(
        'File: ${file.field} | name=${file.filename} | '
        'type=${file.contentType} | length=${file.length} bytes',
      );
    }
    debugPrint('========================================');
  }

  void _logResponse(int statusCode, String body) {
    debugPrint('========== ORDERS API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body: $body');
    debugPrint('=========================================');
  }
}
