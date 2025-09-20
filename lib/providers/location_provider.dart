import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

enum LocationStatus { unknown, disabled, denied, granted }

class LocationProvider extends ChangeNotifier {
  LocationProvider({LocationService? service})
    : _service = service ?? const LocationService();

  final LocationService _service;

  LocationStatus _status = LocationStatus.unknown;
  Position? _position;
  bool _isRequesting = false;
  String? _error;
  LocationPermission _lastPermission = LocationPermission.denied;
  bool _useStaticLocation = false;

  LocationStatus get status => _status;
  Position? get position => _position;
  bool get isRequesting => _isRequesting;
  String? get error => _error;
  bool get useStaticLocation => _useStaticLocation;
  bool get canRequestPermission =>
      _lastPermission != LocationPermission.deniedForever;
  bool get isDeniedForever =>
      _lastPermission == LocationPermission.deniedForever;

  static Position _staticPosition() => Position(
    latitude: 40.936,
    longitude: 29.155,
    timestamp: DateTime.now(),
    accuracy: 1,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
    isMocked: true,
  );

  Future<void> initialize() async {
    if (_useStaticLocation) {
      _applyStaticLocation();
      return;
    }

    final enabled = await _service.isServiceEnabled();
    if (!enabled) {
      _status = LocationStatus.disabled;
      notifyListeners();
      return;
    }

    final permission = await _service.currentPermission();
    _lastPermission = permission;
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      await _fetchPosition();
    } else if (permission == LocationPermission.deniedForever) {
      _status = LocationStatus.denied;
      notifyListeners();
    } else {
      _status = LocationStatus.unknown;
      notifyListeners();
    }
  }

  Future<void> requestPermissionAndFetch() async {
    if (_useStaticLocation || _isRequesting) return;
    _isRequesting = true;
    _error = null;
    notifyListeners();

    try {
      final enabled = await _service.isServiceEnabled();
      if (!enabled) {
        _status = LocationStatus.disabled;
        return;
      }

      final permission = await _service.requestPermission();
      _lastPermission = permission;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _status = LocationStatus.denied;
        return;
      }

      await _fetchPosition();
    } catch (error) {
      _error = error.toString();
    } finally {
      _isRequesting = false;
      notifyListeners();
    }
  }

  Future<void> _fetchPosition() async {
    try {
      _status = LocationStatus.granted;
      _position = await _service.getCurrentPosition();
    } catch (error) {
      _error = error.toString();
      _status = LocationStatus.denied;
    }
    notifyListeners();
  }

  Future<void> openAppSettings() async {
    await _service.openAppSettings();
  }

  Future<void> openLocationSettings() async {
    await _service.openLocationSettings();
  }

  Future<void> setUseStaticLocation(bool value) async {
    if (_useStaticLocation == value) return;
    _useStaticLocation = value;
    if (value) {
      _applyStaticLocation();
    } else {
      await initialize();
    }
  }

  void _applyStaticLocation() {
    _status = LocationStatus.granted;
    _position = _staticPosition();
    _error = null;
    _lastPermission = LocationPermission.always;
    notifyListeners();
  }
}
