import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/venue.dart';
import 'poi_provider.dart';

/// Mock POI provider for testing and development
/// 
/// Returns sample venues based on the query without making network calls
class MockPoiProvider implements PoiProvider {
  const MockPoiProvider({this.isAvailable = true});
  
  final bool isAvailable;
  
  @override
  bool get isEnabled => isAvailable;
  
  @override
  String get name => 'Mock Provider';
  
  @override
  Future<List<Venue>> searchVenues({
    required double latitude,
    required double longitude,
    required String query,
    int limit = 12,
    int? radius,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    final mockVenues = _generateMockVenues(latitude, longitude, query);
    return mockVenues.take(limit).toList();
  }
  
  @override
  Future<Venue?> getVenueDetails(String venueId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Return a mock venue with the given ID
    return _createMockVenue(
      id: venueId,
      name: 'Mock Venue Details',
      category: 'Mock Category',
      latitude: 41.0082,
      longitude: 28.9784,
    );
  }
  
  @override
  Future<List<Venue>> getTrendingVenues({
    required double latitude,
    required double longitude,
    int limit = 12,
    int? radius,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 400));
    
    return _generateTrendingVenues(latitude, longitude).take(limit).toList();
  }
  
  List<Venue> _generateMockVenues(double lat, double lng, String query) {
    final lowerQuery = query.toLowerCase();
    final venues = <Venue>[];
    
    // Coffee venues
    if (lowerQuery.contains('coffee') || lowerQuery.contains('cafe') || lowerQuery.isEmpty) {
      venues.addAll([
        _createMockVenue(
          id: 'mock_coffee_1',
          name: 'Mock Coffee House',
          category: 'Café',
          latitude: lat + 0.001,
          longitude: lng + 0.001,
        ),
        _createMockVenue(
          id: 'mock_coffee_2',
          name: 'Test Brew Café',
          category: 'Coffee Shop',
          latitude: lat - 0.002,
          longitude: lng + 0.0015,
        ),
      ]);
    }
    
    // Restaurant venues
    if (lowerQuery.contains('restaurant') || lowerQuery.contains('food') || lowerQuery.isEmpty) {
      venues.addAll([
        _createMockVenue(
          id: 'mock_restaurant_1',
          name: 'Mock Bistro',
          category: 'Restaurant',
          latitude: lat + 0.0015,
          longitude: lng - 0.001,
        ),
        _createMockVenue(
          id: 'mock_restaurant_2',
          name: 'Test Kitchen',
          category: 'Fast Food',
          latitude: lat - 0.001,
          longitude: lng - 0.002,
        ),
      ]);
    }
    
    // Bar venues
    if (lowerQuery.contains('bar') || lowerQuery.contains('drink') || lowerQuery.isEmpty) {
      venues.add(_createMockVenue(
        id: 'mock_bar_1',
        name: 'Mock Lounge',
        category: 'Bar',
        latitude: lat + 0.002,
        longitude: lng + 0.002,
      ));
    }
    
    return venues;
  }
  
  List<Venue> _generateTrendingVenues(double lat, double lng) {
    return [
      _createMockVenue(
        id: 'trending_1',
        name: 'Trending Spot 1',
        category: 'Trendy Café',
        latitude: lat + 0.0005,
        longitude: lng + 0.0005,
        rating: 4.8,
        reviewCount: 250,
      ),
      _createMockVenue(
        id: 'trending_2',
        name: 'Popular Restaurant',
        category: 'Restaurant',
        latitude: lat - 0.0008,
        longitude: lng + 0.0012,
        rating: 4.6,
        reviewCount: 180,
      ),
      _createMockVenue(
        id: 'trending_3',
        name: 'Hot New Bar',
        category: 'Cocktail Bar',
        latitude: lat + 0.0012,
        longitude: lng - 0.0007,
        rating: 4.7,
        reviewCount: 95,
      ),
    ];
  }
  
  Venue _createMockVenue({
    required String id,
    required String name,
    required String category,
    required double latitude,
    required double longitude,
    double rating = 4.2,
    int reviewCount = 42,
  }) {
    return Venue(
      id: id,
      name: name,
      category: category,
      location: VenueLocation(
        geoPoint: GeoPoint(latitude, longitude),
        geohash: 'mock_geohash',
      ),
      addressSummary: 'Mock Address, Test City',
      ownerId: null,
      amenities: const ['WiFi', 'Mock Amenity'],
      rating: RatingSummary(average: rating, count: reviewCount),
      trendingScore: rating * 10,
      coverPhotoUrl: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&q=80',
    );
  }
}