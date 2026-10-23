import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/core/services/socket_service.dart';
import 'package:nomoride/features/home/data/models/dp_order.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Screen Real-Time Order Updates Tests', () {
    test('SocketService emits order update notification on notifyOrderUpdate', () async {
      final socketService = SocketService.instance;
      final completer = Completer<bool>();

      final subscription = socketService.onOrderUpdate.listen((_) {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      });

      socketService.notifyOrderUpdate();

      final result = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );

      expect(result, isTrue);
      await subscription.cancel();
    });

    test('Order list deduplication logic removes duplicate order entries', () {
      final rawOrders = [
        const DpOrder(
          id: 'ord-1',
          orderNumber: 'NOMO_ORD-101',
          status: 'assigned',
        ),
        const DpOrder(
          id: 'ord-1',
          orderNumber: 'NOMO_ORD-101',
          status: 'assigned',
        ),
        const DpOrder(
          id: 'ord-2',
          orderNumber: 'NOMO_ORD-102',
          status: 'assigned',
        ),
      ];

      final seen = <String>{};
      final uniqueOrders = rawOrders.where((order) {
        final key = order.orderNumber.isNotEmpty ? order.orderNumber : (order.id ?? '');
        return key.isNotEmpty && seen.add(key);
      }).toList();

      expect(uniqueOrders.length, equals(2));
      expect(uniqueOrders[0].orderNumber, equals('NOMO_ORD-101'));
      expect(uniqueOrders[1].orderNumber, equals('NOMO_ORD-102'));
    });
  });
}
