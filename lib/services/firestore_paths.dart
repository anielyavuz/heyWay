class FirestorePaths {
  FirestorePaths._();

  static String user(String userId) => 'users/$userId';
  static String venue(String venueId) => 'venues/$venueId';
  static String pulse(String pulseId) => 'pulses/$pulseId';

  static String userPulses(String userId) => 'users/$userId/pulses';
  static String userPulse(String userId, String pulseId) =>
      'users/$userId/pulses/$pulseId';

  static String venueTips(String venueId) => 'venues/$venueId/tips';
  static String venueTip(String venueId, String tipId) =>
      'venues/$venueId/tips/$tipId';
}
