import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../models/venue.dart';
import 'poi_provider.dart';

class FoursquareService implements PoiProvider {
  FoursquareService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://places-api.foursquare.com/places/search';

  final http.Client _client;

  @override
  bool get isEnabled => foursquareApiKey.isNotEmpty;

  @override
  String get name => 'Foursquare';

  void _debugLog(String message) {
    assert(() {
      debugPrint('[FoursquareService] $message');
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

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'query': query,
        'll': '$latitude,$longitude',
        'radius': '${radius ?? 2000}',
        'limit': '$limit',
        'sort': 'RELEVANCE',
        'fields': 'fsq_place_id,name,location,categories,rating,popularity,photos,stats,chains,features',
      },
    );

    _debugLog('Request → $uri');

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $foursquareApiKey',
        'Accept': 'application/json',
        'X-Places-Api-Version': '2025-06-17',
      },
    );

    _debugLog('Status ← ${response.statusCode}');

    if (response.statusCode != 200) {
      _debugLog('Body ← ${response.body}');
      throw Exception('Foursquare request failed: ${response.statusCode}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? const [];

    assert(() {
      debugPrint('[FoursquareService] Body ← ${response.body}');
      return true;
    }());

    return results.map((item) => _mapVenue(item)).toList();
  }

  @override
  Future<Venue?> getVenueDetails(String venueId) async {
    // Foursquare doesn't provide venue details in free tier
    // Return null for now
    return null;
  }

  @override
  Future<List<Venue>> getTrendingVenues({
    required double latitude,
    required double longitude,
    int limit = 12,
    int? radius,
  }) async {
    if (!isEnabled) return const [];

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'll': '$latitude,$longitude',
        'radius': '${radius ?? 2000}',
        'limit': '$limit',
        'sort': 'POPULARITY', // Sort by popularity for trending
        'fields': 'fsq_place_id,name,location,categories,rating,popularity,photos,stats,chains,features',
      },
    );

    _debugLog('Trending Request → $uri');

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': 'Bearer $foursquareApiKey',
        'Accept': 'application/json',
        'X-Places-Api-Version': '2025-06-17',
      },
    );

    _debugLog('Trending Status ← ${response.statusCode}');

    if (response.statusCode != 200) {
      _debugLog('Trending Body ← ${response.body}');
      throw Exception('Foursquare trending request failed: ${response.statusCode}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? const [];

    assert(() {
      debugPrint('[FoursquareService] Trending Body ← ${response.body}');
      return true;
    }());

    return results.map((item) => _mapVenue(item)).toList();
  }

  Venue _mapVenue(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final latitude = (map['latitude'] as num?)?.toDouble();
    final longitude = (map['longitude'] as num?)?.toDouble();

    final location = map['location'] as Map<String, dynamic>? ?? const {};
    final categories = map['categories'] as List<dynamic>? ?? const [];
    final primaryCategory =
        categories.isNotEmpty ? categories.first['name'] as String? : null;

    // Extract rating information
    final rating = (map['rating'] as num?)?.toDouble() ?? 0.0;
    final ratingCount = (map['stats']?['total_ratings'] as num?)?.toInt() ?? 0;
    
    // Extract popularity/trending score (0.0-1.0)
    final popularity = (map['popularity'] as num?)?.toDouble() ?? 0.0;
    
    // Extract chains and features for amenities
    final chains = (map['chains'] as List<dynamic>? ?? [])
        .map((chain) => chain['name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    
    final features = (map['features'] as Map<String, dynamic>? ?? {})
        .entries
        .where((entry) => entry.value == true)
        .map((entry) => entry.key)
        .toList();
    
    final amenities = [...chains, ...features];

    // Try to get a better cover photo
    String coverPhoto = 'https://images.unsplash.com/photo-1529421304207-8fc2c05c696c?auto=format&fit=crop&w=800&q=80';
    
    // Check if there are photos available
    final photos = map['photos'] as List<dynamic>? ?? [];
    if (photos.isNotEmpty) {
      final firstPhoto = photos.first as Map<String, dynamic>? ?? {};
      final photoPrefix = firstPhoto['prefix'] as String? ?? '';
      final photoSuffix = firstPhoto['suffix'] as String? ?? '';
      if (photoPrefix.isNotEmpty && photoSuffix.isNotEmpty) {
        coverPhoto = '${photoPrefix}300x300$photoSuffix';
      }
    }

    return Venue(
      id: map['fsq_place_id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed venue',
      category: primaryCategory ?? 'Venue',
      location: VenueLocation(
        geoPoint: latitude != null && longitude != null
            ? GeoPoint(latitude, longitude)
            : null,
        geohash: '',
      ),
      addressSummary: _formatAddress(location),
      ownerId: null,
      amenities: amenities,
      rating: RatingSummary(average: rating, count: ratingCount),
      trendingScore: popularity,
      coverPhotoUrl: coverPhoto,
    );
  }

  String _formatAddress(Map<String, dynamic> location) {
    final parts = <String?>[
      location['address'] as String?,
      location['locality'] as String?,
      location['region'] as String?,
    ].whereType<String>();
    return parts.isEmpty ? 'Unknown address' : parts.join(', ');
  }
}
