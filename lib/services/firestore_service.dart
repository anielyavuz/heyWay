import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/pulse.dart';
import '../models/venue.dart';
import '../models/friendship.dart';
import '../utils/debug_logger.dart';
import 'firestore_paths.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  
  // In-memory cache for venue search results
  static final Map<String, _CachedVenueResult> _venueSearchCache = {};
  static const Duration _cacheValidityDuration = Duration(minutes: 10);
  
  // In-memory cache for individual venues
  static final Map<String, _CachedVenue> _venueCache = {};
  static const Duration _venueValidityDuration = Duration(minutes: 30);

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _venuesCollection => _firestore.collection('venues');
  CollectionReference get _pulsesCollection => _firestore.collection('pulses');
  CollectionReference get _friendshipsCollection => _firestore.collection('friendships');

  /// Users
  Future<void> upsertUser(AppUser user) async {
    await _firestore
        .doc(FirestorePaths.user(user.id))
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (doc.exists) {
      return AppUser.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
    }
    return null;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    data['lastActive'] = Timestamp.now();
    await _usersCollection.doc(uid).update(data);
  }

  Stream<AppUser> userStream(String userId) {
    return _firestore
        .doc(FirestorePaths.user(userId))
        .withConverter<AppUser>(
          fromFirestore: (snapshot, _) => AppUser.fromDoc(snapshot),
          toFirestore: (user, _) => user.toMap(),
        )
        .snapshots()
        .map((snapshot) => snapshot.data()!);
  }

  /// Venues
  Future<void> upsertVenue(Venue venue) async {
    await _firestore
        .doc(FirestorePaths.venue(venue.id))
        .set(venue.toMap(), SetOptions(merge: true));
  }

  Future<Venue?> getVenue(String venueId) async {
    // Check in-memory cache first
    final cachedVenue = _venueCache[venueId];
    if (cachedVenue != null && cachedVenue.isValid) {
      print('🏪 Venue cache hit for: $venueId');
      return cachedVenue.venue;
    }

    print('🌐 Fetching venue from Firestore: $venueId');
    
    DocumentSnapshot doc;
    try {
      // Try cache first
      doc = await _venuesCollection.doc(venueId).get(const GetOptions(source: Source.cache));
      print('📱 Got venue from Firestore cache: $venueId');
    } catch (e) {
      // Fallback to server
      print('🌐 Firestore cache miss, querying server for: $venueId');
      doc = await _venuesCollection.doc(venueId).get(const GetOptions(source: Source.server));
      print('☁️ Got venue from server: $venueId');
    }
    
    if (doc.exists) {
      final venue = Venue.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
      
      // Cache the venue
      _venueCache[venueId] = _CachedVenue(venue, DateTime.now());
      
      // Clean old cache entries periodically
      _cleanVenueCache();
      
      return venue;
    }
    return null;
  }

  Stream<Venue> venueStream(String venueId) {
    return _firestore
        .doc(FirestorePaths.venue(venueId))
        .withConverter<Venue>(
          fromFirestore: (snapshot, _) => Venue.fromDoc(snapshot),
          toFirestore: (venue, _) => venue.toMap(),
        )
        .snapshots()
        .map((snapshot) => snapshot.data()!);
  }

  Future<List<Venue>> searchVenues({
    String? query,
    double? latitude,
    double? longitude,
    double? radius,
    String? category,
    int limit = 20,
  }) async {
    // Create cache key
    final cacheKey = _createVenueSearchCacheKey(
      query: query,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      category: category,
      limit: limit,
    );

    // Check cache first
    final cachedResult = _venueSearchCache[cacheKey];
    if (cachedResult != null && cachedResult.isValid) {
      DebugLogger.info('Firestore cache hit for key: ${cacheKey.length > 30 ? cacheKey.substring(0, 30) + '...' : cacheKey}', 'FirestoreService');
      return cachedResult.venues;
    }

    DebugLogger.info('Firestore query for key: ${cacheKey.length > 30 ? cacheKey.substring(0, 30) + '...' : cacheKey}', 'FirestoreService');
    
    Query venueQuery = _venuesCollection;

    if (category != null && category.isNotEmpty) {
      venueQuery = venueQuery.where('category', isEqualTo: category);
    }

    venueQuery = venueQuery.limit(limit * 2); // Get more for filtering
    
    QuerySnapshot querySnapshot;
    try {
      // Try cache first
      querySnapshot = await venueQuery.get(const GetOptions(source: Source.cache));
      print('📱 Got ${querySnapshot.docs.length} venues from Firestore cache');
    } catch (e) {
      // Fallback to server if cache fails
      print('🌐 Firestore cache miss, querying server...');
      querySnapshot = await venueQuery.get(const GetOptions(source: Source.server));
      print('☁️ Got ${querySnapshot.docs.length} venues from server');
    }
    
    List<Venue> venues = querySnapshot.docs
        .map((doc) => Venue.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
        .toList();

    // Filter by location if provided
    if (latitude != null && longitude != null && radius != null) {
      venues = venues.where((venue) {
        if (venue.location.geoPoint == null) return false;
        double distance = _calculateDistance(
          latitude, longitude, 
          venue.location.geoPoint!.latitude, 
          venue.location.geoPoint!.longitude);
        return distance <= radius;
      }).toList();
    }

    // Filter by name if query provided
    if (query != null && query.isNotEmpty) {
      venues = venues.where((venue) =>
          venue.name.toLowerCase().contains(query.toLowerCase())).toList();
    }

    // Limit results
    venues = venues.take(limit).toList();

    // Cache the result
    _venueSearchCache[cacheKey] = _CachedVenueResult(venues, DateTime.now());
    
    // Clean old cache entries periodically
    _cleanVenueSearchCache();

    return venues;
  }

  /// Pulses
  Future<void> addPulse(Pulse pulse) async {
    final batch = _firestore.batch();
    
    // Generate a new document ID if pulse.id is empty
    final pulseDocRef = pulse.id.isEmpty 
        ? _pulsesCollection.doc() 
        : _pulsesCollection.doc(pulse.id);
    
    final pulseId = pulseDocRef.id;
    
    // Create updated pulse with the generated ID and proper data
    final pulseWithId = pulse.copyWith(id: pulseId);
    final pulseData = pulseWithId.toMap();
    
    // Create pulse in main collection
    batch.set(pulseDocRef, pulseData);
    
    // Mirror pulse in user's subcollection
    batch.set(
      _firestore.doc(FirestorePaths.userPulse(pulse.userId, pulseId)),
      pulseData,
    );
    
    // Update user pulse count
    batch.update(_usersCollection.doc(pulse.userId), {
      'stats.pulseCount': FieldValue.increment(1),
      'lastActive': Timestamp.now(),
    });
    
    await batch.commit();
  }

  Future<Pulse?> getPulse(String pulseId) async {
    final doc = await _pulsesCollection.doc(pulseId).get();
    if (doc.exists) {
      return Pulse.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
    }
    return null;
  }

  Future<void> updatePulse(String pulseId, Map<String, dynamic> data) async {
    final batch = _firestore.batch();
    
    // Update in main collection
    batch.update(_pulsesCollection.doc(pulseId), data);
    
    // Get pulse to find userId for mirroring
    final pulseDoc = await _pulsesCollection.doc(pulseId).get();
    if (pulseDoc.exists) {
      final pulseData = pulseDoc.data() as Map<String, dynamic>;
      final userId = pulseData['userId'];
      
      // Update in user's subcollection
      batch.update(
        _firestore.doc(FirestorePaths.userPulse(userId, pulseId)),
        data,
      );
    }
    
    await batch.commit();
  }

  Future<void> deletePulse(String pulseId) async {
    final batch = _firestore.batch();
    
    // Get pulse data first
    final pulseDoc = await _pulsesCollection.doc(pulseId).get();
    if (!pulseDoc.exists) return;
    
    final pulseData = pulseDoc.data() as Map<String, dynamic>;
    final userId = pulseData['userId'];
    
    // Delete from main collection
    batch.delete(_pulsesCollection.doc(pulseId));
    
    // Delete from user's subcollection
    batch.delete(_firestore.doc(FirestorePaths.userPulse(userId, pulseId)));
    
    // Update user pulse count
    batch.update(_usersCollection.doc(userId), {
      'stats.pulseCount': FieldValue.increment(-1),
      'lastActive': Timestamp.now(),
    });
    
    await batch.commit();
  }

  Stream<List<Pulse>> recentPublicPulses({int limit = 20}) {
    return _firestore
        .collection('pulses')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .withConverter<Pulse>(
          fromFirestore: (snapshot, _) => Pulse.fromDoc(snapshot),
          toFirestore: (pulse, _) => pulse.toMap(),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<Pulse>> getPulsesStream({
    String? userId,
    String? venueId,
    String visibility = 'public',
    int limit = 20,
  }) {
    // Simple query - only visibility filter to avoid complex indexing
    Query pulseQuery = _pulsesCollection
        .where('visibility', isEqualTo: visibility)
        .orderBy('createdAt', descending: true)
        .limit(limit * 2); // Get more to allow client-side filtering
    
    return pulseQuery.snapshots().map((snapshot) {
      var pulses = snapshot.docs
          .map((doc) => Pulse.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      
      // Apply additional filters client-side to avoid indexing requirements
      if (userId != null) {
        pulses = pulses.where((pulse) => pulse.userId == userId).toList();
      }
      
      if (venueId != null) {
        pulses = pulses.where((pulse) => pulse.venueId == venueId).toList();
      }
      
      // Return limited results
      return pulses.take(limit).toList();
    });
  }

  Stream<List<Pulse>> getUserPulsesStream(String userId, {int limit = 20}) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('pulses')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs
                .map((doc) => Pulse.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
                .toList());
  }

  // Simple method for public pulses without complex indexing
  Stream<List<Pulse>> getSimplePublicPulsesStream({int limit = 20}) {
    try {
      return _pulsesCollection
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs
                  .map((doc) => Pulse.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
                  .toList());
    } catch (e) {
      // Fallback: return empty stream if indexing fails
      return Stream.value(<Pulse>[]);
    }
  }

  // Get feed pulses for a user (public + friends-only from friends + own posts)
  Stream<List<Pulse>> getFeedPulsesStream(String userId, {int limit = 30}) {
    return getUserFriendsStream(userId).asyncMap((friendships) async {
      List<Pulse> allPulses = [];
      
      try {
        // Get friend user IDs
        final friendIds = friendships.map((f) => f.getOtherUserId(userId)).toList();
        
        DebugLogger.info(
          '🔵 Feed Query Debug: User $userId has ${friendships.length} friendships, ${friendIds.length} friend IDs: $friendIds',
          'FirestoreService',
        );
        
        // Always include all public pulses (not just from friends)
        final publicSnapshot = await _pulsesCollection
            .where('visibility', isEqualTo: 'public')
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        
        final publicPulses = publicSnapshot.docs
            .map((doc) => Pulse.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
        
        allPulses.addAll(publicPulses);
        
        // Get friends-only pulses from friends (exclude user's own posts)
        if (friendIds.isNotEmpty) {
          final friendsOnlyIds = friendIds.where((id) => id != userId).take(10).toList();
          
          if (friendsOnlyIds.isNotEmpty) {
            try {
              DebugLogger.info(
                '🔍 Querying friends-only pulses for friend IDs: $friendsOnlyIds',
                'FirestoreService',
              );
              
              // Remove orderBy to avoid index requirement - we'll sort client-side
              final friendsSnapshot = await _pulsesCollection
                  .where('visibility', isEqualTo: 'friends')
                  .where('userId', whereIn: friendsOnlyIds)
                  .get();
              
              DebugLogger.info(
                '📊 Friends-only query returned ${friendsSnapshot.docs.length} documents',
                'FirestoreService',
              );
              
              final friendsPulses = friendsSnapshot.docs
                  .map((doc) => Pulse.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
                  .toList();
              
              // Sort by creation time on client side
              friendsPulses.sort((a, b) => 
                  (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
              
              // Take limited results
              final limitedFriendsPulses = friendsPulses.take(limit ~/ 2).toList();
              
              allPulses.addAll(limitedFriendsPulses);
              
              DebugLogger.info(
                '🎯 Added ${limitedFriendsPulses.length} friends-only pulses to feed',
                'FirestoreService',
              );
            } catch (e) {
              DebugLogger.error(
                '❌ Friends-only query failed: $e',
                'FirestoreService',
              );
              // If friends-only query fails due to indexing, continue with just public
            }
          }
        }
        
        // Sort by creation time and limit
        allPulses.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
        final result = allPulses.take(limit).toList();
        
        // Debug: Log final feed composition
        final publicCount = result.where((p) => p.visibility == 'public').length;
        final friendsCount = result.where((p) => p.visibility == 'friends').length;
        final privateCount = result.where((p) => p.visibility == 'private').length;
        
        DebugLogger.info(
          '🎪 Final feed composition: ${result.length} total (${publicCount} public, ${friendsCount} friends, ${privateCount} private)',
          'FirestoreService',
        );
        
        return result;
        
      } catch (e) {
        // Fallback to simple public feed
        final snapshot = await _pulsesCollection
            .where('visibility', isEqualTo: 'public')
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        
        return snapshot.docs
            .map((doc) => Pulse.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList();
      }
    });
  }

  // Helper method to calculate distance between two points
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

  // Cache helper methods
  String _createVenueSearchCacheKey({
    String? query,
    double? latitude,
    double? longitude,
    double? radius,
    String? category,
    int limit = 20,
  }) {
    return [
      query ?? '',
      latitude?.toStringAsFixed(3) ?? '',
      longitude?.toStringAsFixed(3) ?? '',
      radius?.toStringAsFixed(0) ?? '',
      category ?? '',
      limit.toString(),
    ].join('|');
  }

  void _cleanVenueSearchCache() {
    if (_venueSearchCache.length > 50) {
      final now = DateTime.now();
      _venueSearchCache.removeWhere((key, value) => 
        now.difference(value.timestamp) > _cacheValidityDuration);
    }
  }

  void _cleanVenueCache() {
    if (_venueCache.length > 100) {
      final now = DateTime.now();
      _venueCache.removeWhere((key, value) => 
        now.difference(value.timestamp) > _venueValidityDuration);
    }
  }

  /// Friendships
  
  // Send a friendship request
  Future<void> sendFriendRequest(String requesterId, String targetUserId) async {
    if (requesterId == targetUserId) {
      throw ArgumentError('Cannot send friend request to yourself');
    }

    final friendship = Friendship.createFriendshipRequest(
      requesterId: requesterId,
      targetUserId: targetUserId,
    );

    await _friendshipsCollection.doc(friendship.pairId).set(friendship.toMap());
  }

  // Respond to a friendship request (accept/decline)
  Future<void> respondToFriendRequest(
    String userId,
    String otherUserId,
    String response, // 'accepted', 'declined'
  ) async {
    if (!FriendshipStatus.isValid(response)) {
      throw ArgumentError('Invalid response: $response');
    }

    final pairId = Friendship.createPairId(userId, otherUserId);
    final friendshipRef = _friendshipsCollection.doc(pairId);
    
    final doc = await friendshipRef.get();
    if (!doc.exists) {
      throw Exception('Friendship request not found');
    }

    final friendship = Friendship.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
    
    if (!friendship.canRespond(userId)) {
      throw Exception('Cannot respond to this friendship request');
    }

    final updatedFriendship = friendship.copyWith(
      status: response,
      respondedAt: DateTime.now(),
    );

    final batch = _firestore.batch();
    
    // Update friendship
    batch.update(friendshipRef, updatedFriendship.toMap());
    
    // Update friend counts if accepted
    if (response == FriendshipStatus.accepted) {
      batch.update(_usersCollection.doc(userId), {
        'stats.friendCount': FieldValue.increment(1),
      });
      batch.update(_usersCollection.doc(otherUserId), {
        'stats.friendCount': FieldValue.increment(1),
      });
    }
    
    await batch.commit();
  }

  // Block a user
  Future<void> blockUser(String userId, String targetUserId) async {
    final pairId = Friendship.createPairId(userId, targetUserId);
    
    final friendship = Friendship.createFriendshipRequest(
      requesterId: userId,
      targetUserId: targetUserId,
    ).copyWith(
      status: FriendshipStatus.blocked,
      respondedAt: DateTime.now(),
    );

    await _friendshipsCollection.doc(pairId).set(friendship.toMap());
  }

  // Remove friendship (unfriend)
  Future<void> removeFriendship(String userId, String otherUserId) async {
    final pairId = Friendship.createPairId(userId, otherUserId);
    final friendshipRef = _friendshipsCollection.doc(pairId);
    
    // Check if friendship exists and was accepted
    final doc = await friendshipRef.get();
    final wasAccepted = doc.exists && 
        (doc.data() as Map<String, dynamic>)['status'] == FriendshipStatus.accepted;
    
    final batch = _firestore.batch();
    
    // Delete friendship
    batch.delete(friendshipRef);
    
    // Decrease friend counts if it was an accepted friendship
    if (wasAccepted) {
      batch.update(_usersCollection.doc(userId), {
        'stats.friendCount': FieldValue.increment(-1),
      });
      batch.update(_usersCollection.doc(otherUserId), {
        'stats.friendCount': FieldValue.increment(-1),
      });
    }
    
    await batch.commit();
  }

  // Get friendship status between two users
  Future<Friendship?> getFriendship(String userId1, String userId2) async {
    final pairId = Friendship.createPairId(userId1, userId2);
    final doc = await _friendshipsCollection.doc(pairId).get();
    
    if (doc.exists) {
      return Friendship.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
    }
    return null;
  }

  // Get all friendships for a user
  Stream<List<Friendship>> getUserFriendshipsStream(String userId) {
    return _friendshipsCollection
        .where('userId1', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot1) async {
      final friendships1 = snapshot1.docs
          .map((doc) => Friendship.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      final snapshot2 = await _friendshipsCollection
          .where('userId2', isEqualTo: userId)
          .get();
      
      final friendships2 = snapshot2.docs
          .map((doc) => Friendship.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();

      return [...friendships1, ...friendships2];
    });
  }

  // Get accepted friends for a user
  Stream<List<Friendship>> getUserFriendsStream(String userId) {
    return getUserFriendshipsStream(userId).map((friendships) =>
        friendships.where((f) => f.isAccepted).toList());
  }

  // Get pending friend requests received by user
  Stream<List<Friendship>> getPendingRequestsStream(String userId) {
    return getUserFriendshipsStream(userId).map((friendships) =>
        friendships.where((f) => f.isPending && !f.isRequester(userId)).toList());
  }

  // Get friend requests sent by user
  Stream<List<Friendship>> getSentRequestsStream(String userId) {
    return getUserFriendshipsStream(userId).map((friendships) =>
        friendships.where((f) => f.isPending && f.isRequester(userId)).toList());
  }

  // Get blocked users
  Stream<List<Friendship>> getBlockedUsersStream(String userId) {
    return getUserFriendshipsStream(userId).map((friendships) =>
        friendships.where((f) => f.isBlocked).toList());
  }

  // Get pending friend requests (received)
  Stream<List<Friendship>> getPendingFriendRequestsStream(String userId) {
    return _friendshipsCollection
        .where('userId1', isEqualTo: userId)
        .where('status', isEqualTo: FriendshipStatus.pending)
        .snapshots()
        .asyncMap((snapshot1) async {
      final requests1 = snapshot1.docs
          .map((doc) => Friendship.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
          .where((f) => f.requesterId != userId) // Requests received, not sent
          .toList();

      final snapshot2 = await _friendshipsCollection
          .where('userId2', isEqualTo: userId)
          .where('status', isEqualTo: FriendshipStatus.pending)
          .get();
      
      final requests2 = snapshot2.docs
          .map((doc) => Friendship.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
          .where((f) => f.requesterId != userId) // Requests received, not sent
          .toList();

      return [...requests1, ...requests2];
    });
  }

  // Get sent friend requests (pending)
  Stream<List<Friendship>> getSentFriendRequestsStream(String userId) {
    return getUserFriendshipsStream(userId).map((friendships) =>
        friendships.where((f) => f.isPending && f.requesterId == userId).toList());
  }

  // Check if users are friends
  Future<bool> areFriends(String userId1, String userId2) async {
    final friendship = await getFriendship(userId1, userId2);
    return friendship?.isAccepted ?? false;
  }

  // Get friends count for a user
  Future<int> getFriendsCount(String userId) async {
    final friendships = await getUserFriendsStream(userId).first;
    return friendships.length;
  }
}

// Cache helper classes
class _CachedVenueResult {
  final List<Venue> venues;
  final DateTime timestamp;
  
  _CachedVenueResult(this.venues, this.timestamp);
  
  bool get isValid => DateTime.now().difference(timestamp) < FirestoreService._cacheValidityDuration;
}

class _CachedVenue {
  final Venue venue;
  final DateTime timestamp;
  
  _CachedVenue(this.venue, this.timestamp);
  
  bool get isValid => DateTime.now().difference(timestamp) < FirestoreService._venueValidityDuration;
}
