class ReconnectPolicy {
  ReconnectPolicy._();

  static const List<Duration> dropSchedule = [
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 32),
    Duration(seconds: 60),
  ];

  static const List<Duration> errorSchedule = [
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
    Duration(seconds: 24),
    Duration(seconds: 48),
  ];

  static final int maxErrorAttempts = errorSchedule.length;

  static const Duration connectingStuckAfter = Duration(seconds: 90);

  static const Set<String> fatalErrors = {
    'vpn_permission_denied',
    'no_profile',
    'unsupported_profile',
  };

  static bool isFatal(String? error) {
    if (error == null || error.isEmpty) return false;
    if (fatalErrors.contains(error)) return true;
    return error.contains('permission') ||
        error.contains('no_profile') ||
        error.contains('unsupported_profile');
  }

  static Duration _pick(List<Duration> schedule, int attempt) {
    if (attempt < 0) attempt = 0;
    if (attempt >= schedule.length) return schedule.last;
    return schedule[attempt];
  }

  static Duration dropDelay(int attempt) => _pick(dropSchedule, attempt);

  static Duration errorDelay(int attempt) => _pick(errorSchedule, attempt);
}
