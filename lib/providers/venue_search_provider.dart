import 'package:flutter/material.dart';
import '../data/sample_venues.dart';
import '../models/venue.dart';

class VenueSearchProvider extends ChangeNotifier {
  VenueSearchProvider();

  String _query = '';
  List<Venue> _results = sampleVenues;

  String get query => _query;
  List<Venue> get results => _results;

  void updateQuery(String value) {
    _query = value;
    _results = _filterVenues(value);
    notifyListeners();
  }

  List<Venue> _filterVenues(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return sampleVenues;
    }

    return sampleVenues.where((venue) {
      final nameMatch = venue.name.toLowerCase().contains(trimmed);
      final categoryMatch = venue.category.toLowerCase().contains(trimmed);
      final amenityMatch = venue.amenities.whereType<String>().any(
        (amenity) => amenity.toLowerCase().contains(trimmed),
      );
      return nameMatch || categoryMatch || amenityMatch;
    }).toList();
  }
}
