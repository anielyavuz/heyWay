import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../models/venue.dart';
import 'poi_provider.dart';

class GooglePlacesService implements PoiProvider {
  GooglePlacesService({http.Client? client}) : _client = client ?? http.Client();

  static const _nearbySearchUrl = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const _textSearchUrl = 'https://maps.googleapis.com/maps/api/place/textsearch/json';
  static const _placeDetailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json';

  final http.Client _client;

  @override
  bool get isEnabled => googlePlacesApiKey.isNotEmpty;

  @override
  String get name => 'Google Places';

  void _debugLog(String message) {
    assert(() {
      debugPrint('[GooglePlacesService] $message');
      return true;
    }());
  }

  @override
  Future<List<Venue>> searchVenues({
    required double latitude,
    required double longitude,
    required String query,
    int limit = 12,
    int? radius,
  }) async {
    if (!isEnabled) return const [];

    // Use text search for query-based searches
    if (query.trim().isNotEmpty) {
      return _textSearch(
        query: query,
        latitude: latitude,
        longitude: longitude,
        limit: limit,
        radius: radius,
      );
    } else {
      return _nearbySearch(
        latitude: latitude,
        longitude: longitude,
        limit: limit,
        radius: radius,
      );
    }
  }

  Future<List<Venue>> _textSearch({
    required String query,
    required double latitude,
    required double longitude,
    int limit = 12,
    int? radius,
  }) async {
    final uri = Uri.parse(_textSearchUrl).replace(
      queryParameters: {
        'query': query,
        'location': '$latitude,$longitude',
        'radius': '${radius ?? 2000}',
        'key': googlePlacesApiKey,
        'fields': 'place_id,name,geometry,rating,user_ratings_total,types,formatted_address,photos,price_level',
      },
    );

    return _makeRequest(uri, limit);
  }

  Future<List<Venue>> _nearbySearch({
    required double latitude,
    required double longitude,
    int limit = 12,
    int? radius,
  }) async {
    final uri = Uri.parse(_nearbySearchUrl).replace(
      queryParameters: {
        'location': '$latitude,$longitude',
        'radius': '${radius ?? 2000}',
        'type': 'establishment',
        'key': googlePlacesApiKey,
      },
    );

    return _makeRequest(uri, limit);
  }

  Future<List<Venue>> _makeRequest(Uri uri, int limit) async {
    _debugLog('Request → $uri');

    final response = await _client.get(uri);
    
    _debugLog('Status ← ${response.statusCode}');

    if (response.statusCode != 200) {
      _debugLog('Body ← ${response.body}');
      throw Exception('Google Places request failed: ${response.statusCode}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      _debugLog('Error Status ← $status');
      throw Exception('Google Places API error: $status');
    }

    final results = body['results'] as List<dynamic>? ?? const [];

    assert(() {
      debugPrint('[GooglePlacesService] Body ← ${response.body}');
      return true;
    }());

    return results
        .take(limit)
        .map((item) => _mapVenue(item))
        .toList();
  }

  @override
  Future<Venue?> getVenueDetails(String venueId) async {
    if (!isEnabled) return null;

    final uri = Uri.parse(_placeDetailsUrl).replace(
      queryParameters: {
        'place_id': venueId,
        'fields': 'place_id,name,geometry,rating,user_ratings_total,types,formatted_address,photos,price_level,opening_hours,website,formatted_phone_number',
        'key': googlePlacesApiKey,
      },
    );

    _debugLog('Details Request → $uri');

    final response = await _client.get(uri);
    
    _debugLog('Details Status ← ${response.statusCode}');

    if (response.statusCode != 200) {
      _debugLog('Details Body ← ${response.body}');
      return null;
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    
    if (status != 'OK') {
      _debugLog('Details Error Status ← $status');
      return null;
    }

    final result = body['result'] as Map<String, dynamic>?;
    if (result == null) return null;

    return _mapVenue(result);
  }

  @override
  Future<List<Venue>> getTrendingVenues({
    required double latitude,
    required double longitude,
    int limit = 12,
    int? radius,
  }) async {
    // Use nearby search without specific query for popular places
    return _nearbySearch(
      latitude: latitude,
      longitude: longitude,
      limit: limit,
      radius: radius,
    );
  }

  Venue _mapVenue(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    
    // Extract location
    final geometry = map['geometry'] as Map<String, dynamic>? ?? {};
    final location = geometry['location'] as Map<String, dynamic>? ?? {};
    final latitude = (location['lat'] as num?)?.toDouble();
    final longitude = (location['lng'] as num?)?.toDouble();

    // Extract rating information
    final rating = (map['rating'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (map['user_ratings_total'] as num?)?.toInt() ?? 0;
    
    // Extract category from types
    final types = (map['types'] as List<dynamic>? ?? [])
        .cast<String>()
        .where((type) => !_isGenericType(type))
        .toList();
    
    final primaryCategory = types.isNotEmpty 
        ? _formatCategory(types.first) 
        : 'Venue';

    // Extract amenities from types and price level
    final amenities = <String>[];
    final priceLevel = map['price_level'] as int?;
    if (priceLevel != null) {
      amenities.add('${'\$' * (priceLevel + 1)} Price Level');
    }
    
    // Add relevant types as amenities
    amenities.addAll(
      types.take(3).map((type) => _formatCategory(type))
    );

    // Calculate trending score based on rating and review count
    final trendingScore = _calculateTrendingScore(rating, ratingCount);

    // Get cover photo
    String coverPhoto = 'https://images.unsplash.com/photo-1529421304207-8fc2c05c696c?auto=format&fit=crop&w=800&q=80';
    
    final photos = map['photos'] as List<dynamic>? ?? [];
    if (photos.isNotEmpty) {
      final firstPhoto = photos.first as Map<String, dynamic>? ?? {};
      final photoReference = firstPhoto['photo_reference'] as String? ?? '';
      if (photoReference.isNotEmpty) {
        coverPhoto = 'https://maps.googleapis.com/maps/api/place/photo'
            '?maxwidth=400&photoreference=$photoReference&key=$googlePlacesApiKey';
      }
    }

    return Venue(
      id: map['place_id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed venue',
      category: primaryCategory,
      location: VenueLocation(
        geoPoint: latitude != null && longitude != null
            ? GeoPoint(latitude, longitude)
            : null,
        geohash: '',
      ),
      addressSummary: map['formatted_address'] as String? ?? 'Unknown address',
      ownerId: null,
      amenities: amenities,
      rating: RatingSummary(average: rating, count: ratingCount),
      trendingScore: trendingScore,
      coverPhotoUrl: coverPhoto,
    );
  }

  bool _isGenericType(String type) {
    const genericTypes = {
      'establishment', 'point_of_interest', 'place_of_worship',
      'premise', 'geocode', 'political', 'colloquial_area'
    };
    return genericTypes.contains(type);
  }

  String _formatCategory(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');
  }

  double _calculateTrendingScore(double rating, int reviewCount) {
    if (rating == 0 || reviewCount == 0) return 0.0;
    
    // Normalize rating (0-5 scale to 0-1)
    final normalizedRating = rating / 5.0;
    
    // Normalize review count (logarithmic scale)
    final normalizedReviews = (reviewCount > 0) 
        ? (1.0 - (1.0 / (1.0 + (reviewCount / 100.0))))
        : 0.0;
    
    // Combine rating and review count (70% rating, 30% popularity)
    return (normalizedRating * 0.7) + (normalizedReviews * 0.3);
  }
}