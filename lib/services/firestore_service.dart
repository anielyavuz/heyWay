import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/pulse.dart';
import '../models/venue.dart';
import 'firestore_paths.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Users
  Future<void> upsertUser(AppUser user) async {
    await _firestore
        .doc(FirestorePaths.user(user.id))
        .set(user.toMap(), SetOptions(merge: true));
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

  /// Pulses
  Future<void> addPulse(Pulse pulse) async {
    await _firestore.collection('pulses').doc(pulse.id).set(pulse.toMap());
    await _firestore
        .doc(FirestorePaths.userPulse(pulse.userId, pulse.id))
        .set(pulse.toMap());
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
}
