import 'dart:math' show sin, cos, sqrt, atan2, pi;
import '../models/venue.dart';
import 'firestore_service.dart';
import 'poi_provider.dart';
import '../utils/debug_logger.dart';

class VenueCacheService {
  VenueCacheService({
    required this.firestoreService,
    required this.poiProvider,
  });

  final FirestoreService firestoreService;
  final PoiProvider poiProvider;

  static const int cacheExpiryHours = 24;
  static const double defaultCacheRadiusKm = 20.0; // 20km cache radius

  Future<List<Venue>> searchVenuesWithCache({
    required double latitude,
    required double longitude,
    required String query,
    int limit = 12,
    int? radius,
    bool forceCache = true, // Prioritize cache by default
  }) async {
    try {
      // Always check cache first with 20km radius
      final cachedVenues = await firestoreService.searchVenues(
        query: query,
        latitude: latitude,
        longitude: longitude,
        radius: defaultCacheRadiusKm * 1000, // Convert to meters
        limit: limit * 2, // Get more from cache to filter locally
      );

      // If we have cached results and force cache is enabled, return them
      if (cachedVenues.isNotEmpty && forceCache) {
        // Sort by distance and limit results
        final sortedVenues = _sortVenuesByDistance(
          cachedVenues, 
          latitude, 
          longitude
        ).take(limit).toList();
        
        DebugLogger.info('Cache hit: Found ${sortedVenues.length} venues in cache for query "$query"', 'VenueCacheService');
        return sortedVenues;
      }

      // If not enough cached results or cache not forced, try POI provider
      if (!poiProvider.isEnabled) {
        DebugLogger.warning('POI provider disabled, returning ${cachedVenues.length} cached venues', 'VenueCacheService');
        return _sortVenuesByDistance(cachedVenues, latitude, longitude)
            .take(limit).toList();
      }

      print('🌐 Fetching fresh venues from POI provider for query "$query"');
      final freshVenues = await poiProvider.searchVenues(
        latitude: latitude,
        longitude: longitude,
        query: query,
        limit: limit,
        radius: radius,
      );

      // Cache the fresh venues in background
      if (freshVenues.isNotEmpty) {
        _cacheVenues(freshVenues); // Fire and forget
        print('💾 Cached ${freshVenues.length} fresh venues');
      }

      return freshVenues;
    } catch (e) {
      print('❌ POI provider failed: $e, falling back to cache');
      // If POI provider fails, return cached venues if available
      final cachedVenues = await firestoreService.searchVenues(
        query: query,
        latitude: latitude,
        longitude: longitude,
        radius: defaultCacheRadiusKm * 1000,
        limit: limit * 2,
      );
      
      if (cachedVenues.isNotEmpty) {
        final sortedVenues = _sortVenuesByDistance(
          cachedVenues, 
          latitude, 
          longitude
        ).take(limit).toList();
        
        print('🏪 Fallback: Returning ${sortedVenues.length} cached venues');
        return sortedVenues;
      }
      
      rethrow;
    }
  }

  /// Get nearby popular venues from cache (for home screen)
  Future<List<Venue>> getNearbyPopularVenues({
    required double latitude,
    required double longitude,
    int limit = 6,
  }) async {
    try {
      // Always try cache first for popular venues
      final cachedVenues = await firestoreService.searchVenues(
        latitude: latitude,
        longitude: longitude,
        radius: defaultCacheRadiusKm * 1000, // 20km radius
        limit: limit * 3, // Get more to have variety
      );

      if (cachedVenues.isNotEmpty) {
        // Sort by distance and trending score
        final sortedVenues = _sortVenuesByPopularity(
          cachedVenues, 
          latitude, 
          longitude
        ).take(limit).toList();
        
        print('🔥 Found ${sortedVenues.length} popular venues in cache');
        return sortedVenues;
      }

      // If no cache, don't make API calls for popular venues to save quota
      print('📍 No cached venues found for popular venues');
      return [];
    } catch (e) {
      print('❌ Error getting popular venues: $e');
      return [];
    }
  }

  Future<Venue?> getVenueWithCache(String venueId) async {
    try {
      // First try to get from cache
      final cachedVenue = await firestoreService.getVenue(venueId);
      
      if (cachedVenue != null && _isVenueRecent(cachedVenue)) {
        return cachedVenue;
      }

      // Try to get fresh data from POI provider
      final freshVenue = await poiProvider.getVenueDetails(venueId);
      
      if (freshVenue != null) {
        await firestoreService.upsertVenue(freshVenue);
        return freshVenue;
      }

      // Return cached venue even if old, if no fresh data available
      return cachedVenue;
    } catch (e) {
      // If POI provider fails, return cached venue if available
      return await firestoreService.getVenue(venueId);
    }
  }

  Future<void> _cacheVenues(List<Venue> venues) async {
    for (final venue in venues) {
      try {
        await firestoreService.upsertVenue(venue);
      } catch (e) {
        // Continue caching other venues even if one fails
        // Silently continue to cache other venues
      }
    }
  }

  /// Sort venues by distance from user location
  List<Venue> _sortVenuesByDistance(
    List<Venue> venues, 
    double userLat, 
    double userLng
  ) {
    venues.sort((a, b) {
      final aPoint = a.location.geoPoint;
      final bPoint = b.location.geoPoint;
      
      if (aPoint == null && bPoint == null) return 0;
      if (aPoint == null) return 1;
      if (bPoint == null) return -1;
      
      final aDist = _calculateDistance(userLat, userLng, aPoint.latitude, aPoint.longitude);
      final bDist = _calculateDistance(userLat, userLng, bPoint.latitude, bPoint.longitude);
      
      return aDist.compareTo(bDist);
    });
    
    return venues;
  }

  /// Sort venues by popularity (rating + trending score) and distance
  List<Venue> _sortVenuesByPopularity(
    List<Venue> venues, 
    double userLat, 
    double userLng
  ) {
    venues.sort((a, b) {
      // Calculate popularity score (rating * 0.7 + trending * 0.3)
      final aPopularity = (a.rating.average * 0.7) + (a.trendingScore * 0.3);
      final bPopularity = (b.rating.average * 0.7) + (b.trendingScore * 0.3);
      
      // If popularity is similar, sort by distance
      if ((aPopularity - bPopularity).abs() < 0.5) {
        final aPoint = a.location.geoPoint;
        final bPoint = b.location.geoPoint;
        
        if (aPoint == null && bPoint == null) return 0;
        if (aPoint == null) return 1;
        if (bPoint == null) return -1;
        
        final aDist = _calculateDistance(userLat, userLng, aPoint.latitude, aPoint.longitude);
        final bDist = _calculateDistance(userLat, userLng, bPoint.latitude, bPoint.longitude);
        
        return aDist.compareTo(bDist);
      }
      
      return bPopularity.compareTo(aPopularity);
    });
    
    return venues;
  }

  /// Calculate distance between two points in meters
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth radius in meters
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  bool _isVenueRecent(Venue venue) {
    // For now, assume venues are fresh if we have them cached
    // In a real implementation, you'd check lastUpdated timestamp
    return true;
  }

}