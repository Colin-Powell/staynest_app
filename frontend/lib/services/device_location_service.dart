import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:property_app/session/app_session.dart';

class DeviceLocationService {
  DeviceLocationService._();

  static final DeviceLocationService instance = DeviceLocationService._();

  Future<Position?>? _initialization;

  Future<Position?> initialize() {
    final inFlight = _initialization;
    if (inFlight != null) return inFlight;

    late final Future<Position?> attempt;
    attempt = _requestDeviceLocation().whenComplete(() {
      if (identical(_initialization, attempt)) _initialization = null;
    });
    _initialization = attempt;
    return attempt;
  }

  Future<Position?> _requestDeviceLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      final lastKnown = await _getLastKnownPosition();
      if (lastKnown != null) {
        _storePosition(lastKnown);
        return lastKnown;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 30),
      );
      _storePosition(position);
      return position;
    } catch (error) {
      debugPrint('[Location] Device location unavailable: $error');
      final lastKnown = await _getLastKnownPosition();
      if (lastKnown == null) return null;
      _storePosition(lastKnown);
      return lastKnown;
    }
  }

  Future<Position?> _getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  void _storePosition(Position position) {
    AppSession.deviceLatitude = position.latitude;
    AppSession.deviceLongitude = position.longitude;
  }
}
