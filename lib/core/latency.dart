import 'dart:io';

import 'profile.dart';

class LatencyTester {
  static Future<Map<String, int?>> testAll(
    List<Profile> profiles, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final ids = profiles.map((p) => p.id).toList();
    final results = await Future.wait(
      profiles.map((p) => measure(p.server, p.port, timeout: timeout)),
    );
    return Map.fromIterables(ids, results);
  }

  static Future<int?> measure(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 5),
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
