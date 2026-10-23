import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/core/services/broadcast_notification_service.dart';
import 'package:nomoride/features/home/data/order_address_cache.dart';
import 'package:nomoride/features/orders/data/models/order_broadcast_model.dart';
import 'package:nomoride/features/orders/presentation/widgets/order_broadcast_bottom_sheet.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  SocketService._internal();

  static final SocketService instance = SocketService._internal();

  static const List<String> _orderSyncEvents = [
    'order:assigned',
    'order:assign',
    'order:new',
    'order:update',
    'order:updated',
    'order:status_updated',
    'order:status_change',
    'order:status_changed',
    'order:status',
    'order:accepted',
    'order:cancelled',
    'order:canceled',
    'assignment:new',
    'delivery:assigned',
    'delivery:update',
    'orders:refresh',
  ];

  final StreamController<void> _orderUpdateController =
      StreamController<void>.broadcast();

  /// Stream emitting when an order assignment, status change, or sync event occurs.
  Stream<void> get onOrderUpdate => _orderUpdateController.stream;

  /// Manually broadcasts an order update trigger to all subscribers (e.g. Home Screen).
  void notifyOrderUpdate() {
    if (!_orderUpdateController.isClosed) {
      _orderUpdateController.add(null);
    }
  }

  io.Socket? _socket;
  bool _isConnected = false;
  String? _authenticatedPartnerId;
  final Set<String> _ignoredOrderIds = <String>{};

  bool get isConnected => _isConnected;

  /// No longer suppresses broadcasts, allowing re-broadcasts of the same order to be displayed.
  void ignoreOrder(String orderId) {}

  bool isOrderIgnored(String orderId) => false;

  /// Initializes the Socket.IO client and connects if an active partner session exists.
  void initAndConnect({String? partnerId}) {
    final effectivePartnerId = partnerId ?? AuthSession.partnerId;

    if (!AuthSession.hasValidSession || effectivePartnerId == null || effectivePartnerId.isEmpty) {
      debugPrint('[SocketService] No active session. Skipping socket connection.');
      return;
    }

    if (_socket != null && _isConnected && _authenticatedPartnerId == effectivePartnerId) {
      debugPrint('[SocketService] Already connected and authenticated for $effectivePartnerId');
      return;
    }

    // If socket already exists, disconnect and recreate cleanly
    if (_socket != null) {
      disconnect();
    }

    final socketUrl = ApiConfig.socketUrl;
    debugPrint('[SocketService] Connecting to Socket.IO at $socketUrl');

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _setupListeners(effectivePartnerId);
    _socket?.connect();
  }

  void _setupListeners(String partnerId) {
    _socket?.onConnect((_) {
      _isConnected = true;
      _authenticatedPartnerId = partnerId;
      debugPrint('================ SOCKET CONNECTED ================');
      debugPrint('[SocketService] Connected. Emitting authentication for partnerId: $partnerId');
      authenticate(partnerId: partnerId);
      debugPrint('==================================================');
    });

    _socket?.on('order:broadcast', (data) {
      debugPrint('🔔 ==================== [ORDER:BROADCAST TRIGGERED] ====================');
      debugPrint('[SocketService] Raw Event Data: $data');
      try {
        final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
        for (final line in prettyJson.split('\n')) {
          debugPrint('  $line');
        }
      } catch (_) {
        debugPrint('  $data');
      }
      developer.log(data.toString(), name: 'ORDER_BROADCAST');
      _handleOrderBroadcast(data);
      debugPrint('========================================================================');
    });

    _socket?.on('order:dismiss', _onOrderClosed);
    _socket?.on('order:closed', _onOrderClosed);

    for (final event in _orderSyncEvents) {
      _socket?.on(event, (data) {
        debugPrint('🔄 ==================== [SOCKET EVENT: $event] ====================');
        debugPrint('[SocketService] Event Payload: $data');
        developer.log(data.toString(), name: 'ORDER_SYNC_EVENT');
        notifyOrderUpdate();
        debugPrint('================================================================');
      });
    }

    _socket?.onDisconnect((reason) {
      _isConnected = false;
      debugPrint('[SocketService] Disconnected: $reason');
    });

    _socket?.onConnectError((error) {
      _isConnected = false;
      debugPrint('[SocketService] Connection Error: $error');
    });

    _socket?.onError((error) {
      debugPrint('[SocketService] Socket Error: $error');
    });

    _socket?.onReconnect((attempt) {
      _isConnected = true;
      debugPrint('[SocketService] Reconnected on attempt #$attempt. Re-authenticating and syncing...');
      authenticate();
      notifyOrderUpdate();
    });
  }

  /// Emits the authentication payload to join the delivery partner broadcast room.
  void authenticate({String? partnerId}) {
    final effectiveId = partnerId ?? AuthSession.partnerId;
    if (effectiveId == null || effectiveId.isEmpty) {
      debugPrint('[SocketService] Cannot authenticate without partnerId');
      return;
    }

    final payload = {
      'role': 'delivery_partner',
      'deliveryPartnerId': effectiveId,
      'partnerId': effectiveId,
    };

    debugPrint('[SocketService] Emitting authenticate: $payload');
    _socket?.emit('authenticate', payload);
  }

  void _onOrderClosed(dynamic data) {
    debugPrint('🚫 ==================== [ORDER CLOSED / DISMISS] ====================');
    debugPrint('[SocketService] Dismiss Event Data: $data');
    developer.log(data.toString(), name: 'ORDER_DISMISS');
    _handleOrderDismiss(data);
    debugPrint('======================================================================');
  }

  /// Tells the server this partner's broadcast timer ran out.
  void emitOrderDismiss(String orderId) {
    final id = orderId.trim();
    if (id.isEmpty) return;
    debugPrint('[SocketService] Emitting order:dismiss for $id');
    _socket?.emit('order:dismiss', {'order_id': id});
  }

  void _handleOrderBroadcast(dynamic data) {
    if (!AuthSession.hasValidSession) {
      debugPrint('[SocketService] Broadcast ignored: user not logged in');
      return;
    }

    try {
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is Map) {
        map = Map<String, dynamic>.from(data);
      }

      if (map == null) {
        debugPrint('[SocketService] Invalid broadcast payload: $data');
        return;
      }

      final broadcast = OrderBroadcastModel.fromJson(map);

      _printBroadcastResponse(map);

      debugPrint('📦 [ORDER:BROADCAST PARSED DETAILS]');
      debugPrint('  • Order ID:         ${broadcast.orderId}');
      debugPrint('  • Order Number:     ${broadcast.orderNumber}');
      debugPrint('  • Earning:          ${broadcast.formattedEarning}');
      debugPrint('  • Pickup:           ${broadcast.pickupAddress}');
      debugPrint('  • Delivery:         ${broadcast.deliveryAddress}');
      debugPrint('  • Timer:            ${broadcast.timerSeconds}s');
      debugPrint('  • Flow / Package:   ${broadcast.flowType} / ${broadcast.packageType}');
      debugPrint('  • Customer:         ${broadcast.customerName} (${broadcast.customerMobile})');
      debugPrint('  • Sound URL:        ${broadcast.soundUrl ?? '-'} (${broadcast.soundDurationSeconds ?? '-'}s)');

      // Verify the broadcast has a valid order ID
      if (broadcast.orderId.isEmpty) {
        debugPrint('[SocketService] Broadcast ignored: order_id is empty');
        return;
      }

      unawaited(OrderAddressCache.remember(
        orderId: broadcast.orderId,
        orderNumber: broadcast.orderNumber,
        pickupAddress: broadcast.pickupAddress,
        deliveryAddress: broadcast.deliveryAddress,
      ));

      if (!BroadcastNotificationService.isAppInForeground) {
        // Native overlay / heads-up owns UI + sound while the partner is on
        // the home screen or another app. Showing the Flutter sheet here would
        // start a second AudioPlayer that Decline on the overlay cannot stop.
        debugPrint(
          '[SocketService] App in background — leaving broadcast to native overlay.',
        );
        unawaited(BroadcastNotificationService.show(broadcast));
        return;
      }

      final context = SessionGuard.navigatorKey.currentContext;
      if (context != null) {
        debugPrint('[SocketService] Showing OrderBroadcastBottomSheet on screen...');
        OrderBroadcastBottomSheet.show(context, broadcast);
      } else {
        debugPrint('[SocketService] ⚠️ Navigator context not ready for broadcast popup.');
      }
    } catch (e, stack) {
      debugPrint('[SocketService] Error handling order:broadcast: $e\n$stack');
    }
  }

  void _printBroadcastResponse(Map<String, dynamic> map) {
    debugPrint('========== ORDER BROADCAST RESPONSE ==========');
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(_jsonSafe(map));
      for (final line in pretty.split('\n')) {
        debugPrint(line);
      }
    } catch (error) {
      debugPrint('[SocketService] Could not format broadcast JSON: $error');
      map.forEach((key, value) {
        debugPrint('$key: $value');
      });
    }
    debugPrint('==============================================');
  }

  dynamic _jsonSafe(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _jsonSafe(item)),
      );
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList();
    }
    return value;
  }

  void _handleOrderDismiss(dynamic data) {
    try {
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is Map) {
        map = Map<String, dynamic>.from(data);
      }

      if (map == null) return;

      final dismissedOrderId = (map['order_id'] ?? map['orderId'] ?? '').toString().trim();
      final claimedBy = (map['claimed_by_partner_id'] ?? map['claimedByPartnerId'] ?? '')
          .toString()
          .trim();
      final mine = AuthSession.partnerId?.trim();
      final acceptedByMe = mine != null && mine.isNotEmpty && claimedBy == mine;
      final message = (map['message'] ?? 'Order was accepted by another partner.').toString().trim();

      if (dismissedOrderId.isNotEmpty) {
        OrderBroadcastBottomSheet.dismissActive(
          dismissedOrderId,
          claimedByPartnerId: claimedBy,
          reason: acceptedByMe
              ? null
              : (message.isNotEmpty
                  ? message
                  : 'Order was accepted by another partner.'),
        );
      }
    } catch (e) {
      debugPrint('[SocketService] Error handling order:dismiss: $e');
    }
  }

  /// Disconnects the socket and cleans up resources (e.g. on user logout).
  void disconnect() {
    debugPrint('[SocketService] Disconnecting socket...');
    _ignoredOrderIds.clear();
    OrderBroadcastBottomSheet.dismissAll();
    _socket?.off('order:broadcast');
    _socket?.off('order:dismiss');
    _socket?.off('order:closed');
    for (final event in _orderSyncEvents) {
      _socket?.off(event);
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _authenticatedPartnerId = null;
  }
}
