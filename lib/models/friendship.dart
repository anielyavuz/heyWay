import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Friendship {
  const Friendship({
    required this.pairId,
    required this.userId1,
    required this.userId2,
    required this.status,
    required this.requesterId,
    required this.requestedAt,
    this.respondedAt,
  });

  factory Friendship.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Friendship(
      pairId: doc.id,
      userId1: data['userId1'] as String? ?? '',
      userId2: data['userId2'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      requesterId: data['requesterId'] as String? ?? '',
      requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId1': userId1,
      'userId2': userId2,
      'status': status,
      'requesterId': requesterId,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    }..removeWhere((key, value) => value == null);
  }

  // Composite key format: sorted user IDs joined with underscore
  static String createPairId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  static Friendship createFriendshipRequest({
    required String requesterId,
    required String targetUserId,
  }) {
    final pairId = createPairId(requesterId, targetUserId);
    final sortedIds = [requesterId, targetUserId]..sort();
    
    return Friendship(
      pairId: pairId,
      userId1: sortedIds[0],
      userId2: sortedIds[1],
      status: FriendshipStatus.pending,
      requesterId: requesterId,
      requestedAt: DateTime.now(),
    );
  }

  final String pairId;
  final String userId1;
  final String userId2;
  final String status;
  final String requesterId;
  final DateTime requestedAt;
  final DateTime? respondedAt;

  // Helper methods
  bool get isPending => status == FriendshipStatus.pending;
  bool get isAccepted => status == FriendshipStatus.accepted;
  bool get isBlocked => status == FriendshipStatus.blocked;
  bool get isDeclined => status == FriendshipStatus.declined;

  // Get the other user ID from perspective of given user
  String getOtherUserId(String currentUserId) {
    if (userId1 == currentUserId) return userId2;
    if (userId2 == currentUserId) return userId1;
    throw ArgumentError('Current user ID not found in friendship');
  }

  // Check if current user is the requester
  bool isRequester(String currentUserId) {
    return requesterId == currentUserId;
  }

  // Check if current user can respond to the request
  bool canRespond(String currentUserId) {
    return isPending && !isRequester(currentUserId);
  }

  Friendship copyWith({
    String? status,
    DateTime? respondedAt,
  }) {
    return Friendship(
      pairId: pairId,
      userId1: userId1,
      userId2: userId2,
      status: status ?? this.status,
      requesterId: requesterId,
      requestedAt: requestedAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Friendship && runtimeType == other.runtimeType && pairId == other.pairId;

  @override
  int get hashCode => pairId.hashCode;

  @override
  String toString() {
    return 'Friendship{pairId: $pairId, status: $status, requester: $requesterId}';
  }
}

// Friendship status constants
class FriendshipStatus {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String declined = 'declined';
  static const String blocked = 'blocked';

  static const List<String> allStatuses = [
    pending,
    accepted,
    declined,
    blocked,
  ];

  static bool isValid(String status) {
    return allStatuses.contains(status);
  }
}

// Friendship helper extensions
extension FriendshipStatusExtension on String {
  bool get isPendingFriendship => this == FriendshipStatus.pending;
  bool get isAcceptedFriendship => this == FriendshipStatus.accepted;
  bool get isDeclinedFriendship => this == FriendshipStatus.declined;
  bool get isBlockedFriendship => this == FriendshipStatus.blocked;
}