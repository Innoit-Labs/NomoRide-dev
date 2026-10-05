import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/notifications/data/notifications_repository.dart';

/// Top-level background message handler for FCM.
/// Must be annotated with @pragma('vm:entry-point') to be called when the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCMService] Background message received: ${message.messageId}');
  debugPrint('[FCMService] Background message title: ${message.notification?.title}');
  debugPrint('[FCMService] Background message body: ${message.notification?.body}');
  debugPrint('[FCMService] Background message data: ${message.data}');
}

class FcmService {
  FcmService._();

  static final FcmService _instance = FcmService._();
  static FcmService get instance => _instance;

  static String? _currentToken;
  static String? get currentToken => _currentToken;

  /// Returns device platform string ("android" or "ios")
  static String get deviceType {
    if (kIsWeb) return 'android';
    return Platform.isIOS ? 'ios' : 'android';
  }

  /// Initializes Firebase and FCM listeners.
  static Future<void> initialize() async {
    try {
      // 1. Initialize Firebase App
      // On Android, google-services.json automatically supplies the credentials
      // matching com.nomoride.
      final app = await Firebase.initializeApp();
      debugPrint('[FCMService] Firebase initialized successfully: ${app.name}');
      debugPrint('[FCMService] Firebase options - ProjectId: ${app.options.projectId}, AppId: ${app.options.appId}');

      // 2. Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Request Notification Permissions (required for iOS and Android 13+)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[FCMService] Permission authorization status: ${settings.authorizationStatus}');

      // 4. Retrieve FCM Token
      try {
        _currentToken = await messaging.getToken();
        // Print the FCM token clearly for testing as requested
        print('==================== FCM TOKEN ====================');
        print('FCM Token: $_currentToken');
        print('===================================================');

        // Automatically sync token with backend if user is already authenticated
        if (_currentToken != null && AuthSession.hasValidSession) {
          await sendTokenToServer(_currentToken);
        }
      } catch (tokenError) {
        debugPrint('[FCMService] Error fetching FCM token: $tokenError');
      }

      // 5. Handle Token Refresh
      messaging.onTokenRefresh.listen((String newToken) {
        _currentToken = newToken;
        print('==================== FCM TOKEN REFRESHED ====================');
        print('New FCM Token: $newToken');
        print('=============================================================');

        // Sync new token to backend if authenticated
        if (AuthSession.hasValidSession) {
          sendTokenToServer(newToken);
        }
      }).onError((err) {
        debugPrint('[FCMService] Error on token refresh: $err');
      });

      // 6. Foreground message handling
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCMService] Foreground notification received');
        debugPrint('[FCMService] Title: ${message.notification?.title}');
        debugPrint('[FCMService] Body: ${message.notification?.body}');
        debugPrint('[FCMService] Data: ${message.data}');
        NotificationsRepository.hasUnreadNotifier.value = true;
        NotificationsRepository.unreadCountNotifier.value += 1;
      });

      // 7. Notification tap handling when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCMService] Notification opened from background: ${message.messageId}');
        _handleMessageInteraction(message);
      });

      // 8. Notification tap handling when app is launched from terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCMService] App launched from terminated state via notification: ${initialMessage.messageId}');
        _handleMessageInteraction(initialMessage);
      }
    } catch (e, stackTrace) {
      debugPrint('[FCMService] Error initializing FCM: $e');
      debugPrint('[FCMService] StackTrace: $stackTrace');
    }
  }

  /// Sends the FCM token to backend for the authenticated delivery partner.
  /// `POST /mobile/v1/delivery_partners/fcm-token`
  /// Body: `{"fcmToken": "...", "deviceType": "android"|"ios"}`
  /// Headers: `Authorization: Bearer <jwt_token>`, `Content-Type: application/json`
  static Future<bool> sendTokenToServer([String? token]) async {
    final fcmToken = (token ?? _currentToken)?.trim();
    if (fcmToken == null || fcmToken.isEmpty) {
      debugPrint('[FCMService] sendTokenToServer skipped: No FCM token available');
      return false;
    }

    if (!AuthSession.hasValidSession) {
      debugPrint('[FCMService] sendTokenToServer postponed: No active auth session');
      return false;
    }

    final jwtToken = AuthSession.authToken?.trim();
    if (jwtToken == null || jwtToken.isEmpty) {
      debugPrint('[FCMService] sendTokenToServer skipped: JWT token is missing');
      return false;
    }

    final uri = ApiConfig.fcmTokenUri;
    debugPrint('[FCMService] Sending FCM token to backend: $uri');

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $jwtToken',
        },
        body: jsonEncode({
          'fcmToken': fcmToken,
          'deviceType': deviceType,
        }),
      );

      debugPrint('[FCMService] FCM token sync response: ${response.statusCode} - ${response.body}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[FCMService] FCM token registered successfully with backend');
        return true;
      } else {
        debugPrint('[FCMService] Failed to register FCM token: ${response.statusCode}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('[FCMService] Error sending FCM token to server: $e');
      debugPrint('[FCMService] StackTrace: $stackTrace');
      return false;
    }
  }

  /// Handles action or deep-link navigation on notification tap if needed without modifying existing UI
  static void _handleMessageInteraction(RemoteMessage message) {
    debugPrint('[FCMService] Processing message interaction: ${message.data}');
  }
}
