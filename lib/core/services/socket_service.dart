import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/orders/data/models/order_broadcast_model.dart';
import 'package:nomoride/features/orders/presentation/widgets/order_broadcast_bottom_sheet.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  SocketService._internal();

  static final SocketService instance = SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  String? _authenticatedPartnerId;
  final Set<String> _ignoredOrderIds = <String>{};

  bool get isConnected => _isConnected;

  /// Adds an order ID to the locally ignored set so the driver isn't re-prompted during this session.
  void ignoreOrder(String orderId) {
    final trimmed = orderId.trim();
    if (trimmed.isNotEmpty) {
      _ignoredOrderIds.add(trimmed);
      debugPrint('[SocketService] Order $trimmed added to ignored orders.');
    }
  }

  bool isOrderIgnored(String orderId) => _ignoredOrderIds.contains(orderId.trim());

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

    _socket?.on('order:dismiss', (data) {
      debugPrint('🚫 ==================== [ORDER:DISMISS TRIGGERED] ====================');
      debugPrint('[SocketService] Dismiss Event Data: $data');
      developer.log(data.toString(), name: 'ORDER_DISMISS');
      _handleOrderDismiss(data);
      debugPrint('======================================================================');
    });

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
      debugPrint('[SocketService] Reconnected on attempt #$attempt. Re-authenticating...');
      authenticate();
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
    };

    debugPrint('[SocketService] Emitting authenticate: $payload');
    _socket?.emit('authenticate', payload);
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

      debugPrint('📦 [ORDER:BROADCAST PARSED DETAILS]');
      debugPrint('  • Order ID:         ${broadcast.orderId}');
      debugPrint('  • Order Number:     ${broadcast.orderNumber}');
      debugPrint('  • Earning:          ${broadcast.formattedEarning}');
      debugPrint('  • Pickup:           ${broadcast.pickupAddress}');
      debugPrint('  • Delivery:         ${broadcast.deliveryAddress}');
      debugPrint('  • Timer:            ${broadcast.timerSeconds}s');
      debugPrint('  • Flow / Package:   ${broadcast.flowType} / ${broadcast.packageType}');
      debugPrint('  • Customer:         ${broadcast.customerName} (${broadcast.customerMobile})');

      // Verify the broadcast has a valid order ID
      if (broadcast.orderId.isEmpty) {
        debugPrint('[SocketService] Broadcast ignored: order_id is empty');
        return;
      }

      // Check if this driver previously declined/ignored this order
      if (_ignoredOrderIds.contains(broadcast.orderId)) {
        debugPrint('[SocketService] Broadcast ignored: order ${broadcast.orderId} was previously declined.');
        return;
      }

      // Display the bottom sheet using the global navigatorKey context
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
      final message = (map['message'] ?? 'Order was accepted by another partner.').toString().trim();

      if (dismissedOrderId.isNotEmpty) {
        OrderBroadcastBottomSheet.dismissActive(
          dismissedOrderId,
          reason: message.isNotEmpty ? message : 'Order was accepted by another partner.',
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
    _socket?.off('order:broadcast');
    _socket?.off('order:dismiss');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _authenticatedPartnerId = null;
  }
}
