import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/notifications/data/models/notification_model.dart';
import 'package:nomoride/features/notifications/data/notifications_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AuthSession.authToken = 'mock_jwt_token';
    NotificationsRepository.markAllLocallyRead();
  });

  tearDown(() {
    AuthSession.authToken = null;
    NotificationsRepository.markAllLocallyRead();
  });

  group('NotificationModel tests', () {
    test('NotificationModel.fromJson parses is_read and formats correctly', () {
      final json1 = {
        'id': 'notif-1',
        'title': 'Order Assigned',
        'message': 'You have a new order',
        'is_read': 0,
      };
      final model1 = NotificationModel.fromJson(json1);
      expect(model1.id, 'notif-1');
      expect(model1.title, 'Order Assigned');
      expect(model1.isRead, false);

      final json2 = {
        'notification_id': 'notif-2',
        'title': 'Order Delivered',
        'subtitle': 'Order completed',
        'isRead': true,
      };
      final model2 = NotificationModel.fromJson(json2);
      expect(model2.id, 'notif-2');
      expect(model2.message, 'Order completed');
      expect(model2.isRead, true);

      final copied = model1.copyWith(isRead: true);
      expect(copied.isRead, true);
      expect(copied.id, 'notif-1');
    });
  });

  group('NotificationsRepository tests', () {
    test('markNotificationsAsRead sends PUT request with notificationIds', () async {
      String? requestedMethod;
      String? requestedUri;
      Map<String, dynamic>? parsedBody;
      Map<String, String>? headers;

      final mockClient = MockClient((request) async {
        requestedMethod = request.method;
        requestedUri = request.url.toString();
        headers = request.headers;
        parsedBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Notifications marked as read successfully',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repository = NotificationsRepository(client: mockClient);
      NotificationsRepository.unreadCountNotifier.value = 2;
      NotificationsRepository.hasUnreadNotifier.value = true;

      final result = await repository.markNotificationsAsRead(['1d2938ab-3a1b-4b47-920f-02c381c810aa']);

      expect(result, isTrue);
      expect(requestedMethod, 'PUT');
      expect(requestedUri, ApiConfig.markReadNotificationsUri.toString());
      expect(headers?['authorization'], 'Bearer mock_jwt_token');
      expect(parsedBody?['notificationIds'], ['1d2938ab-3a1b-4b47-920f-02c381c810aa']);
      expect(NotificationsRepository.unreadCountNotifier.value, 1);
      expect(NotificationsRepository.hasUnreadNotifier.value, true);

      // Mark the second one
      await repository.markNotificationsAsRead(['another-id']);
      expect(NotificationsRepository.unreadCountNotifier.value, 0);
      expect(NotificationsRepository.hasUnreadNotifier.value, false);
    });

    test('getNotifications updates unread notifiers', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 'notif-1',
                'title': 'Unread Alert',
                'message': 'Hello',
                'is_read': 0,
              },
              {
                'id': 'notif-2',
                'title': 'Read Alert',
                'message': 'World',
                'is_read': 1,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repository = NotificationsRepository(client: mockClient);
      final list = await repository.getNotifications();

      expect(list.length, 2);
      expect(list[0].isRead, false);
      expect(list[1].isRead, true);
      expect(NotificationsRepository.hasUnreadNotifier.value, true);
      expect(NotificationsRepository.unreadCountNotifier.value, 1);
    });
  });
}
