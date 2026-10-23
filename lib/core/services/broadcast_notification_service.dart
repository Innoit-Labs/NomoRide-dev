import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nomoride/core/network/session_guard.dart';
import 'package:nomoride/core/services/broadcast_sound_player.dart';
import 'package:nomoride/features/orders/data/models/order_broadcast_model.dart';
import 'package:nomoride/features/orders/presentation/widgets/order_broadcast_bottom_sheet.dart';
import 'package:nomoride/theme/theme_helper.dart';

/// Shows order broadcasts as heads-up system notifications while the app is
/// in the background (recents) or killed, and re-opens the broadcast popup
/// when the partner taps the notification.
class BroadcastNotificationService {
  BroadcastNotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'order_broadcasts',
    'New order requests',
    description: 'Alerts for new delivery order requests',
    importance: Importance.max,
  );

  /// Channel the backend targets in its FCM `android.notification`.
  static const AndroidNotificationChannel _backendChannel =
      AndroidNotificationChannel(
    'high_importance_channel',
    'Order broadcasts',
    description: 'New order broadcasts sent by NomoRide',
    importance: Importance.max,
  );

  static const MethodChannel _launchChannel =
      MethodChannel('com.nomoride/broadcast_launch');

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _homeReady = false;
  static bool _overlayPrompted = false;
  static final List<OrderBroadcastModel> _pending = [];
  static String? _acceptOrderId;

  static bool get isAppInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Main-isolate setup: registers tap handling and picks up the broadcast
  /// that launched the app from a killed state.
  static Future<void> initialize() async {
    await _ensurePlugin(onTap: _onNotificationTap);
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _queueFromPayload(launch!.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('[BroadcastNotification] Launch details error: $e');
    }

    if (defaultTargetPlatform != TargetPlatform.android) return;
    _launchChannel.setMethodCallHandler((call) async {
      if (call.method == 'broadcastLaunched') {
        _presentLaunchData(call.arguments);
      } else if (call.method == 'stopBroadcastSound' ||
          call.method == 'overlayDeclined') {
        // Native overlay Decline — stop Flutter AudioPlayer if it was playing.
        await BroadcastSoundPlayer.stop();
        if (call.method != 'overlayDeclined') return;
        final args = call.arguments;
        if (args is! Map) return;
        final orderId = (args['order_id'] ??
                args['orderId'] ??
                args['broadcast_id'] ??
                args['broadcastId'])
            ?.toString();
        if (orderId == null || orderId.isEmpty) return;
        OrderBroadcastManager.instance.handleNativeDecline(orderId);
      }
    });
    try {
      _presentLaunchData(
        await _launchChannel.invokeMethod<Object?>('takePendingBroadcast'),
      );
    } catch (e) {
      debugPrint('[BroadcastNotification] Pending launch error: $e');
    }
  }

  /// Order data handed over by the native receiver that brought the app to
  /// the front from another app.
  static void _presentLaunchData(Object? data) {
    if (data is! Map) return;
    debugPrint('[BroadcastNotification] App opened for broadcast: $data');
    final map = Map<String, dynamic>.from(data);
    final action = map.remove('launch_action')?.toString();
    final broadcast = fromFcmData(map);
    if (broadcast == null) return;
    if (action == 'accept') _acceptOrderId = broadcast.orderId;
    present(broadcast);
  }

  /// After Decline, return to the app the partner was using.
  static Future<void> returnToPreviousAppIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final opened = await _launchChannel
              .invokeMethod<bool>('consumeOpenedOverOtherApp') ??
          false;
      if (opened) await _launchChannel.invokeMethod<void>('moveToBack');
    } catch (e) {
      debugPrint('[BroadcastNotification] Return to previous app failed: $e');
    }
  }

  /// Accept keeps the partner inside NomoRide, so a later Decline must not
  /// send them back.
  static Future<void> stayInApp() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _launchChannel.invokeMethod<bool>('consumeOpenedOverOtherApp');
    } catch (_) {}
  }

  /// Keeps Android from freezing the app while the partner is online.
  static Future<void> setOnline(bool online) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _launchChannel.invokeMethod<void>('setOnlineService', {
        'online': online,
      });
    } catch (e) {
      debugPrint('[BroadcastNotification] Online service failed: $e');
    }
  }

  /// Asks once per app start for "Display over other apps", which Android
  /// requires before an order broadcast can open the app over other apps.
  static Future<void> promptOverlayPermission(BuildContext context) async {
    if (_overlayPrompted || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _overlayPrompted = true;
    try {
      final granted =
          await _launchChannel.invokeMethod<bool>('canDrawOverlays') ?? true;
      if (granted || !context.mounted) return;
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1F),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColours.primary.withValues(alpha: 0.35),
            ),
          ),
          title: Text(
            'Show new orders over other apps',
            style: CustomTextStyles.montserratBold.copyWith(
              color: AppColours.primary,
              fontSize: 16,
            ),
          ),
          content: Text(
            'Allow "Display over other apps" so new order requests open '
            'NomoRide even while you are using another app.',
            style: CustomTextStyles.openSansRegular.copyWith(
              color: AppColours.secondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Not now',
                style: CustomTextStyles.openSansSemiBold.copyWith(
                  color: AppColours.secondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Allow',
                style: CustomTextStyles.montserratBold.copyWith(
                  color: AppColours.primary,
                ),
              ),
            ),
          ],
        ),
      );
      if (open == true) {
        await _launchChannel.invokeMethod<void>('openOverlaySettings');
      }
    } catch (e) {
      debugPrint('[BroadcastNotification] Overlay permission check failed: $e');
    }
  }

  static Future<void> _ensurePlugin({
    DidReceiveNotificationResponseCallback? onTap,
  }) async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: onTap,
      );
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_channel);
      await android?.createNotificationChannel(_backendChannel);
      _initialized = true;
    } catch (e) {
      debugPrint('[BroadcastNotification] Init error: $e');
    }
  }

  static int _idFor(String orderId) => orderId.hashCode & 0x7fffffff;

  /// Displays the broadcast in the notification tray. Safe to call from the
  /// FCM background isolate.
  static Future<void> show(OrderBroadcastModel broadcast) async {
    if (broadcast.orderId.isEmpty) return;
    await _ensurePlugin();
    if (!_initialized) return;

    final expiresAt = broadcast.expiresAt ??
        DateTime.now().add(Duration(seconds: broadcast.timerSeconds));
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return;

    final payload = jsonEncode({
      ...broadcast.toJson(),
      'expires_at': expiresAt.toIso8601String(),
    });

    final title = broadcast.formattedEarning.isNotEmpty
        ? 'New Order Request • ${broadcast.formattedEarning}'
        : 'New Order Request';
    final orderLabel = broadcast.orderNumber.isNotEmpty
        ? '#${broadcast.orderNumber}'
        : 'New order';
    final body = '$orderLabel\n'
        'Pickup: ${broadcast.pickupAddress}\n'
        'Drop: ${broadcast.deliveryAddress}';

    try {
      await _plugin.show(
        _idFor(broadcast.orderId),
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.call,
            visibility: NotificationVisibility.public,
            ticker: title,
            timeoutAfter: remaining.inMilliseconds,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[BroadcastNotification] Show error: $e');
    }
  }

  static Future<void> cancel(String orderId) async {
    if (!_initialized || orderId.isEmpty) return;
    try {
      await _plugin.cancel(_idFor(orderId));
    } catch (_) {}
  }

  /// Parses an FCM data map (flat fields or a nested `broadcast` JSON) into a
  /// broadcast, or null when the message is not an order broadcast.
  static OrderBroadcastModel? fromFcmData(Map<String, dynamic> data) {
    if (data.isEmpty) return null;
    final type = (data['type'] ?? data['event'] ?? '').toString();
    final isBroadcast = type == 'ORDER_BROADCAST' ||
        type == 'BROADCAST_ORDER' ||
        type == 'order:broadcast' ||
        data.containsKey('broadcast') ||
        data.containsKey('order_id') ||
        data.containsKey('orderId') ||
        data.containsKey('orderNumber') ||
        data.containsKey('order_number');
    if (!isBroadcast) return null;

    final map = Map<String, dynamic>.from(data);
    final existingId = (map['order_id'] ?? map['orderId'] ?? map['id'] ?? '')
        .toString()
        .trim();
    if (existingId.isEmpty) {
      final number = (map['orderNumber'] ?? map['order_number'] ?? '')
          .toString()
          .trim();
      if (number.isNotEmpty) map['order_id'] = number;
    }
    final nested = data['broadcast'];
    try {
      if (nested is String && nested.trim().startsWith('{')) {
        map.addAll(Map<String, dynamic>.from(jsonDecode(nested) as Map));
      } else if (nested is Map) {
        map.addAll(Map<String, dynamic>.from(nested));
      }
      final broadcast = OrderBroadcastModel.fromJson(map);
      return broadcast.orderId.isEmpty ? null : broadcast;
    } catch (e) {
      debugPrint('[BroadcastNotification] Could not parse FCM broadcast: $e');
      return null;
    }
  }

  /// Opens the broadcast popup now if Home is up, otherwise once it is.
  static void present(OrderBroadcastModel broadcast) {
    final expiresAt = broadcast.expiresAt;
    if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) {
      debugPrint(
          '[BroadcastNotification] ${broadcast.orderId} already expired.');
      if (_acceptOrderId == broadcast.orderId) _acceptOrderId = null;
      return;
    }
    _pending.removeWhere((b) => b.orderId == broadcast.orderId);
    _pending.add(broadcast);
    _flush();
  }

  /// Called by Home once the navigator can host the popup.
  static void markHomeReady() {
    _homeReady = true;
    _flush();
  }

  static void _flush() {
    if (!_homeReady || _pending.isEmpty) return;
    final context = SessionGuard.navigatorKey.currentContext;
    if (context == null) return;
    final items = List<OrderBroadcastModel>.from(_pending);
    final acceptId = _acceptOrderId;
    _pending.clear();
    _acceptOrderId = null;
    for (final broadcast in items) {
      final expiresAt = broadcast.expiresAt;
      if (expiresAt != null && !expiresAt.isAfter(DateTime.now())) continue;
      OrderBroadcastBottomSheet.show(context, broadcast);
    }
    OrderBroadcastManager.instance.bringToFront();
    if (acceptId != null && acceptId.isNotEmpty) {
      OrderBroadcastManager.instance.handleAccept(context, acceptId);
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    _queueFromPayload(response.payload);
  }

  static void _queueFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      final broadcast = OrderBroadcastModel.fromJson(map);
      if (broadcast.orderId.isNotEmpty) present(broadcast);
    } catch (e) {
      debugPrint('[BroadcastNotification] Bad payload: $e');
    }
  }
}
