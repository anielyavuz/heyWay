import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.privacy,
    required this.stats,
    required this.homeGeoPoint,
    required this.lastActive,
    required this.pushTokens,
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      id: doc.id,
      displayName: data['displayName'] as String? ?? '',
      username: data['username'] as String? ?? '',
      avatarUrl: data['avatarUrl'] as String? ?? '',
      privacy: PrivacySettings.fromMap(
        data['privacy'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      stats: UserStats.fromMap(
        data['stats'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      homeGeoPoint: data['homeGeoPoint'] as GeoPoint?,
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      pushTokens: (data['pushTokens'] as List<dynamic>? ?? const <dynamic>[])
          .cast<String>(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'username': username,
      'avatarUrl': avatarUrl,
      'privacy': privacy.toMap(),
      'stats': stats.toMap(),
      'homeGeoPoint': homeGeoPoint,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      'pushTokens': pushTokens,
    }..removeWhere((key, value) => value == null);
  }

  final String id;
  final String displayName;
  final String username;
  final String avatarUrl;
  final PrivacySettings privacy;
  final UserStats stats;
  final GeoPoint? homeGeoPoint;
  final DateTime? lastActive;
  final List<String> pushTokens;

  AppUser copyWith({
    String? displayName,
    String? username,
    String? avatarUrl,
    PrivacySettings? privacy,
    UserStats? stats,
    GeoPoint? homeGeoPoint,
    DateTime? lastActive,
    List<String>? pushTokens,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      privacy: privacy ?? this.privacy,
      stats: stats ?? this.stats,
      homeGeoPoint: homeGeoPoint ?? this.homeGeoPoint,
      lastActive: lastActive ?? this.lastActive,
      pushTokens: pushTokens ?? this.pushTokens,
    );
  }
}

@immutable
class PrivacySettings {
  const PrivacySettings({
    required this.profile,
    required this.pulses,
    required this.locationSharing,
  });

  factory PrivacySettings.fromMap(Map<String, dynamic> map) {
    return PrivacySettings(
      profile: map['profile'] as String? ?? 'public',
      pulses: map['pulses'] as String? ?? 'public',
      locationSharing: map['locationSharing'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'profile': profile,
    'pulses': pulses,
    'locationSharing': locationSharing,
  };

  final String profile;
  final String pulses;
  final bool locationSharing;
}

@immutable
class UserStats {
  const UserStats({
    required this.pulseCount,
    required this.friendCount,
    required this.badgeCount,
  });

  factory UserStats.fromMap(Map<String, dynamic> map) {
    return UserStats(
      pulseCount: (map['pulseCount'] as num?)?.toInt() ?? 0,
      friendCount: (map['friendCount'] as num?)?.toInt() ?? 0,
      badgeCount: (map['badgeCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'pulseCount': pulseCount,
    'friendCount': friendCount,
    'badgeCount': badgeCount,
  };

  final int pulseCount;
  final int friendCount;
  final int badgeCount;
}
