import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.addressSummary,
    required this.ownerId,
    required this.amenities,
    required this.rating,
    required this.trendingScore,
    required this.coverPhotoUrl,
  });

  factory Venue.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Venue(
      id: doc.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? '',
      location: VenueLocation.fromMap(
        data['location'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      addressSummary: data['addressSummary'] as String? ?? '',
      ownerId: data['ownerId'] as String?,
      amenities: (data['amenities'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>(),
      rating: RatingSummary.fromMap(
        data['ratingSummary'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      trendingScore: (data['trendingScore'] as num?)?.toDouble() ?? 0.0,
      coverPhotoUrl: data['coverPhotoUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'location': location.toMap(),
      'addressSummary': addressSummary,
      'ownerId': ownerId,
      'amenities': amenities,
      'ratingSummary': rating.toMap(),
      'trendingScore': trendingScore,
      'coverPhotoUrl': coverPhotoUrl,
    }..removeWhere((key, value) => value == null);
  }

  final String id;
  final String name;
  final String category;
  final VenueLocation location;
  final String addressSummary;
  final String? ownerId;
  final List<String> amenities;
  final RatingSummary rating;
  final double trendingScore;
  final String coverPhotoUrl;
}

@immutable
class VenueLocation {
  const VenueLocation({required this.geoPoint, required this.geohash});

  factory VenueLocation.fromMap(Map<String, dynamic> map) {
    return VenueLocation(
      geoPoint: map['geoPoint'] as GeoPoint?,
      geohash: map['geohash'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() =>
      {'geoPoint': geoPoint, 'geohash': geohash}
        ..removeWhere((key, value) => value == null);

  final GeoPoint? geoPoint;
  final String geohash;
}

@immutable
class RatingSummary {
  const RatingSummary({required this.average, required this.count});

  factory RatingSummary.fromMap(Map<String, dynamic> map) {
    return RatingSummary(
      average: (map['average'] as num?)?.toDouble() ?? 0.0,
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'average': average, 'count': count};

  final double average;
  final int count;
}
