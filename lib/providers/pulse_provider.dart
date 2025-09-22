import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/pulse.dart';
import '../models/venue.dart';
import '../services/firestore_service.dart';
import '../utils/debug_logger.dart';

class PulseProvider extends ChangeNotifier {
  PulseProvider({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  List<Pulse> _userPulses = [];
  List<Pulse> _publicPulses = [];
  bool _isLoadingUserPulses = false;
  bool _isLoadingPublicPulses = false;
  String? _error;
  final Map<String, Venue> _cachedVenues = {};
  final Set<String> _loadingVenueIds = {};
  final Map<String, AppUser> _cachedUsers = {};
  final Set<String> _loadingUserIds = {};
  StreamSubscription<List<Pulse>>? _userPulsesSubscription;
  StreamSubscription<List<Pulse>>? _publicPulsesSubscription;

  // Getters
  List<Pulse> get userPulses => _userPulses;
  List<Pulse> get publicPulses => _publicPulses;
  bool get isLoadingUserPulses => _isLoadingUserPulses;
  bool get isLoadingPublicPulses => _isLoadingPublicPulses;
  String? get error => _error;
  Venue? getVenueById(String venueId) => _cachedVenues[venueId];
  Map<String, Venue> get cachedVenues => Map.unmodifiable(_cachedVenues);
  AppUser? getUserById(String userId) => _cachedUsers[userId];
  Map<String, AppUser> get cachedUsers => Map.unmodifiable(_cachedUsers);

  // Load user's own pulses
  Future<void> loadUserPulses(String userId) async {
    _userPulsesSubscription?.cancel();

    _isLoadingUserPulses = true;
    _error = null;
    notifyListeners();

    _userPulsesSubscription = _firestoreService
        .getUserPulsesStream(userId, limit: 50)
        .listen(
          (pulses) {
            _userPulses = pulses;
            _isLoadingUserPulses = false;
            notifyListeners();
            unawaited(_preloadVenuesForPulses(pulses));
            unawaited(_preloadUsersForPulses(pulses));
          },
          onError: (error) {
            DebugLogger.error(
              'Failed to load user pulses: $error',
              'PulseProvider',
            );
            _error = 'Failed to load your pulses: $error';
            _userPulses = [];
            _isLoadingUserPulses = false;
            notifyListeners();
          },
        );
  }

  // Load feed pulses (public + friends-only from friends + own posts)
  Future<void> loadFeedPulses(String userId) async {
    _publicPulsesSubscription?.cancel();

    _isLoadingPublicPulses = true;
    _error = null;
    notifyListeners();

    _publicPulsesSubscription = _firestoreService
        .getFeedPulsesStream(userId, limit: 30)
        .listen(
          (pulses) {
            _publicPulses = pulses;
            _isLoadingPublicPulses = false;
            notifyListeners();
            unawaited(_preloadVenuesForPulses(pulses));
            unawaited(_preloadUsersForPulses(pulses));
          },
          onError: (error) {
            DebugLogger.warning(
              'Enhanced feed failed: $error, falling back to simple public feed',
              'PulseProvider',
            );

            _publicPulsesSubscription?.cancel();
            _publicPulsesSubscription = _firestoreService
                .getSimplePublicPulsesStream(limit: 30)
                .listen(
                  (pulses) {
                    _publicPulses = pulses;
                    _isLoadingPublicPulses = false;
                    notifyListeners();
                    unawaited(_preloadVenuesForPulses(pulses));
                    unawaited(_preloadUsersForPulses(pulses));
                  },
                  onError: (fallbackError) {
                    DebugLogger.error(
                      'Simple public feed also failed: $fallbackError',
                      'PulseProvider',
                    );
                    _publicPulses = [];
                    _isLoadingPublicPulses = false;
                    notifyListeners();
                  },
                );
          },
        );
  }

  // Legacy method for backward compatibility
  Future<void> loadPublicPulses() async {
    _publicPulsesSubscription?.cancel();

    _isLoadingPublicPulses = true;
    _error = null;
    notifyListeners();

    _publicPulsesSubscription = _firestoreService
        .getSimplePublicPulsesStream(limit: 30)
        .listen(
          (pulses) {
            _publicPulses = pulses;
            _isLoadingPublicPulses = false;
            notifyListeners();
            unawaited(_preloadVenuesForPulses(pulses));
            unawaited(_preloadUsersForPulses(pulses));
          },
          onError: (error) {
            DebugLogger.warning(
              'Public pulses loading failed: $error',
              'PulseProvider',
            );
            _publicPulses = [];
            _error = null;
            _isLoadingPublicPulses = false;
            notifyListeners();
          },
        );
  }

  Future<void> _preloadVenuesForPulses(List<Pulse> pulses) async {
    final idsToLoad = <String>{};
    for (final pulse in pulses) {
      final venueId = pulse.venueId;
      if (venueId.isEmpty) continue;
      if (_cachedVenues.containsKey(venueId)) continue;
      if (_loadingVenueIds.contains(venueId)) continue;
      idsToLoad.add(venueId);
    }

    if (idsToLoad.isEmpty) {
      return;
    }

    var hasUpdates = false;

    await Future.wait(
      idsToLoad.map((venueId) async {
        _loadingVenueIds.add(venueId);
        try {
          final venue = await _firestoreService.getVenue(venueId);
          if (venue != null) {
            _cachedVenues[venueId] = venue;
            hasUpdates = true;
          }
        } catch (error) {
          DebugLogger.warning(
            'Failed to preload venue $venueId: $error',
            'PulseProvider',
          );
        } finally {
          _loadingVenueIds.remove(venueId);
        }
      }),
    );

    if (hasUpdates) {
      notifyListeners();
    }
  }

  Future<void> _preloadUsersForPulses(List<Pulse> pulses) async {
    final idsToLoad = <String>{};
    for (final pulse in pulses) {
      final userId = pulse.userId;
      if (userId.isEmpty) continue;
      if (_cachedUsers.containsKey(userId)) continue;
      if (_loadingUserIds.contains(userId)) continue;
      idsToLoad.add(userId);
    }

    if (idsToLoad.isEmpty) {
      return;
    }

    var hasUpdates = false;

    await Future.wait(
      idsToLoad.map((userId) async {
        _loadingUserIds.add(userId);
        try {
          final user = await _firestoreService.getUser(userId);
          if (user != null) {
            _cachedUsers[userId] = user;
            hasUpdates = true;
          }
        } catch (error) {
          DebugLogger.warning(
            'Failed to preload user $userId: $error',
            'PulseProvider',
          );
        } finally {
          _loadingUserIds.remove(userId);
        }
      }),
    );

    if (hasUpdates) {
      notifyListeners();
    }
  }

  // Add a new pulse to the local cache
  void addPulse(Pulse pulse) {
    if (pulse.userId.isNotEmpty) {
      _userPulses.insert(0, pulse);

      if (pulse.visibility == 'public') {
        _publicPulses.insert(0, pulse);
      }

      notifyListeners();
      unawaited(_preloadVenuesForPulses([pulse]));
      unawaited(_preloadUsersForPulses([pulse]));
    }
  }

  // Remove a pulse from local cache
  void removePulse(String pulseId) {
    _userPulses.removeWhere((pulse) => pulse.id == pulseId);
    _publicPulses.removeWhere((pulse) => pulse.id == pulseId);
    notifyListeners();
  }

  // Update a pulse in local cache
  void updatePulse(Pulse updatedPulse) {
    // Update in user pulses
    final userIndex = _userPulses.indexWhere((p) => p.id == updatedPulse.id);
    if (userIndex != -1) {
      _userPulses[userIndex] = updatedPulse;
    }

    // Update in public pulses
    final publicIndex = _publicPulses.indexWhere(
      (p) => p.id == updatedPulse.id,
    );
    if (publicIndex != -1) {
      _publicPulses[publicIndex] = updatedPulse;
    }

    notifyListeners();
  }

  // Clear all data
  void clear() {
    _userPulses.clear();
    _publicPulses.clear();
    _isLoadingUserPulses = false;
    _isLoadingPublicPulses = false;
    _error = null;
    _userPulsesSubscription?.cancel();
    _userPulsesSubscription = null;
    _publicPulsesSubscription?.cancel();
    _publicPulsesSubscription = null;
    _cachedVenues.clear();
    _loadingVenueIds.clear();
    _cachedUsers.clear();
    _loadingUserIds.clear();
    notifyListeners();
  }

  // Refresh user pulses
  Future<void> refreshUserPulses(String userId) async {
    _userPulses.clear();
    await loadUserPulses(userId);
  }

  // Refresh public pulses
  Future<void> refreshPublicPulses() async {
    _publicPulses.clear();
    await loadPublicPulses();
  }

  @override
  void dispose() {
    _userPulsesSubscription?.cancel();
    _publicPulsesSubscription?.cancel();
    _cachedVenues.clear();
    _loadingVenueIds.clear();
    _cachedUsers.clear();
    _loadingUserIds.clear();
    super.dispose();
  }
}
