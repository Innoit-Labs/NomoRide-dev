import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/core/services/socket_service.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';
import 'package:nomoride/features/home/data/order_address_cache.dart';
import 'package:nomoride/features/orders/data/my_orders_repository.dart';

class OrdersRepository {
  OrdersRepository({
    http.Client? client,
    MyOrdersRepository? myOrdersRepository,
  })  : _client = client ?? http.Client(),
        _myOrdersRepository = myOrdersRepository ?? MyOrdersRepository();

  final http.Client _client;
  final MyOrdersRepository _myOrdersRepository;

  Future<List<DpOrder>> getDpOrders({bool log = true}) async {
    if (!AuthSession.hasValidSession) {
      throw const ApiException('Please login to view orders.');
    }

    final uri = ApiConfig.dpOrdersUri;
    if (log) _logRequest('GET', uri);

    try {
      final response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          ...AuthSession.authHeaders,
        },
      );

      if (log) _logResponse(response.statusCode, response.body);
      await SessionGuard.ensureAuthorized(response);

      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? false;

      if (response.statusCode == 200 && success) {
        final data = json?['data'];
        if (data is List) {
          final orders = data
              .whereType<Map<String, dynamic>>()
              .map(DpOrder.fromJson)
              .where(
                (order) =>
                    order.orderNumber.isNotEmpty &&
                    order.id != null &&
                    order.id!.isNotEmpty,
              )
              .toList();
          return await _backfillMissingAddresses(orders);
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

  static final Map<String, DpOrder> _addressSourceCache = {};
  static final Set<String> _addressLookupAttempted = {};
  static final Set<String> _missingAddressReported = {};

  static String? _realAddress(String? address) =>
      DpOrder.isDummyAddress(address) ? null : address;

  /// The backend sends "Customer Address" instead of the real address on some
  /// orders, but every order carries the customer's `customerAddressId`.
  /// Another order with the same id (often the return leg, where the customer
  /// address is the pickup) usually has the real text.
  Future<Map<String, String>> _customerAddressesById(
    List<DpOrder> orders,
  ) async {
    final hubAddresses = {
      for (final order in orders)
        if (order.flowType?.trim().toLowerCase() != 'return' &&
            order.pickupAddress != null)
          order.pickupAddress!.trim().toLowerCase(),
    };

    final byId = <String, String>{};
    for (final order in orders) {
      final addressId = order.customerAddressId?.trim();
      final address = _realAddress(order.customerAddress)?.trim();
      if (addressId == null || addressId.isEmpty || address == null) continue;
      if (hubAddresses.contains(address.toLowerCase())) continue;
      byId.putIfAbsent(addressId, () => address);
    }
    await OrderAddressCache.rememberCustomerAddresses(byId);
    return byId;
  }

  /// The list endpoint can omit or placeholder the customer address; fill it
  /// from addresses seen on other orders, the broadcast, or the single order
  /// endpoint (once per order so polling stays cheap).
  Future<List<DpOrder>> _backfillMissingAddresses(List<DpOrder> orders) async {
    final addressesById = await _customerAddressesById(orders);

    return Future.wait(orders.map((order) async {
      final id = order.id?.trim() ?? '';
      var pickup = _realAddress(order.pickupAddress);
      var drop = _realAddress(order.dropAddress);
      if (pickup != null && drop != null) return order;

      final isReturn = order.flowType?.trim().toLowerCase() == 'return';
      final addressId = order.customerAddressId?.trim();
      final known = addressesById[addressId] ??
          await OrderAddressCache.customerAddressFor(addressId);
      if (isReturn) {
        pickup ??= known;
      } else {
        drop ??= known;
      }

      final saved = await OrderAddressCache.lookup(
        orderId: id,
        orderNumber: order.orderNumber,
      );
      pickup ??= _realAddress(saved.pickup);
      drop ??= _realAddress(saved.drop);

      if ((pickup == null || drop == null) && id.isNotEmpty) {
        var source = _addressSourceCache[id];
        if (source == null && _addressLookupAttempted.add(id)) {
          try {
            source = await getOrderById(id);
            _addressSourceCache[id] = source;
          } catch (e) {
            debugPrint('[OrdersRepo] address lookup for $id failed ($e)');
          }
        }
        if (source != null) {
          pickup ??= _realAddress(source.pickupAddress);
          drop ??= _realAddress(source.dropAddress);
        }
      }

      if (drop == null &&
          !isReturn &&
          _missingAddressReported.add(order.orderNumber)) {
        debugPrint(
          '[OrdersRepo] ${order.orderNumber}: API sent no customer address',
        );
      }

      final source = id.isNotEmpty ? _addressSourceCache[id] : null;
      return order.copyWith(
        pickupAddress: pickup,
        dropAddress: drop,
        rtoStatus: order.rtoStatus ?? source?.rtoStatus,
        rtoDetails: (order.rtoDetails != null && order.rtoDetails!.hasAnyData)
            ? order.rtoDetails
            : source?.rtoDetails,
        amount: order.amount ?? source?.amount,
        completedAt: order.completedAt ?? source?.completedAt,
        returnedToIapAt: order.returnedToIapAt ?? source?.returnedToIapAt,
        rtoCompletedAt: order.rtoCompletedAt ?? source?.rtoCompletedAt,
      );
    }));
  }

  Future<Map<String, dynamic>> acceptBroadcastOrder(String orderId) async {
    if (!AuthSession.hasValidSession) {
      throw const ApiException('Please login to accept orders.');
    }

    final uri = ApiConfig.acceptBroadcastOrderUri;
    final payload = jsonEncode({'order_id': orderId.trim()});
    _logRequest('POST', uri, body: payload);

    try {
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: payload,
      );

      _logResponse(response.statusCode, response.body);
      await SessionGuard.ensureAuthorized(response);

      final json = _tryParseJson(response.body);
      final success = json?['success'] as bool? ?? (response.statusCode == 200);

      if (response.statusCode == 200 && success) {
        SocketService.instance.notifyOrderUpdate();
        return (json?['data'] is Map<String, dynamic>)
            ? (json!['data'] as Map<String, dynamic>)
            : (json ?? <String, dynamic>{});
      }

      final message = json?['message'] as String? ??
          'Order has already been claimed by another delivery partner.';
      throw ApiException(message, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to accept order: $e');
    }
  }

  Future<DpOrder> getOrderById(String idOrNumber) async {
    final trimmed = idOrNumber.trim();
    if (trimmed.isEmpty) {
      throw const ApiException('Order identifier is missing.');
    }
    if (!AuthSession.hasValidSession) {
      throw const ApiException('Please login to view order details.');
    }

    final uri = ApiConfig.singleOrderUri(trimmed);
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

      if ((response.statusCode == 200 || response.statusCode == 201) && success) {
        final data = json?['data'];
        if (data is Map<String, dynamic>) {
          return DpOrder.fromJson(data);
        }
        throw const ApiException('Invalid order details response from server.');
      }

      final message = json?['message'] as String? ??
          'Failed to load order details (${response.statusCode})';
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
  /// Uses dedicated single order endpoint first, then falls back to lists if needed.
  Future<DpOrder> refreshOrderDetails(
    DpOrder current, {
    bool preferHistorySource = false,
  }) async {
    // 1. Try dedicated single order endpoint first: GET /mobile/v1/delivery_partners/orders/{id}
    final candidates = <String>[
      if (current.id?.trim().isNotEmpty ?? false) current.id!.trim(),
      if (current.orderNumber.trim().isNotEmpty) current.orderNumber.trim(),
    ];

    for (final identifier in candidates.toSet()) {
      try {
        final fetched = await getOrderById(identifier);
        return _mergeOrders(current, fetched);
      } catch (e) {
        debugPrint('[OrdersRepo] getOrderById($identifier) failed ($e), falling back');
      }
    }

    final historyPreferred =
        preferHistorySource || current.journey.isCompleted;

    if (historyPreferred) {
      final fromMyOrders = await _findInMyOrders(current);
      if (fromMyOrders != null) return _mergeOrders(current, fromMyOrders);
      if (current.journey.isCompleted) return current;
    }

    try {
      final active = await getDpOrderByNumber(current.orderNumber);
      final merged = _mergeOrders(current, active);
      if (historyPreferred && !merged.journey.isCompleted) {
        return current;
      }
      return merged;
    } on ApiException {
      // Not in the active DP orders list — try my orders next.
    } catch (_) {
      return current;
    }

    if (!historyPreferred) {
      final fromMyOrders = await _findInMyOrders(current);
      if (fromMyOrders != null) return _mergeOrders(current, fromMyOrders);
    }

    return current;
  }

  DpOrder _mergeOrders(DpOrder current, DpOrder fresh) {
    return fresh.copyWith(
      orderType: (fresh.orderType != null && fresh.orderType!.isNotEmpty)
          ? fresh.orderType
          : current.orderType,
      flowType: (fresh.flowType != null && fresh.flowType!.isNotEmpty)
          ? fresh.flowType
          : current.flowType,
      apiNextActionLabel: (fresh.apiNextActionLabel != null &&
              fresh.apiNextActionLabel!.isNotEmpty)
          ? fresh.apiNextActionLabel
          : current.apiNextActionLabel,
      customerName: (fresh.customerName != null && fresh.customerName!.isNotEmpty)
          ? fresh.customerName
          : current.customerName,
      customerPhone: (fresh.customerPhone != null && fresh.customerPhone!.isNotEmpty)
          ? fresh.customerPhone
          : current.customerPhone,
      pickupAddress: (fresh.pickupAddress != null &&
              fresh.pickupAddress!.isNotEmpty &&
              !DpOrder.isDummyAddress(fresh.pickupAddress))
          ? fresh.pickupAddress
          : current.pickupAddress,
      dropAddress: (fresh.dropAddress != null &&
              fresh.dropAddress!.isNotEmpty &&
              !DpOrder.isDummyAddress(fresh.dropAddress))
          ? fresh.dropAddress
          : current.dropAddress,
      scheduledTime: (fresh.scheduledTime != null && fresh.scheduledTime!.isNotEmpty)
          ? fresh.scheduledTime
          : current.scheduledTime,
      returnDate: (fresh.returnDate != null && fresh.returnDate!.isNotEmpty)
          ? fresh.returnDate
          : current.returnDate,
      returnTime: (fresh.returnTime != null && fresh.returnTime!.isNotEmpty)
          ? fresh.returnTime
          : current.returnTime,
      returnNotes: (fresh.returnNotes != null && fresh.returnNotes!.isNotEmpty)
          ? fresh.returnNotes
          : current.returnNotes,
      rtoStatus: (fresh.rtoStatus != null && fresh.rtoStatus!.isNotEmpty)
          ? fresh.rtoStatus
          : current.rtoStatus,
      rtoDetails: (fresh.rtoDetails != null && fresh.rtoDetails!.hasAnyData)
          ? fresh.rtoDetails
          : current.rtoDetails,
      amount: (fresh.amount != null && fresh.amount!.isNotEmpty)
          ? fresh.amount
          : current.amount,
      completedAt: (fresh.completedAt != null && fresh.completedAt!.isNotEmpty)
          ? fresh.completedAt
          : current.completedAt,
      returnedToIapAt:
          (fresh.returnedToIapAt != null && fresh.returnedToIapAt!.isNotEmpty)
              ? fresh.returnedToIapAt
              : current.returnedToIapAt,
      rtoCompletedAt:
          (fresh.rtoCompletedAt != null && fresh.rtoCompletedAt!.isNotEmpty)
              ? fresh.rtoCompletedAt
              : current.rtoCompletedAt,
    );
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
    bool? waited10mins,
    List<String> photoProofPaths = const [],
    double? latitude,
    double? longitude,
  }) async {
    if (!AuthSession.hasValidSession) {
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

    if (validPhotos.isNotEmpty || status == 'not_delivered') {
      return _updateOrderStatusMultipart(
        id: id,
        orderNumber: orderNumber,
        status: status,
        flowType: flowType,
        rejectReason: rejectReason,
        waited10mins: waited10mins,
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
      waited10mins: waited10mins,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// RTO handover of an undelivered forward order at the IAP hub.
  /// `POST order-status-update` with `status: rto_returned`.
  Future<DpOrder> submitRtoReturn({
    required DpOrder order,
    String? notes,
    List<String> photoPaths = const [],
  }) async {
    if (!AuthSession.hasValidSession) {
      throw const ApiException('Please login to update order status.');
    }
    final id = order.id?.trim();
    if (id == null || id.isEmpty) {
      throw const ApiException('Order id is missing.');
    }

    const status = 'rto_returned';
    final fields = <String, String>{'id': id, 'status': status};
    final trimmedNotes = notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      fields['notes'] = trimmedNotes;
    }

    final uri = ApiConfig.orderStatusUpdateUri;
    try {
      final http.Response response;
      final photos = photoPaths
          .map((path) => path.trim())
          .where((path) => path.isNotEmpty)
          .toSet();
      if (photos.isNotEmpty) {
        final request = http.MultipartRequest('POST', uri)
          ..headers['Accept'] = 'application/json'
          ..headers.addAll(AuthSession.authHeaders)
          ..fields.addAll(fields);
        for (final photo in photos) {
          await _addImageFile(request, _photoFieldForStatus(status), photo);
        }
        _logMultipartRequest(request);
        response = await http.Response.fromStream(await _client.send(request));
      } else {
        final body = jsonEncode(fields);
        _logRequest('POST', uri, body: body);
        response = await _client.post(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            ...AuthSession.authHeaders,
          },
          body: body,
        );
      }
      _logResponse(response.statusCode, response.body);
      return _parseStatusUpdateResponse(
        orderNumber: order.orderNumber,
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

  Map<String, String> _statusFields({
    required String id,
    required String orderNumber,
    required String status,
    required String flowType,
    String? rejectReason,
    bool? waited10mins,
    double? latitude,
    double? longitude,
  }) {
    final fields = <String, String>{
      'id': id.trim(),
      'orderNumber': orderNumber.trim(),
      'order_number': orderNumber.trim(),
      'status': status.trim(),
      'flow_type': flowType.trim(),
    };

    final reason = rejectReason?.trim();
    if (reason != null && reason.isNotEmpty) {
      fields['reject_reason'] = reason;
      fields['rejection_reason'] = reason;
      fields['reason'] = reason;
    }

    if (waited10mins != null) {
      fields['waited10mins'] = waited10mins.toString();
      fields['waited_10_mins'] = waited10mins.toString();
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
    bool? waited10mins,
    double? latitude,
    double? longitude,
  }) async {
    final uri = ApiConfig.orderStatusUpdateUri;
    final body = jsonEncode(
      _statusFields(
        id: id,
        orderNumber: orderNumber,
        status: status,
        flowType: flowType,
        rejectReason: rejectReason,
        waited10mins: waited10mins,
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
    bool? waited10mins,
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
        orderNumber: orderNumber,
        status: status,
        flowType: flowType,
        rejectReason: rejectReason,
        waited10mins: waited10mins,
        latitude: latitude,
        longitude: longitude,
      ),
    );

    var addedFiles = 0;
    for (final path in photoProofPaths) {
      final added = await _addImageFile(request, photoField, path);
      if (added) addedFiles++;
    }

    if (addedFiles == 0 && status != 'not_delivered') {
      return _updateOrderStatusJson(
        id: id,
        orderNumber: orderNumber,
        status: status,
        flowType: flowType,
        rejectReason: rejectReason,
        waited10mins: waited10mins,
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
    if (statusCode == 401) {
      await SessionGuard.ensureAuthorized(
        http.Response(body, statusCode),
      );
    }

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
        SocketService.instance.notifyOrderUpdate();
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
      case 'not_delivered':
        return 'pickup_failed_image';
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
    if (body != null) debugPrint('Body: $body');
    debugPrint('========================================');
  }

  void _logMultipartRequest(http.MultipartRequest request) {
    debugPrint('========== ORDERS API REQUEST ==========');
    debugPrint('URL: ${request.url}');
    debugPrint('Method: POST');
    debugPrint('Fields: ${jsonEncode(request.fields)}');
    for (final file in request.files) {
      debugPrint(
        'File: ${file.field} | name=${file.filename} | length=${file.length} bytes',
      );
    }
    debugPrint('========================================');
  }

  void _logResponse(int statusCode, String body) {
    debugPrint('========== ORDERS API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body:');
    String text = body;
    try {
      final decoded = jsonDecode(body);
      text = const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {}
    // One line at a time, and split long lines so logcat does not cut the JSON
    // or mix a second raw copy into the same print.
    for (final line in text.split('\n')) {
      const chunk = 800;
      if (line.length <= chunk) {
        debugPrint(line);
        continue;
      }
      for (var i = 0; i < line.length; i += chunk) {
        final end = i + chunk > line.length ? line.length : i + chunk;
        debugPrint(line.substring(i, end));
      }
    }
    debugPrint('=========================================');
  }
}
