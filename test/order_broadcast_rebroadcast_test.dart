import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/core/services/socket_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Order Broadcast Re-broadcast & Dismiss Tests', () {
    test('SocketService does not ignore orders when decline or dismiss is clicked', () {
      final socketService = SocketService.instance;

      // Simulate an order being declined/dismissed
      socketService.ignoreOrder('order_12345');

      // Verify that isOrderIgnored remains false so future broadcasts are not suppressed
      expect(socketService.isOrderIgnored('order_12345'), isFalse);
    });
  });
}
