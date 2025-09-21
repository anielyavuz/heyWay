import 'package:flutter/foundation.dart';
import '../models/friendship.dart';
import '../services/firestore_service.dart';
import '../utils/debug_logger.dart';

class FriendsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  // State variables
  List<Friendship> _friends = [];
  List<Friendship> _pendingRequests = [];
  List<Friendship> _sentRequests = [];
  List<Friendship> _blockedUsers = [];
  
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<Friendship> get friends => _friends;
  List<Friendship> get pendingRequests => _pendingRequests;
  List<Friendship> get sentRequests => _sentRequests;
  List<Friendship> get blockedUsers => _blockedUsers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Check if two users are friends
  bool areFriends(String userId1, String userId2) {
    return _friends.any((friendship) => 
      (friendship.userId1 == userId1 && friendship.userId2 == userId2) ||
      (friendship.userId1 == userId2 && friendship.userId2 == userId1)
    );
  }
  
  // Check if there's a pending request between users
  bool hasPendingRequest(String userId1, String userId2) {
    return _pendingRequests.any((friendship) => 
      (friendship.userId1 == userId1 && friendship.userId2 == userId2) ||
      (friendship.userId1 == userId2 && friendship.userId2 == userId1)
    ) || _sentRequests.any((friendship) => 
      (friendship.userId1 == userId1 && friendship.userId2 == userId2) ||
      (friendship.userId1 == userId2 && friendship.userId2 == userId1)
    );
  }
  
  // Check if user is blocked
  bool isBlocked(String userId1, String userId2) {
    return _blockedUsers.any((friendship) => 
      (friendship.userId1 == userId1 && friendship.userId2 == userId2) ||
      (friendship.userId1 == userId2 && friendship.userId2 == userId1)
    );
  }
  
  // Initialize streams for a user
  void initializeForUser(String userId) {
    DebugLogger.info('Initializing friends provider for user: ${userId.length > 8 ? userId.substring(0, 8) : userId}...', 'FriendsProvider');
    _clearData();
    _setupStreams(userId);
  }
  
  void _clearData() {
    _friends.clear();
    _pendingRequests.clear();
    _sentRequests.clear();
    _blockedUsers.clear();
    _error = null;
    notifyListeners();
  }
  
  void _setupStreams(String userId) {
    // Listen to friends stream
    _firestoreService.getUserFriendsStream(userId).listen(
      (friendships) {
        _friends = friendships;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load friends: $error';
        notifyListeners();
      },
    );
    
    // Listen to pending requests stream
    _firestoreService.getPendingRequestsStream(userId).listen(
      (requests) {
        _pendingRequests = requests;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load pending requests: $error';
        notifyListeners();
      },
    );
    
    // Listen to sent requests stream
    _firestoreService.getSentRequestsStream(userId).listen(
      (requests) {
        _sentRequests = requests;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load sent requests: $error';
        notifyListeners();
      },
    );
    
    // Listen to blocked users stream
    _firestoreService.getBlockedUsersStream(userId).listen(
      (blocked) {
        _blockedUsers = blocked;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Failed to load blocked users: $error';
        notifyListeners();
      },
    );
  }
  
  // Send friend request
  Future<void> sendFriendRequest(String requesterId, String targetUserId) async {
    if (_isLoading) return;
    
    DebugLogger.info('Sending friend request from ${requesterId.length > 8 ? requesterId.substring(0, 8) : requesterId}... to ${targetUserId.length > 8 ? targetUserId.substring(0, 8) : targetUserId}...', 'FriendsProvider');
    _setLoading(true);
    try {
      await _firestoreService.sendFriendRequest(requesterId, targetUserId);
      DebugLogger.info('Friend request sent successfully', 'FriendsProvider');
      _clearError();
    } catch (e) {
      DebugLogger.error('Failed to send friend request: $e', 'FriendsProvider');
      _setError('Failed to send friend request: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Accept friend request
  Future<void> acceptFriendRequest(String userId, String otherUserId) async {
    if (_isLoading) return;
    
    _setLoading(true);
    try {
      await _firestoreService.respondToFriendRequest(
        userId, 
        otherUserId, 
        FriendshipStatus.accepted
      );
      _clearError();
    } catch (e) {
      _setError('Failed to accept friend request: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Decline friend request
  Future<void> declineFriendRequest(String userId, String otherUserId) async {
    if (_isLoading) return;
    
    _setLoading(true);
    try {
      await _firestoreService.respondToFriendRequest(
        userId, 
        otherUserId, 
        FriendshipStatus.declined
      );
      _clearError();
    } catch (e) {
      _setError('Failed to decline friend request: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Block user
  Future<void> blockUser(String userId, String otherUserId) async {
    if (_isLoading) return;
    
    _setLoading(true);
    try {
      await _firestoreService.blockUser(userId, otherUserId);
      _clearError();
    } catch (e) {
      _setError('Failed to block user: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Unblock user
  Future<void> unblockUser(String userId, String otherUserId) async {
    if (_isLoading) return;
    
    _setLoading(true);
    try {
      await _firestoreService.removeFriendship(userId, otherUserId);
      _clearError();
    } catch (e) {
      _setError('Failed to unblock user: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Remove friendship
  Future<void> removeFriend(String userId, String otherUserId) async {
    if (_isLoading) return;
    
    _setLoading(true);
    try {
      await _firestoreService.removeFriendship(userId, otherUserId);
      _clearError();
    } catch (e) {
      _setError('Failed to remove friend: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Cancel sent friend request
  Future<void> cancelFriendRequest(String userId, String otherUserId) async {
    if (_isLoading) return;
    
    _setLoading(true);
    try {
      await _firestoreService.removeFriendship(userId, otherUserId);
      _clearError();
    } catch (e) {
      _setError('Failed to cancel friend request: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  void _clearError() {
    _error = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _clearData();
    super.dispose();
  }
}