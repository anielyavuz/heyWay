import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

import '../config/api_keys.dart';
import '../data/sample_venues.dart';
import '../models/venue.dart';
import '../services/foursquare_service.dart';

class VenueSearchProvider extends ChangeNotifier {
  VenueSearchProvider({FoursquareService? service})
    : _service = service ?? FoursquareService();

  final FoursquareService _service;

  String _query = '';
  List<Venue> _results = sampleVenues;
  bool _isLoading = false;
  String? _errorMessage;
  double? _latitude;
  double? _longitude;

  String get query => _query;
  List<Venue> get results => _results;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRemoteEnabled => _service.isEnabled;

  void updateLocation(Position? position) {
    if (position == null) return;
    final lat = position.latitude;
    final lng = position.longitude;
    if (_latitude == lat && _longitude == lng) return;
    _latitude = lat;
    _longitude = lng;
    if (_query.trim().isNotEmpty && _service.isEnabled) {
      _performSearch();
    }
  }

  Future<void> updateQuery(String value) async {
    _query = value;
    await _performSearch();
  }

  Future<void> _performSearch() async {
    final trimmed = _query.trim();

    if (trimmed.isEmpty) {
      _isLoading = false;
      _errorMessage = null;
      _results = sampleVenues;
      notifyListeners();
      return;
    }

    if (!_service.isEnabled || _latitude == null || _longitude == null) {
      _isLoading = false;
      _errorMessage = _service.isEnabled
          ? null
          : 'Set FOURSQUARE_API_KEY to fetch live venues.';
      _results = _filterSample(trimmed);
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final remote = await _service.search(
        latitude: _latitude!,
        longitude: _longitude!,
        query: trimmed,
      );

      if (remote.isEmpty) {
        _results = _filterSample(trimmed);
      } else {
        _results = remote;
      }
    } catch (error) {
      _errorMessage = error.toString();
      _results = _filterSample(trimmed);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Venue> _filterSample(String value) {
    final trimmed = value.toLowerCase();
    return sampleVenues.where((venue) {
      final nameMatch = venue.name.toLowerCase().contains(trimmed);
      final categoryMatch = venue.category.toLowerCase().contains(trimmed);
      final amenityMatch = venue.amenities.whereType<String>().any(
        (amenity) => amenity.toLowerCase().contains(trimmed),
      );
      return nameMatch || categoryMatch || amenityMatch;
    }).toList();
  }
}
