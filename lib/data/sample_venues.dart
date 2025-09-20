import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/venue.dart';

final sampleVenues = <Venue>[
  Venue(
    id: 'cafe_pulse',
    name: 'Pulse Collective Cafe',
    category: 'Cafe',
    location: const VenueLocation(
      geoPoint: GeoPoint(41.0369, 28.9853),
      geohash: 'sxkbfcyy3',
    ),
    addressSummary: 'Istiklal Cd. 123, Beyoğlu, Istanbul',
    ownerId: null,
    amenities: const ['WiFi', 'Outdoor Seating', 'Vegan Options'],
    rating: const RatingSummary(average: 4.6, count: 128),
    trendingScore: 92.4,
    coverPhotoUrl:
        'https://images.unsplash.com/photo-1521017432531-fbd92d768814?auto=format&fit=crop&w=800&q=80',
  ),
  Venue(
    id: 'rooftop_wave',
    name: 'Rooftop Wave Bar',
    category: 'Bar',
    location: const VenueLocation(
      geoPoint: GeoPoint(41.0284, 28.9738),
      geohash: 'sxkbe5prc',
    ),
    addressSummary: 'Kumbaracı Yokuşu 45, Karaköy, Istanbul',
    ownerId: null,
    amenities: const ['Live Music', 'Rooftop', 'Cocktails'],
    rating: const RatingSummary(average: 4.8, count: 214),
    trendingScore: 88.0,
    coverPhotoUrl:
        'https://images.unsplash.com/photo-1525286116112-b59af11adad1?auto=format&fit=crop&w=800&q=80',
  ),
  Venue(
    id: 'atlas_gallery',
    name: 'Atlas Art Gallery',
    category: 'Gallery',
    location: const VenueLocation(
      geoPoint: GeoPoint(41.0392, 28.9977),
      geohash: 'sxkbg7rse',
    ),
    addressSummary: 'Abdi İpekçi Cd. 90, Nişantaşı, Istanbul',
    ownerId: null,
    amenities: const ['Guided Tours', 'Workshops'],
    rating: const RatingSummary(average: 4.3, count: 76),
    trendingScore: 73.2,
    coverPhotoUrl:
        'https://images.unsplash.com/photo-1529421304207-8fc2c05c696c?auto=format&fit=crop&w=800&q=80',
  ),
  Venue(
    id: 'bosphorus_run_club',
    name: 'Bosphorus Run Club',
    category: 'Outdoor',
    location: const VenueLocation(
      geoPoint: GeoPoint(41.0457, 29.0226),
      geohash: 'sxkbhne77',
    ),
    addressSummary: 'Kuruçeşme Parkı, Beşiktaş, Istanbul',
    ownerId: null,
    amenities: const ['Community Events', 'Locker Room'],
    rating: const RatingSummary(average: 4.9, count: 54),
    trendingScore: 80.1,
    coverPhotoUrl:
        'https://images.unsplash.com/photo-1526404079169-9f47aa4c4d1d?auto=format&fit=crop&w=800&q=80',
  ),
];
