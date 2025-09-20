import 'package:geolocator/geolocator.dart';

class LocationService {
  const LocationService();

  Future<bool> isServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> currentPermission() async {
    return Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition();
  }

  Future<void> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  Future<void> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}
