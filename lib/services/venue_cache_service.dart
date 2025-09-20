import '../models/venue.dart';
import 'firestore_service.dart';
import 'poi_provider.dart';

class VenueCacheService {
  VenueCacheService({
    required this.firestoreService,
    required this.poiProvider,
  });

  final FirestoreService firestoreService;
  final PoiProvider poiProvider;

  static const int cacheExpiryHours = 24;

  Future<List<Venue>> searchVenuesWithCache({
    required double latitude,
    required double longitude,
    required String query,
    int limit = 12,
    int? radius,
  }) async {
    try {
      // First try to get venues from Firestore cache
      final cachedVenues = await firestoreService.searchVenues(
        query: query,
        latitude: latitude,
        longitude: longitude,
        radius: (radius ?? 2000).toDouble(),
        limit: limit,
      );

      // If we have enough cached results and they're recent, return them
      if (cachedVenues.isNotEmpty && _areVenuesRecent(cachedVenues)) {
        return cachedVenues;
      }

      // Otherwise, fetch from POI provider
      final freshVenues = await poiProvider.searchVenues(
        latitude: latitude,
        longitude: longitude,
        query: query,
        limit: limit,
        radius: radius,
      );

      // Cache the fresh venues in Firestore
      await _cacheVenues(freshVenues);

      return freshVenues;
    } catch (e) {
      // If POI provider fails, return cached venues if available
      final cachedVenues = await firestoreService.searchVenues(
        query: query,
        latitude: latitude,
        longitude: longitude,
        radius: (radius ?? 2000).toDouble(),
        limit: limit,
      );
      
      if (cachedVenues.isNotEmpty) {
        return cachedVenues;
      }
      
      rethrow;
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

  bool _areVenuesRecent(List<Venue> venues) {
    if (venues.isEmpty) return false;
    
    // Check if most venues are recent (using metadata if available)
    // For now, assume venues are fresh if we have them cached
    // In a real implementation, you'd check lastUpdated timestamp
    return true;
  }

  bool _isVenueRecent(Venue venue) {
    // For now, assume venues are fresh if we have them cached
    // In a real implementation, you'd check lastUpdated timestamp
    return true;
  }

}