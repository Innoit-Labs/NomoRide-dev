import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nomoride/core/network/api_exception.dart';

class LocationService {
  static const _locationRequiredStatuses = {
    'arrived',
    'confirm_pickup',
    'confirm_delivery',
  };

  static bool requiresLocationForStatus(String status) {
    return _locationRequiredStatuses.contains(status.trim().toLowerCase());
  }

  static Future<({double latitude, double longitude})> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const ApiException(
          'Please enable location services to continue.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw const ApiException(
          'Location permission is required to confirm this step.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw const ApiException(
          'Location permission is permanently denied. Enable it in app settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      return (latitude: position.latitude, longitude: position.longitude);
    } on MissingPluginException {
      throw const ApiException(
        'Location plugin is not ready. Stop the app completely and run it again.',
      );
    } on PlatformException catch (error) {
      throw ApiException(
        error.message ?? 'Unable to read your current location.',
      );
    }
  }
}
