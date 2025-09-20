import '../models/venue.dart';
import 'google_places_service.dart';
import 'foursquare_service.dart';
import 'mock_poi_provider.dart';
import 'poi_provider.dart';

/// Manages POI providers and provides a unified interface
/// 
/// This class handles provider selection, fallbacks, and aggregation
class PoiProviderManager implements PoiProvider {
  PoiProviderManager({
    PoiProvider? primaryProvider,
    List<PoiProvider>? fallbackProviders,
  }) : _primaryProvider = primaryProvider ?? GooglePlacesService(),
        _fallbackProviders = fallbackProviders ?? [FoursquareService(), const MockPoiProvider()];
  
  final PoiProvider _primaryProvider;
  final List<PoiProvider> _fallbackProviders;
  
  /// Get all available providers (enabled ones)
  List<PoiProvider> get availableProviders {
    final providers = <PoiProvider>[];
    if (_primaryProvider.isEnabled) {
      providers.add(_primaryProvider);
    }
    providers.addAll(_fallbackProviders.where((p) => p.isEnabled));
    return providers;
  }
  
  /// Get the currently active provider
  PoiProvider get activeProvider {
    if (_primaryProvider.isEnabled) {
      return _primaryProvider;
    }
    
    for (final provider in _fallbackProviders) {
      if (provider.isEnabled) {
        return provider;
      }
    }
    
    // Return mock provider as last resort
    return const MockPoiProvider();
  }
  
  @override
  bool get isEnabled => availableProviders.isNotEmpty;
  
  @override
  String get name => 'POI Manager (${activeProvider.name})';
  
  @override
  Future<List<Venue>> searchVenues({
    required double latitude,
    required double longitude,
    required String query,
    int limit = 12,
    int? radius,
  }) async {
    final provider = activeProvider;
    
    try {
      return await provider.searchVenues(
        latitude: latitude,
        longitude: longitude,
        query: query,
        limit: limit,
        radius: radius,
      );
    } catch (e) {
      // If primary provider fails, try fallback
      for (final fallback in _fallbackProviders) {
        if (fallback != provider && fallback.isEnabled) {
          try {
            return await fallback.searchVenues(
              latitude: latitude,
              longitude: longitude,
              query: query,
              limit: limit,
              radius: radius,
            );
          } catch (fallbackError) {
            // Continue to next fallback
            continue;
          }
        }
      }
      
      // If all providers fail, rethrow the original error
      rethrow;
    }
  }
  
  @override
  Future<Venue?> getVenueDetails(String venueId) async {
    final provider = activeProvider;
    
    try {
      return await provider.getVenueDetails(venueId);
    } catch (e) {
      // Try fallback providers
      for (final fallback in _fallbackProviders) {
        if (fallback != provider && fallback.isEnabled) {
          try {
            return await fallback.getVenueDetails(venueId);
          } catch (fallbackError) {
            continue;
          }
        }
      }
      
      return null; // Return null if all providers fail for details
    }
  }
  
  @override
  Future<List<Venue>> getTrendingVenues({
    required double latitude,
    required double longitude,
    int limit = 12,
    int? radius,
  }) async {
    final provider = activeProvider;
    
    try {
      return await provider.getTrendingVenues(
        latitude: latitude,
        longitude: longitude,
        limit: limit,
        radius: radius,
      );
    } catch (e) {
      // Try fallback providers
      for (final fallback in _fallbackProviders) {
        if (fallback != provider && fallback.isEnabled) {
          try {
            return await fallback.getTrendingVenues(
              latitude: latitude,
              longitude: longitude,
              limit: limit,
              radius: radius,
            );
          } catch (fallbackError) {
            continue;
          }
        }
      }
      
      rethrow;
    }
  }
  
  /// Switch to a specific provider type
  /// Returns true if switch was successful
  bool switchToProvider(PoiProviderType type) {
    // This would be implemented when we add provider configuration
    // For now, we use the current setup
    return activeProvider.isEnabled;
  }
  
  /// Get provider statistics for debugging
  Map<String, dynamic> getProviderStats() {
    return {
      'activeProvider': activeProvider.name,
      'availableProviders': availableProviders.map((p) => p.name).toList(),
      'primaryEnabled': _primaryProvider.isEnabled,
      'fallbackCount': _fallbackProviders.length,
    };
  }
}