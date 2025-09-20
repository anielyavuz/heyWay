import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../models/venue.dart';

class FoursquareService {
  FoursquareService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://api.foursquare.com/v3/places/search';

  final http.Client _client;

  bool get isEnabled => foursquareApiKey.isNotEmpty;

  Future<List<Venue>> search({
    required double latitude,
    required double longitude,
    required String query,
    int limit = 12,
  }) async {
    if (!isEnabled) return const [];

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'query': query,
        'll': '$latitude,$longitude',
        'radius': '2000',
        'limit': '$limit',
        'sort': 'RELEVANCE',
      },
    );

    final response = await _client.get(
      uri,
      headers: {
        'Authorization': foursquareApiKey,
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Foursquare request failed: ${response.statusCode}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final results = body['results'] as List<dynamic>? ?? const [];
    return results.map((item) => _mapVenue(item)).toList();
  }

  Venue _mapVenue(dynamic raw) {
    final map = raw as Map<String, dynamic>;
    final geocodes = map['geocodes'] as Map<String, dynamic>? ?? const {};
    final mainGeo = geocodes['main'] as Map<String, dynamic>? ?? const {};
    final latitude = (mainGeo['latitude'] as num?)?.toDouble();
    final longitude = (mainGeo['longitude'] as num?)?.toDouble();

    final location = map['location'] as Map<String, dynamic>? ?? const {};
    final categories = map['categories'] as List<dynamic>? ?? const [];
    final primaryCategory = categories.isNotEmpty
        ? categories.first['name'] as String?
        : null;

    return Venue(
      id: map['fsq_id'] as String? ?? '',
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
      amenities: const [],
      rating: const RatingSummary(average: 0, count: 0),
      trendingScore: 0,
      coverPhotoUrl:
          'https://images.unsplash.com/photo-1529421304207-8fc2c05c696c?auto=format&fit=crop&w=800&q=80',
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
