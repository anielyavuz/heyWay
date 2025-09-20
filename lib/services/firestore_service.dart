import 'dart:math' show sin, cos, sqrt, atan2, pi;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/pulse.dart';
import '../models/venue.dart';
import 'firestore_paths.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _venuesCollection => _firestore.collection('venues');
  CollectionReference get _pulsesCollection => _firestore.collection('pulses');

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
    final doc = await _venuesCollection.doc(venueId).get();
    if (doc.exists) {
      return Venue.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>);
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
    Query venueQuery = _venuesCollection;

    if (category != null && category.isNotEmpty) {
      venueQuery = venueQuery.where('category', isEqualTo: category);
    }

    venueQuery = venueQuery.limit(limit);
    
    final querySnapshot = await venueQuery.get();
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

    return venues;
  }

  /// Pulses
  Future<void> addPulse(Pulse pulse) async {
    final batch = _firestore.batch();
    
    // Create pulse in main collection
    batch.set(_pulsesCollection.doc(pulse.id), pulse.toMap());
    
    // Mirror pulse in user's subcollection
    batch.set(
      _firestore.doc(FirestorePaths.userPulse(pulse.userId, pulse.id)),
      pulse.toMap(),
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
    Query pulseQuery = _pulsesCollection;
    
    if (userId != null) {
      pulseQuery = pulseQuery.where('userId', isEqualTo: userId);
    }
    
    if (venueId != null) {
      pulseQuery = pulseQuery.where('venueId', isEqualTo: venueId);
    }
    
    pulseQuery = pulseQuery
        .where('visibility', isEqualTo: visibility)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    
    return pulseQuery.snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => Pulse.fromDoc(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
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
}
