import 'dart:io';

import 'profile.dart';
import 'vpn_bridge.dart';

class LatencyTester {
  static Future<Map<String, int?>> testAll(
    List<Profile> profiles,
    VpnBridge bridge, {
    Duration timeout = const Duration(seconds: 6),
    int concurrency = 4,
  }) async {
    final queue = List<Profile>.from(profiles);
    final results = <String, int?>{};
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final p = queue.removeLast();
        results[p.id] = await measure(p, bridge, timeout: timeout);
      }
    }
    if (profiles.isNotEmpty) {
      await Future.wait(
        List.generate(concurrency.clamp(1, profiles.length), (_) => worker()),
      );
    }
    return results;
  }

  static Future<int?> measure(
    Profile profile,
    VpnBridge bridge, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    int? ms;
    try {
      ms = await bridge.urlTest(profile: profile, timeout: timeout);
    } catch (_) {
      ms = null;
    }
    if (ms == null) {
      return tcp(profile.server, profile.port, timeout: const Duration(seconds: 4));
    }
    return ms >= 0 ? ms : null;
  }

  static Future<int?> tcp(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      final watch = Stopwatch()..start();
      final socket = await Socket.connect(host, port, timeout: timeout);
      watch.stop();
      socket.destroy();
      return watch.elapsedMilliseconds;
    } catch (_) {
      return null;
    }
  }
}
