import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../services/firestore_service.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  User? _user;
  AppUser? _appUser;
  bool _isLoading = false;

  User? get user => _user;
  AppUser? get appUser => _appUser;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _user != null;

  void _onAuthStateChanged(User? user) async {
    _user = user;

    if (user != null) {
      try {
        _appUser = await _firestoreService.getUser(user.uid);

        // Create user document if it doesn't exist
        if (_appUser == null) {
          _appUser = AppUser(
            id: user.uid,
            displayName: user.displayName ?? 'User',
            username: user.email?.split('@').first ?? 'user',
            avatarUrl: user.photoURL ?? '',
            privacy: const PrivacySettings(
              profile: 'public',
              pulses: 'friends',
              locationSharing: false,
            ),
            stats: const UserStats(
              pulseCount: 0,
              friendCount: 0,
              badgeCount: 0,
            ),
            homeGeoPoint: null,
            lastActive: DateTime.now(),
            pushTokens: const [],
          );

          await _firestoreService.upsertUser(_appUser!);
        }
      } catch (e) {
        debugPrint('Error loading user data: $e');
      }
    } else {
      _appUser = null;
    }

    notifyListeners();
  }

  Future<void> signInAnonymously() async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint('Error signing in with email: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createUserWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);

        final appUser = AppUser(
          id: user.uid,
          displayName: displayName,
          username: displayName,
          avatarUrl: user.photoURL ?? '',
          privacy: const PrivacySettings(
            profile: 'public',
            pulses: 'friends',
            locationSharing: false,
          ),
          stats: const UserStats(pulseCount: 0, friendCount: 0, badgeCount: 0),
          homeGeoPoint: null,
          lastActive: DateTime.now(),
          pushTokens: const [],
        );

        await _firestoreService.upsertUser(appUser);
        _appUser = appUser;
      }
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> linkAnonymousAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || !currentUser.isAnonymous) {
      throw FirebaseAuthException(
        code: 'operation-not-allowed',
        message: 'Only anonymous users can be linked.',
      );
    }

    try {
      _isLoading = true;
      notifyListeners();

      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      final result = await currentUser.linkWithCredential(credential);
      final linkedUser = result.user ?? currentUser;

      await linkedUser.updateDisplayName(displayName);

      final existingUser = await _firestoreService.getUser(linkedUser.uid);
      final updatedUser =
          (existingUser ??
                  AppUser(
                    id: linkedUser.uid,
                    displayName: displayName,
                    username: displayName,
                    avatarUrl: linkedUser.photoURL ?? '',
                    privacy: const PrivacySettings(
                      profile: 'public',
                      pulses: 'friends',
                      locationSharing: false,
                    ),
                    stats: const UserStats(
                      pulseCount: 0,
                      friendCount: 0,
                      badgeCount: 0,
                    ),
                    homeGeoPoint: null,
                    lastActive: DateTime.now(),
                    pushTokens: const [],
                  ))
              .copyWith(displayName: displayName, username: displayName);

      await _firestoreService.upsertUser(updatedUser);
      _appUser = updatedUser;
    } catch (e) {
      debugPrint('Error linking anonymous account: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  Future<void> updateProfile(AppUser updatedUser) async {
    try {
      await _firestoreService.upsertUser(updatedUser);
      _appUser = updatedUser;
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }
}
