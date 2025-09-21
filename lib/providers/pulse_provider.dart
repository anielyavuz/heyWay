import 'package:flutter/foundation.dart';
import '../models/pulse.dart';
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

  // Getters
  List<Pulse> get userPulses => _userPulses;
  List<Pulse> get publicPulses => _publicPulses;
  bool get isLoadingUserPulses => _isLoadingUserPulses;
  bool get isLoadingPublicPulses => _isLoadingPublicPulses;
  String? get error => _error;

  // Load user's own pulses
  Future<void> loadUserPulses(String userId) async {
    if (_isLoadingUserPulses) return;

    _isLoadingUserPulses = true;
    _error = null;
    notifyListeners();

    try {
      // Get pulses from user's subcollection for better performance
      final pulses = await _firestoreService
          .getUserPulsesStream(userId, limit: 50)
          .first;
      
      _userPulses = pulses;
    } catch (e) {
      _error = 'Failed to load your pulses: $e';
      _userPulses = [];
    } finally {
      _isLoadingUserPulses = false;
      notifyListeners();
    }
  }

  // Load feed pulses (public + friends-only from friends + own posts)
  Future<void> loadFeedPulses(String userId) async {
    if (_isLoadingPublicPulses) return;

    _isLoadingPublicPulses = true;
    _error = null;
    notifyListeners();

    try {
      // Try enhanced feed first (now that indexes are enabled)
      DebugLogger.info('Loading enhanced feed with friends content', 'PulseProvider');
      final pulses = await _firestoreService
          .getFeedPulsesStream(userId, limit: 30)
          .first;
      _publicPulses = pulses;
    } catch (e) {
      // Fallback to simple public feed
      DebugLogger.warning('Enhanced feed failed: $e, falling back to simple public feed', 'PulseProvider');
      try {
        final pulses = await _firestoreService
            .getSimplePublicPulsesStream(limit: 30)
            .first;
        _publicPulses = pulses;
      } catch (e2) {
        DebugLogger.error('Simple public feed also failed: $e2', 'PulseProvider');
        _publicPulses = [];
      }
      _error = null; // Don't show error to user for indexing issues
    } finally {
      _isLoadingPublicPulses = false;
      notifyListeners();
    }
  }

  // Legacy method for backward compatibility
  Future<void> loadPublicPulses() async {
    // For backward compatibility, load simple public pulses
    if (_isLoadingPublicPulses) return;

    _isLoadingPublicPulses = true;
    _error = null;
    notifyListeners();

    try {
      final pulses = await _firestoreService
          .getSimplePublicPulsesStream(limit: 30)
          .first;
      
      _publicPulses = pulses;
    } catch (e) {
      DebugLogger.warning('Public pulses loading failed: $e', 'PulseProvider');
      _publicPulses = [];
      _error = null;
    } finally {
      _isLoadingPublicPulses = false;
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
    final publicIndex = _publicPulses.indexWhere((p) => p.id == updatedPulse.id);
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
}