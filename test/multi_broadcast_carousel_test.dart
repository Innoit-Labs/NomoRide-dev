import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomoride/core/utils/size_utils.dart';
import 'package:nomoride/features/orders/data/models/order_broadcast_model.dart';
import 'package:nomoride/features/orders/presentation/widgets/order_broadcast_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OrderBroadcastModel Tests', () {
    test('parses broadcast_id, order_id, distance_km, item_count, and kit_details', () {
      final json = {
        'broadcast_id': 'bcast-999',
        'order_id': 'ord-123',
        'order_number': 'NOMO_ORD-441',
        'flow_type': 'delivery',
        'package_type': 'express',
        'distance_km': 3.42,
        'item_count': 4,
        'kit_details': {'kit_type': 'Wardrobe Kit'},
        'pickup_address': 'Store A',
        'delivery_address': 'Customer B',
        'timer_seconds': 25,
      };

      final model = OrderBroadcastModel.fromJson(json);

      expect(model.broadcastId, 'bcast-999');
      expect(model.orderId, 'ord-123');
      expect(model.orderNumber, 'NOMO_ORD-441');
      expect(model.flowType, 'delivery');
      expect(model.distanceKm, 3.42);
      expect(model.formattedDistance, '3.4 km');
      expect(model.itemCount, 4);
      expect(model.itemsCountLabel, '4 Items');
      expect(model.kitDetails, 'Wardrobe Kit');
      expect(model.kitDetailsLabel, 'Wardrobe Kit');
      expect(model.timerSeconds, 25);
      expect(model.uniqueId, 'bcast-999');
    });

    test('calculates distance using haversine if coordinates exist without distance_km', () {
      final json = {
        'order_id': 'ord-calc',
        'order_number': 'NOMO_ORD-442',
        'flow_type': 'return',
        'pickup_address': 'Kukatpally',
        'pickup_latitude': 17.4948,
        'pickup_longitude': 78.3996,
        'delivery_address': 'Hitech City',
        'delivery_latitude': 17.4458,
        'delivery_longitude': 78.3980,
      };

      final model = OrderBroadcastModel.fromJson(json);

      expect(model.distanceKm, isNotNull);
      expect(model.distanceKm!, greaterThan(4.0));
      expect(model.distanceKm!, lessThan(7.0));
      expect(model.formattedDistance, contains('km'));
    });
  });

  group('OrderBroadcastManager State & Queue Tests', () {
    late OrderBroadcastManager manager;

    setUp(() {
      manager = OrderBroadcastManager.instance;
      manager.dismissAll();
    });

    tearDown(() {
      manager.dismissAll();
    });

    test('maintains activeBroadcasts list and ignores duplicates', () {
      const b1 = OrderBroadcastModel(
        broadcastId: 'b-1',
        orderId: 'ord-1',
        orderNumber: 'NOMO-1',
        flowType: 'delivery',
        packageType: 'standard',
        earningAmount: 50.0,
        formattedEarning: '₹50.00',
        pickupAddress: 'Hub',
        deliveryAddress: 'Customer',
        customerName: 'Alice',
        customerMobile: '9999999999',
        timerSeconds: 30,
      );

      const b1Duplicate = OrderBroadcastModel(
        broadcastId: 'b-1',
        orderId: 'ord-1',
        orderNumber: 'NOMO-1',
        flowType: 'delivery',
        packageType: 'standard',
        earningAmount: 50.0,
        formattedEarning: '₹50.00',
        pickupAddress: 'Hub',
        deliveryAddress: 'Customer',
        customerName: 'Alice',
        customerMobile: '9999999999',
        timerSeconds: 30,
      );

      const b2 = OrderBroadcastModel(
        broadcastId: 'b-2',
        orderId: 'ord-2',
        orderNumber: 'NOMO-2',
        flowType: 'return',
        packageType: 'wardrobe',
        earningAmount: 75.0,
        formattedEarning: '₹75.00',
        pickupAddress: 'Customer',
        deliveryAddress: 'Hub',
        customerName: 'Bob',
        customerMobile: '8888888888',
        timerSeconds: 30,
      );

      expect(manager.activeBroadcasts, isEmpty);

      // Add first broadcast
      manager.startBroadcast(b1);
      expect(manager.activeBroadcasts.length, 1);
      expect(manager.activeOrderIds, ['ord-1']);

      // Add duplicate broadcast - must be ignored
      manager.startBroadcast(b1Duplicate);
      expect(manager.activeBroadcasts.length, 1);

      // Add second broadcast
      manager.startBroadcast(b2);
      expect(manager.activeBroadcasts.length, 2);
      expect(manager.activeOrderIds, ['ord-1', 'ord-2']);

      // Dismiss first order specifically
      manager.dismissOrder('ord-1', reason: 'Claimed by other');
      expect(manager.activeBroadcasts.length, 1);
      expect(manager.activeOrderIds, ['ord-2']);

      // Dismiss second order
      manager.dismissOrder('ord-2');
      expect(manager.activeBroadcasts.length, 0);
    });

    test('adjusts active page index when an item is removed', () {
      const b1 = OrderBroadcastModel(
        orderId: 'ord-1',
        orderNumber: 'NOMO-1',
        flowType: 'delivery',
        packageType: 'standard',
        earningAmount: 50.0,
        formattedEarning: '₹50.00',
        pickupAddress: 'Hub',
        deliveryAddress: 'Customer',
        customerName: 'Alice',
        customerMobile: '9999999999',
      );
      const b2 = OrderBroadcastModel(
        orderId: 'ord-2',
        orderNumber: 'NOMO-2',
        flowType: 'delivery',
        packageType: 'standard',
        earningAmount: 60.0,
        formattedEarning: '₹60.00',
        pickupAddress: 'Hub',
        deliveryAddress: 'Customer',
        customerName: 'Bob',
        customerMobile: '8888888888',
      );

      manager.startBroadcast(b1);
      manager.startBroadcast(b2);
      expect(manager.activeBroadcasts.length, 2);

      // Suppose user was looking at page 1
      manager.currentPageIndex = 1;
      expect(manager.currentPageIndex, 1);

      // Remove ord-2 (the current page)
      manager.dismissOrder('ord-2');
      expect(manager.activeBroadcasts.length, 1);
      // Current page clamped back to 0
      expect(manager.currentPageIndex, 0);
    });
  });

  group('OrderBroadcastCarouselDialog Widget Tests', () {
    late OrderBroadcastManager manager;

    setUp(() {
      manager = OrderBroadcastManager.instance;
      manager.dismissAll();
    });

    tearDown(() {
      manager.dismissAll();
    });

    testWidgets('renders single broadcast card without pagination dots', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      manager.startBroadcast(const OrderBroadcastModel(
        orderId: 'ord-single',
        orderNumber: 'NOMO-SINGLE',
        flowType: 'delivery',
        packageType: 'standard',
        earningAmount: 80.0,
        formattedEarning: '₹80.00',
        pickupAddress: 'Pickup Hub',
        deliveryAddress: 'Delivery Address',
        customerName: 'Customer A',
        customerMobile: '9999999999',
        distanceKm: 2.5,
        itemCount: 2,
        timerSeconds: 30,
      ));

      await tester.pumpWidget(
        Sizer(
          builder: (context, orientation, deviceType) => const MaterialApp(
            home: Scaffold(
              body: OrderBroadcastCarouselDialog(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('NEW ORDER REQUEST'), findsOneWidget);
      expect(find.text('#NOMO-SINGLE'), findsOneWidget);
      expect(find.text('₹80.00'), findsOneWidget);
      expect(find.text('2.5 km'), findsOneWidget);
      expect(find.text('2 Items'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Accept Order'), findsOneWidget);
      expect(find.textContaining('Incoming Orders:'), findsNothing);

      manager.dismissAll();
    });

    testWidgets('renders multiple broadcast cards with counter badge and pagination dots', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      manager.startBroadcast(const OrderBroadcastModel(
        orderId: 'ord-1',
        orderNumber: 'NOMO-1',
        flowType: 'delivery',
        packageType: 'standard',
        earningAmount: 50.0,
        formattedEarning: '₹50.00',
        pickupAddress: 'Hub 1',
        deliveryAddress: 'Delivery 1',
        customerName: 'User 1',
        customerMobile: '1111111111',
        timerSeconds: 30,
      ));

      manager.startBroadcast(const OrderBroadcastModel(
        orderId: 'ord-2',
        orderNumber: 'NOMO-2',
        flowType: 'return',
        packageType: 'standard',
        earningAmount: 70.0,
        formattedEarning: '₹70.00',
        pickupAddress: 'Hub 2',
        deliveryAddress: 'Delivery 2',
        customerName: 'User 2',
        customerMobile: '2222222222',
        timerSeconds: 30,
      ));

      await tester.pumpWidget(
        Sizer(
          builder: (context, orientation, deviceType) => const MaterialApp(
            home: Scaffold(
              body: OrderBroadcastCarouselDialog(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Top Counter badge for 2 orders
      expect(find.text('Incoming Orders: 1 of 2'), findsOneWidget);
      expect(find.text('Swipe'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);

      // Swipe PageView to next order
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pump(const Duration(milliseconds: 400));

      // Verify counter badge updated to 2 of 2
      expect(find.text('Incoming Orders: 2 of 2'), findsOneWidget);
      expect(find.text('#NOMO-2'), findsOneWidget);
      expect(find.text('₹70.00'), findsOneWidget);

      manager.dismissAll();
    });
  });
}
