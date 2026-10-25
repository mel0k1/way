/// Exponential-backoff schedule for the auto-reconnect watchdog.
///
/// Two paths are covered:
/// * [dropSchedule] — the tunnel/engine dropped while the user wanted to stay
///   connected (app relaunch of the core, service death, network change).
/// * [errorSchedule] — a connect attempt itself failed and the watchdog keeps
///   retrying a bounded number of times before giving up.
class ReconnectPolicy {
  ReconnectPolicy._();

  /// Delays between reconnect attempts after an unexpected drop.
  /// The first attempt is delayed long enough for the in-core watchdog
  /// (5s tick) to restore the engine on its own.
  static const List<Duration> dropSchedule = [
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 32),
    Duration(seconds: 60),
  ];

  /// Delays between retries after a failed connect attempt.
  static const List<Duration> errorSchedule = [
    Duration(seconds: 3),
    Duration(seconds: 6),
    Duration(seconds: 12),
    Duration(seconds: 24),
    Duration(seconds: 48),
  ];

  /// Maximum number of retry attempts after connect errors, after which the
  /// watchdog gives up and waits for explicit user action.
  static final int maxErrorAttempts = errorSchedule.length;

  /// A connect was stuck in the connecting phase for longer than this —
  /// force a full disconnect/reconnect cycle.
  static const Duration connectingStuckAfter = Duration(seconds: 90);

  /// Errors that must never be retried automatically (user decision needed).
  static const Set<String> fatalErrors = {
    'vpn_permission_denied',
    'no_profile',
    'unsupported_profile',
  };

  /// Fatal-error matcher for raw platform messages: Android surfaces native
  /// exception texts (e.g. "missing vpn permission") that are not exact keys
  /// of [fatalErrors] but are just as hopeless to retry.
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
