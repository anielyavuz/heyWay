import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

import '../models/venue.dart';
import '../services/poi_provider.dart';
import '../services/poi_provider_manager.dart';
import '../services/venue_cache_service.dart';
import '../services/firestore_service.dart';

class VenueSearchProvider extends ChangeNotifier {
  VenueSearchProvider({PoiProvider? poiProvider}) {
    _poiProvider = poiProvider ?? PoiProviderManager();
    _venueCacheService = VenueCacheService(
      firestoreService: FirestoreService(),
      poiProvider: _poiProvider,
    );
  }

  late final PoiProvider _poiProvider;
  late final VenueCacheService _venueCacheService;

  String _query = '';
  List<Venue> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  double? _latitude;
  double? _longitude;

  String get query => _query;
  List<Venue> get results => _results;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRemoteEnabled => _poiProvider.isEnabled;
  
  String get providerName => _poiProvider.name;

  void updateLocation(Position? position) {
    if (position == null) return;
    final lat = position.latitude;
    final lng = position.longitude;
    if (_latitude == lat && _longitude == lng) return;
    _latitude = lat;
    _longitude = lng;
    if (_query.trim().isNotEmpty && _poiProvider.isEnabled) {
      _performSearch();
    } else if (_query.trim().isEmpty && _poiProvider.isEnabled) {
      _loadNearbyPopularVenues();
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
      _results = [];
      notifyListeners();
      return;
    }

    if (!_poiProvider.isEnabled || _latitude == null || _longitude == null) {
      _isLoading = false;
      _errorMessage = _poiProvider.isEnabled
          ? null
          : 'Provider: ${_poiProvider.name} - Configure API keys for live data.';
      _results = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final remote = await _venueCacheService.searchVenuesWithCache(
        latitude: _latitude!,
        longitude: _longitude!,
        query: trimmed,
      );

      _results = remote;
    } catch (error) {
      _errorMessage = error.toString();
      _results = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadNearbyPopularVenues() async {
    if (!_poiProvider.isEnabled || _latitude == null || _longitude == null) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final List<Future<List<Venue>>> searches = [
        // 2 cafes
        _venueCacheService.searchVenuesWithCache(
          latitude: _latitude!,
          longitude: _longitude!,
          query: 'cafe',
        ),
        // 2 restaurants
        _venueCacheService.searchVenuesWithCache(
          latitude: _latitude!,
          longitude: _longitude!,
          query: 'restaurant',
        ),
        // 2 entertainment venues
        _venueCacheService.searchVenuesWithCache(
          latitude: _latitude!,
          longitude: _longitude!,
          query: 'entertainment',
        ),
      ];

      final results = await Future.wait(searches);
      
      final List<Venue> combinedResults = [];
      
      // Take 2 from each category
      if (results[0].isNotEmpty) combinedResults.addAll(results[0].take(2));
      if (results[1].isNotEmpty) combinedResults.addAll(results[1].take(2));
      if (results[2].isNotEmpty) combinedResults.addAll(results[2].take(2));
      
      _results = combinedResults;
    } catch (error) {
      _errorMessage = error.toString();
      _results = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

}
