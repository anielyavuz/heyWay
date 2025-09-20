import '../models/venue.dart';

/// Abstract interface for Point of Interest (POI) providers
/// 
/// This allows swapping between different services like Foursquare, Google Places, HERE Maps
/// without changing the core application logic.
abstract class PoiProvider {
  /// Whether this provider is currently available/configured
  bool get isEnabled;
  
  /// Provider name for debugging and analytics
  String get name;
  
  /// Search for venues near a given location
  /// 
  /// [latitude] and [longitude] specify the search center
  /// [query] is the search term (e.g., "coffee", "restaurant")
  /// [limit] is the maximum number of results to return
  /// [radius] is the search radius in meters (optional)
  Future<List<Venue>> searchVenues({
    required double latitude,
    required double longitude,
    required String query,
    int limit = 12,
    int? radius,
  });
  
  /// Get venue details by ID
  /// 
  /// Returns null if venue not found or provider doesn't support detail queries
  Future<Venue?> getVenueDetails(String venueId);
  
  /// Get trending/popular venues in an area
  /// 
  /// [latitude] and [longitude] specify the search center
  /// [limit] is the maximum number of results to return
  /// [radius] is the search radius in meters (optional)
  Future<List<Venue>> getTrendingVenues({
    required double latitude,
    required double longitude,
    int limit = 12,
    int? radius,
  });
}

/// Configuration for POI providers
class PoiProviderConfig {
  const PoiProviderConfig({
    required this.apiKey,
    this.baseUrl,
    this.requestTimeout = const Duration(seconds: 10),
    this.maxRetries = 3,
  });
  
  final String apiKey;
  final String? baseUrl;
  final Duration requestTimeout;
  final int maxRetries;
}

/// Available POI provider types
enum PoiProviderType {
  foursquare,
  googlePlaces,
  hereMaps,
  mock, // For testing
}