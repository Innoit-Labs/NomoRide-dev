import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nomoride/core/services/auth_session.dart';
import 'package:nomoride/features/profile/data/models/delivery_partner_profile.dart';
import 'package:nomoride/features/profile/data/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProfileRepository.clearPersistedStatus();
    ProfileRepository.clearCache();
    AuthSession.authToken = 'mock_token';
  });

  tearDown(() async {
    await ProfileRepository.clearPersistedStatus();
    ProfileRepository.clearCache();
  });

  group('Delivery Partner Persistent Online/Offline Status Logic', () {
    test('First-time app installation: Default status is Offline when no status has ever been saved', () async {
      final status = await ProfileRepository.restoreOnlineStatus();

      expect(status, isFalse);
      expect(ProfileRepository.currentOnlineStatus, isFalse);
      expect(ProfileRepository.hasSavedStatus, isFalse);
    });

    test('Manual status change to Online: saves to SharedPreferences and updates backend', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('update_isonline'));
        expect(request.method, 'PUT');
        final body = jsonDecode(request.body);
        expect(body['is_online'], isTrue);

        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Status updated',
            'data': {'is_online': true},
          }),
          200,
        );
      });

      final repository = ProfileRepository(client: mockClient);
      final result = await repository.updateIsOnline(true);

      expect(result, isTrue);
      expect(ProfileRepository.currentOnlineStatus, isTrue);
      expect(ProfileRepository.hasSavedStatus, isTrue);

      // Verify SharedPreferences has persisted the status
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('dp_is_online_status'), isTrue);
    });

    test('App restart: If user selected Online, status remains Online after restarting the app', () async {
      // 1. User sets status to Online in session 1
      await ProfileRepository.saveOnlineStatus(true);
      expect(ProfileRepository.currentOnlineStatus, isTrue);

      // 2. Simulate app close/restart by clearing memory state (as happens on new process launch)
      ProfileRepository.clearCache();
      // Notice: we do NOT call clearPersistedStatus because disk storage survives restart!

      // 3. App initializes on launch/restart
      final restoredStatus = await ProfileRepository.restoreOnlineStatus();

      expect(restoredStatus, isTrue);
      expect(ProfileRepository.currentOnlineStatus, isTrue);
      expect(ProfileRepository.hasSavedStatus, isTrue);
    });

    test('App restart: If user selected Offline, status remains Offline after restarting the app', () async {
      // 1. User sets status to Offline in session 1
      await ProfileRepository.saveOnlineStatus(false);
      expect(ProfileRepository.currentOnlineStatus, isFalse);
      expect(ProfileRepository.hasSavedStatus, isTrue);

      // 2. Simulate app close/restart
      ProfileRepository.clearCache();

      // 3. App initializes on launch/restart
      final restoredStatus = await ProfileRepository.restoreOnlineStatus();

      expect(restoredStatus, isFalse);
      expect(ProfileRepository.currentOnlineStatus, isFalse);
      expect(ProfileRepository.hasSavedStatus, isTrue);
    });

    test('Do not reset status: API profile refreshes preserve the saved Online status', () async {
      // User is Online
      await ProfileRepository.saveOnlineStatus(true);
      expect(ProfileRepository.currentOnlineStatus, isTrue);

      // Backend returns profile payload where is_online might be false
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': 'dp_1',
              'full_name': 'Test Rider',
              'is_online': false,
            },
          }),
          200,
        );
      });

      final repository = ProfileRepository(client: mockClient);
      final profile = await repository.getProfile(forceRefresh: true);

      // The saved online status MUST be preserved and not overwritten!
      expect(ProfileRepository.currentOnlineStatus, isTrue);
      expect(profile.isOnline, isTrue);
    });

    test('Backend synchronization: synchronizes saved status with backend without resetting to default', () async {
      // User has saved Online status
      await ProfileRepository.saveOnlineStatus(true);
      expect(ProfileRepository.currentOnlineStatus, isTrue);

      bool putCalled = false;
      bool putValue = false;
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('update_isonline')) {
          putCalled = true;
          final body = jsonDecode(request.body);
          putValue = body['is_online'] as bool;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'is_online': putValue},
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final repository = ProfileRepository(client: mockClient);
      const backendProfileWithMismatch = DeliveryPartnerProfile(
        fullName: 'Test Rider',
        isOnline: false, // Backend was offline
      );

      // App initializes and checks backend sync
      await repository.syncSavedStatusWithBackend(backendProfileWithMismatch);

      // Backend was updated to match user's saved Online status
      expect(putCalled, isTrue);
      expect(putValue, isTrue);
      // Status remains Online!
      expect(ProfileRepository.currentOnlineStatus, isTrue);
    });
  });
}
