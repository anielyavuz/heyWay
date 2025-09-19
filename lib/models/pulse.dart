import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Pulse {
  const Pulse({
    required this.id,
    required this.userId,
    required this.venueId,
    required this.caption,
    required this.mood,
    required this.visibility,
    required this.mediaRefs,
    required this.badgeUnlocks,
    required this.likesCount,
    required this.commentCount,
    required this.createdAt,
  });

  factory Pulse.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Pulse(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      venueId: data['venueId'] as String? ?? '',
      caption: data['caption'] as String? ?? '',
      mood: data['mood'] as String? ?? '',
      visibility: data['visibility'] as String? ?? 'public',
      mediaRefs: (data['mediaRefs'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>(),
      badgeUnlocks:
          (data['badgeUnlocks'] as List<dynamic>? ?? const <dynamic>[])
              .cast<String>(),
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'venueId': venueId,
      'caption': caption,
      'mood': mood,
      'visibility': visibility,
      'mediaRefs': mediaRefs,
      'badgeUnlocks': badgeUnlocks,
      'likesCount': likesCount,
      'commentCount': commentCount,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    }..removeWhere((key, value) => value == null);
  }

  final String id;
  final String userId;
  final String venueId;
  final String caption;
  final String mood;
  final String visibility;
  final List<String> mediaRefs;
  final List<String> badgeUnlocks;
  final int likesCount;
  final int commentCount;
  final DateTime? createdAt;

  Pulse copyWith({
    String? caption,
    String? mood,
    String? visibility,
    List<String>? mediaRefs,
    List<String>? badgeUnlocks,
    int? likesCount,
    int? commentCount,
    DateTime? createdAt,
  }) {
    return Pulse(
      id: id,
      userId: userId,
      venueId: venueId,
      caption: caption ?? this.caption,
      mood: mood ?? this.mood,
      visibility: visibility ?? this.visibility,
      mediaRefs: mediaRefs ?? this.mediaRefs,
      badgeUnlocks: badgeUnlocks ?? this.badgeUnlocks,
      likesCount: likesCount ?? this.likesCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
