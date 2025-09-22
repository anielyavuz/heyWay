import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
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

  Timer? _searchDebounce;
  int _searchSequence = 0;

  static const List<String> _defaultCuratedKeywords = [
    'cafe',
    'coffee',
    'kafe',
    'restaurant',
    'restoran',
    'bar',
    'pub',
    'nightlife',
    'club',
    'entertainment',
    'eğlence',
    'social',
    'sosyal',
    'market',
    'shopping',
    'mall',
  ];

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
      loadNearbyPopularVenues();
    }
  }

  Future<void> getCurrentLocationAndUpdate() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latitude = position.latitude;
      _longitude = position.longitude;
    } catch (e) {
      // Handle location errors silently
    }
  }

  Future<void> updateQuery(String value, {bool immediate = false}) async {
    final previousQuery = _query;
    _query = value;
    final trimmed = value.trim();

    if (immediate) {
      _searchDebounce?.cancel();
      _searchDebounce = null;
      _searchSequence++;
      await _performSearch();
      return;
    }

    if (trimmed.isEmpty) {
      _searchDebounce?.cancel();
      _searchDebounce = null;
      _searchSequence++;
      _isLoading = false;
      _errorMessage = null;
      _results = [];
      notifyListeners();
      return;
    }

    if (previousQuery == value && _searchDebounce != null) {
      return;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(seconds: 2), () {
      _searchSequence++;
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final trimmed = _query.trim();
    final currentSequence = _searchSequence;

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

      if (currentSequence != _searchSequence) {
        return;
      }

      _results = remote;
    } catch (error) {
      if (currentSequence != _searchSequence) {
        return;
      }

      _errorMessage = error.toString();
      _results = [];
    } finally {
      if (currentSequence == _searchSequence) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadNearbyPopularVenues({
    int limit = 6,
    List<String>? keywordFilters,
  }) async {
    if (_latitude == null || _longitude == null) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final keywords = (keywordFilters == null)
        ? _defaultCuratedKeywords
        : keywordFilters;
    final normalizedKeywords = keywords
        .where((keyword) => keyword.trim().isNotEmpty)
        .map((keyword) => keyword.toLowerCase())
        .toSet()
        .toList(growable: false);

    try {
      final seedVenues = await _venueCacheService.getNearbyPopularVenues(
        latitude: _latitude!,
        longitude: _longitude!,
        limit: math.max(limit * 3, limit),
      );

      final curated = <Venue>[];
      final seenIds = <String>{};

      if (seedVenues.isNotEmpty) {
        _appendVenues(
          results: curated,
          additions: seedVenues,
          seenIds: seenIds,
          keywords: normalizedKeywords,
          limit: limit,
          requireKeywordMatch: normalizedKeywords.isNotEmpty,
        );

        if (curated.length < limit) {
          _appendVenues(
            results: curated,
            additions: seedVenues,
            seenIds: seenIds,
            keywords: normalizedKeywords,
            limit: limit,
            requireKeywordMatch: false,
          );
        }
      }

      if (curated.length < limit && _poiProvider.isEnabled) {
        final keywordsForSearch = normalizedKeywords.isEmpty
            ? <String>['popular places']
            : normalizedKeywords;

        for (final keyword in keywordsForSearch) {
          final extraVenues = await _venueCacheService.searchVenuesWithCache(
            latitude: _latitude!,
            longitude: _longitude!,
            query: keyword,
            limit: limit,
            forceCache: curated.isEmpty,
          );

          _appendVenues(
            results: curated,
            additions: extraVenues,
            seenIds: seenIds,
            keywords: normalizedKeywords,
            limit: limit,
            requireKeywordMatch: normalizedKeywords.isNotEmpty,
          );

          if (curated.length >= limit) {
            break;
          }
        }
      }

      if (curated.length < limit && seedVenues.isNotEmpty) {
        _appendVenues(
          results: curated,
          additions: seedVenues,
          seenIds: seenIds,
          keywords: normalizedKeywords,
          limit: limit,
          requireKeywordMatch: false,
        );
      }

      _results = _sortVenuesByDistance(curated).take(limit).toList();
    } catch (error) {
      _errorMessage = error.toString();
      _results = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreNearbyVenues() async {
    if (_latitude == null || _longitude == null || _isLoading) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Load more venues with higher limit
      final moreVenues = await _venueCacheService.getNearbyPopularVenues(
        latitude: _latitude!,
        longitude: _longitude!,
        limit: 20, // Get more venues
      );

      if (moreVenues.isNotEmpty) {
        // Remove duplicates and add new venues
        final currentIds = _results.map((v) => v.id).toSet();
        final newVenues = moreVenues
            .where((v) => !currentIds.contains(v.id))
            .toList();
        _results.addAll(newVenues);
      }
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Venue> createManualVenue(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Venue name cannot be empty');
    }

    if (_latitude == null || _longitude == null) {
      await getCurrentLocationAndUpdate();
    }

    final docRef = FirebaseFirestore.instance.collection('venues').doc();
    final geoPoint = (_latitude != null && _longitude != null)
        ? GeoPoint(_latitude!, _longitude!)
        : null;

    final venue = Venue(
      id: docRef.id,
      name: trimmed,
      category: 'Manual Entry',
      location: VenueLocation(
        geoPoint: geoPoint,
        geohash: geoPoint != null
            ? _encodeGeohash(_latitude!, _longitude!)
            : '',
      ),
      addressSummary: 'Topluluk tarafından eklendi',
      ownerId: null,
      amenities: const [],
      rating: const RatingSummary(average: 0.0, count: 0),
      trendingScore: 0.0,
      coverPhotoUrl: '',
    );

    await FirestoreService().upsertVenue(venue);

    _results = [
      venue,
      ..._results.where((existing) => existing.id != venue.id),
    ];
    notifyListeners();

    return venue;
  }

  void _appendVenues({
    required List<Venue> results,
    required Iterable<Venue> additions,
    required Set<String> seenIds,
    required List<String> keywords,
    required int limit,
    required bool requireKeywordMatch,
  }) {
    final additionsList = List<Venue>.from(additions);
    if (additionsList.isEmpty) {
      return;
    }

    final sortedAdditions = _sortVenuesByDistance(additionsList);
    for (final venue in sortedAdditions) {
      if (results.length >= limit) {
        break;
      }
      if (seenIds.contains(venue.id)) {
        continue;
      }
      if (requireKeywordMatch && !_matchesKeywords(venue, keywords)) {
        continue;
      }
      results.add(venue);
      seenIds.add(venue.id);
    }
  }

  List<Venue> _sortVenuesByDistance(List<Venue> venues) {
    if (_latitude == null || _longitude == null) {
      return List<Venue>.from(venues);
    }

    final userLat = _latitude!;
    final userLng = _longitude!;
    final sorted = List<Venue>.from(venues);

    sorted.sort((a, b) {
      final aPoint = a.location.geoPoint;
      final bPoint = b.location.geoPoint;

      if (aPoint == null && bPoint == null) return 0;
      if (aPoint == null) return 1;
      if (bPoint == null) return -1;

      final aDistance = _calculateDistance(
        userLat,
        userLng,
        aPoint.latitude,
        aPoint.longitude,
      );
      final bDistance = _calculateDistance(
        userLat,
        userLng,
        bPoint.latitude,
        bPoint.longitude,
      );

      return aDistance.compareTo(bDistance);
    });

    return sorted;
  }

  bool _matchesKeywords(Venue venue, List<String> keywords) {
    if (keywords.isEmpty) {
      return true;
    }

    final searchable = '${venue.name} ${venue.category}'
        .toLowerCase()
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');

    return keywords.any((keyword) {
      final normalizedKeyword = keyword
          .toLowerCase()
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ı', 'i')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c');
      return searchable.contains(normalizedKeyword);
    });
  }

  double _calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = _degreesToRadians(endLat - startLat);
    final dLng = _degreesToRadians(endLng - startLng);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(startLat)) *
            math.cos(_degreesToRadians(endLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * (math.pi / 180.0);

  String _encodeGeohash(
    double latitude,
    double longitude, {
    int precision = 9,
  }) {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    final latInterval = [-90.0, 90.0];
    final lngInterval = [-180.0, 180.0];
    final buffer = StringBuffer();

    bool isEvenBit = true;
    int bit = 0;
    int ch = 0;

    while (buffer.length < precision) {
      if (isEvenBit) {
        final mid = (lngInterval[0] + lngInterval[1]) / 2;
        if (longitude >= mid) {
          ch = (ch << 1) + 1;
          lngInterval[0] = mid;
        } else {
          ch = (ch << 1);
          lngInterval[1] = mid;
        }
      } else {
        final mid = (latInterval[0] + latInterval[1]) / 2;
        if (latitude >= mid) {
          ch = (ch << 1) + 1;
          latInterval[0] = mid;
        } else {
          ch = (ch << 1);
          latInterval[1] = mid;
        }
      }

      isEvenBit = !isEvenBit;
      bit++;

      if (bit == 5) {
        buffer.write(base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
