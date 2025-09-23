import 'package:geolocator/geolocator.dart';

import '../models/venue.dart';

String? formatVenueDistance(Position? position, Venue venue) {
  final geoPoint = venue.location.geoPoint;
  if (position == null || geoPoint == null) {
    return null;
  }

  final distanceInMeters = Geolocator.distanceBetween(
    position.latitude,
    position.longitude,
    geoPoint.latitude,
    geoPoint.longitude,
  );

  if (distanceInMeters.isNaN || distanceInMeters.isInfinite) {
    return null;
  }

  if (distanceInMeters >= 1000) {
    final distanceInKm = distanceInMeters / 1000;
    final formatted = distanceInKm >= 10
        ? distanceInKm.toStringAsFixed(0)
        : distanceInKm.toStringAsFixed(1);
    return '$formatted km uzakta';
  }

  return '${distanceInMeters.round()} m uzakta';
}
