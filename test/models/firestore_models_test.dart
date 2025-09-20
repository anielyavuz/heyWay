import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heyway/models/app_user.dart';
import 'package:heyway/models/venue.dart';
import 'package:heyway/models/pulse.dart';

void main() {
  group('Firestore Models Tests', () {
    test('AppUser model serialization/deserialization', () {
      final user = AppUser(
        id: 'test-user-123',
        displayName: 'Test User',
        username: 'testuser',
        avatarUrl: 'https://example.com/avatar.jpg',
        privacy: const PrivacySettings(
          profile: 'public',
          pulses: 'friends',
          locationSharing: true,
        ),
        stats: const UserStats(
          pulseCount: 5,
          friendCount: 10,
          badgeCount: 2,
        ),
        homeGeoPoint: const GeoPoint(40.7128, -74.0060),
        lastActive: DateTime.now(),
        pushTokens: const ['token1', 'token2'],
      );

      final map = user.toMap();
      
      expect(map['displayName'], equals('Test User'));
      expect(map['username'], equals('testuser'));
      expect(map['privacy']['profile'], equals('public'));
      expect(map['stats']['pulseCount'], equals(5));
      expect(map['homeGeoPoint'], isA<GeoPoint>());
      expect(map['pushTokens'], equals(['token1', 'token2']));
    });

    test('Venue model serialization/deserialization', () {
      final venue = Venue(
        id: 'venue-123',
        name: 'Test Cafe',
        category: 'coffee',
        location: const VenueLocation(
          geoPoint: GeoPoint(40.7128, -74.0060),
          geohash: 'dr5regw3pp',
        ),
        addressSummary: '123 Test St, New York, NY',
        ownerId: 'owner-123',
        amenities: const ['wifi', 'outdoor_seating'],
        rating: const RatingSummary(average: 4.5, count: 100),
        trendingScore: 0.8,
        coverPhotoUrl: 'https://example.com/venue.jpg',
      );

      final map = venue.toMap();
      
      expect(map['name'], equals('Test Cafe'));
      expect(map['category'], equals('coffee'));
      expect(map['location']['geohash'], equals('dr5regw3pp'));
      expect(map['amenities'], equals(['wifi', 'outdoor_seating']));
      expect(map['ratingSummary']['average'], equals(4.5));
      expect(map['trendingScore'], equals(0.8));
    });

    test('Pulse model serialization/deserialization', () {
      final pulse = Pulse(
        id: 'pulse-123',
        userId: 'user-123',
        venueId: 'venue-123',
        caption: 'Great coffee here!',
        mood: 'happy',
        visibility: 'public',
        mediaRefs: const ['photo1.jpg', 'photo2.jpg'],
        badgeUnlocks: const ['coffee_lover'],
        likesCount: 15,
        commentCount: 3,
        createdAt: DateTime.now(),
      );

      final map = pulse.toMap();
      
      expect(map['userId'], equals('user-123'));
      expect(map['venueId'], equals('venue-123'));
      expect(map['caption'], equals('Great coffee here!'));
      expect(map['mood'], equals('happy'));
      expect(map['visibility'], equals('public'));
      expect(map['mediaRefs'], equals(['photo1.jpg', 'photo2.jpg']));
      expect(map['badgeUnlocks'], equals(['coffee_lover']));
      expect(map['likesCount'], equals(15));
      expect(map['commentCount'], equals(3));
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('User copyWith method', () {
      final originalUser = AppUser(
        id: 'user-123',
        displayName: 'Original Name',
        username: 'original',
        avatarUrl: 'original.jpg',
        privacy: const PrivacySettings(
          profile: 'public',
          pulses: 'public',
          locationSharing: false,
        ),
        stats: const UserStats(
          pulseCount: 0,
          friendCount: 0,
          badgeCount: 0,
        ),
        homeGeoPoint: null,
        lastActive: null,
        pushTokens: const [],
      );

      final updatedUser = originalUser.copyWith(
        displayName: 'New Name',
        stats: const UserStats(
          pulseCount: 5,
          friendCount: 10,
          badgeCount: 2,
        ),
      );

      expect(updatedUser.id, equals('user-123'));
      expect(updatedUser.displayName, equals('New Name'));
      expect(updatedUser.username, equals('original'));
      expect(updatedUser.stats.pulseCount, equals(5));
      expect(updatedUser.stats.friendCount, equals(10));
    });

    test('Pulse copyWith method', () {
      final originalPulse = Pulse(
        id: 'pulse-123',
        userId: 'user-123',
        venueId: 'venue-123',
        caption: 'Original caption',
        mood: 'neutral',
        visibility: 'private',
        mediaRefs: const [],
        badgeUnlocks: const [],
        likesCount: 0,
        commentCount: 0,
        createdAt: DateTime.now(),
      );

      final updatedPulse = originalPulse.copyWith(
        caption: 'Updated caption',
        mood: 'happy',
        likesCount: 10,
      );

      expect(updatedPulse.id, equals('pulse-123'));
      expect(updatedPulse.caption, equals('Updated caption'));
      expect(updatedPulse.mood, equals('happy'));
      expect(updatedPulse.visibility, equals('private'));
      expect(updatedPulse.likesCount, equals(10));
      expect(updatedPulse.commentCount, equals(0));
    });
  });
}