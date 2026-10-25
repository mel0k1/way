import 'package:flutter_test/flutter_test.dart';
import 'package:way/core/reconnect_policy.dart';

void main() {
  group('ReconnectPolicy.dropDelay', () {
    test('follows the exponential drop schedule', () {
      expect(ReconnectPolicy.dropDelay(0), const Duration(seconds: 8));
      expect(ReconnectPolicy.dropDelay(1), const Duration(seconds: 16));
      expect(ReconnectPolicy.dropDelay(2), const Duration(seconds: 32));
    });

    test('caps at 60 seconds for late attempts', () {
      expect(ReconnectPolicy.dropDelay(3), const Duration(seconds: 60));
      expect(ReconnectPolicy.dropDelay(4), const Duration(seconds: 60));
      expect(ReconnectPolicy.dropDelay(50), const Duration(seconds: 60));
      expect(ReconnectPolicy.dropDelay(-1), const Duration(seconds: 8));
    });
  });

  group('ReconnectPolicy.errorDelay', () {
    test('follows the error retry schedule', () {
      expect(ReconnectPolicy.errorDelay(0), const Duration(seconds: 3));
      expect(ReconnectPolicy.errorDelay(1), const Duration(seconds: 6));
      expect(ReconnectPolicy.errorDelay(2), const Duration(seconds: 12));
      expect(ReconnectPolicy.errorDelay(3), const Duration(seconds: 24));
      expect(ReconnectPolicy.errorDelay(4), const Duration(seconds: 48));
    });

    test('caps at the last schedule entry', () {
      expect(ReconnectPolicy.errorDelay(5), const Duration(seconds: 48));
      expect(ReconnectPolicy.errorDelay(99), const Duration(seconds: 48));
    });
  });

  group('ReconnectPolicy.fatalErrors', () {
    test('permission denial and missing profile are never retried', () {
      expect(ReconnectPolicy.fatalErrors, contains('vpn_permission_denied'));
      expect(ReconnectPolicy.fatalErrors, contains('no_profile'));
      expect(ReconnectPolicy.fatalErrors, contains('unsupported_profile'));
    });

    test('transient core errors are retryable', () {
      expect(ReconnectPolicy.fatalErrors, isNot(contains('waycore_not_found')));
      expect(ReconnectPolicy.fatalErrors, isNot(contains('start_timeout')));
    });
  });

  test('maxErrorAttempts matches the error schedule length', () {
    expect(ReconnectPolicy.maxErrorAttempts, ReconnectPolicy.errorSchedule.length);
  });

  test('connecting stuck threshold is 90 seconds', () {
    expect(ReconnectPolicy.connectingStuckAfter, const Duration(seconds: 90));
  });
}
