import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class OneSignalService {
  OneSignalService._();

  static const String _appId = '16716eed-10e5-419d-b21d-2168933dac42';
  static bool _isInitialized = false;

  /// Initializes OneSignal (once per process) and logs in the partner (on every successful auth).
  static Future<void> initialize({
    required String partnerId,
  }) async {
    debugPrint(
      '[OneSignalService] initialize() ENTERED with partnerId: $partnerId',
    );

    try {
      debugPrint('[OneSignalService] Checking initialization state');
      if (!_isInitialized) {
        debugPrint('[OneSignalService] Setting log level to verbose');
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

        debugPrint('[OneSignalService] Calling OneSignal.initialize');
        await OneSignal.initialize(_appId);
        _isInitialized = true;
        debugPrint('[OneSignalService] OneSignal.initialize SUCCESS');

        debugPrint('[OneSignalService] Requesting notification permission');
        await OneSignal.Notifications.requestPermission(true);
        debugPrint(
          '[OneSignalService] Notification permission request SUCCESS',
        );

        debugPrint('[OneSignalService] Adding push subscription observer');
        OneSignal.User.pushSubscription.addObserver((state) {
          print("========== ONESIGNAL PUSH STATE ==========");
          print("ID: ${state.current.id}");
          print("TOKEN: ${state.current.token}");
          print("OPTED IN: ${state.current.optedIn}");
          print("===========================================");
        });
      } else {
        debugPrint(
          '[OneSignalService] OneSignal already initialized. Skipping init step.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[OneSignalService] OneSignal.initialize FAILED: $e');
      debugPrint('[OneSignalService] STACK TRACE: $stackTrace');
    }

    try {
      debugPrint('[OneSignalService] Calling OneSignal.login');
      await OneSignal.login(partnerId);
      debugPrint('[OneSignalService] OneSignal.login SUCCESS');
    } catch (e, stackTrace) {
      debugPrint('[OneSignalService] OneSignal.login FAILED: $e');
      debugPrint('[OneSignalService] STACK TRACE: $stackTrace');
    }
  }

  /// Logs out the user from OneSignal.
  static Future<void> logout() async {
    try {
      debugPrint('[OneSignalService] OneSignal user logout started');
      await OneSignal.logout();
      debugPrint('[OneSignalService] OneSignal user logout completed');
    } catch (error) {
      debugPrint('[OneSignalService] Error during OneSignal logout: $error');
    }
  }
}
