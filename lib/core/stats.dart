import 'dart:convert';
import 'dart:io';

import 'config_builder.dart';

class WayStats {
  final int upBytes;
  final int downBytes;
  final int totalUp;
  final int totalDown;
  final int connections;

  const WayStats({
    this.upBytes = 0,
    this.downBytes = 0,
    this.totalUp = 0,
    this.totalDown = 0,
    this.connections = 0,
  });

  static const zero = WayStats();
}

class StatsPoller {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2);

  Future<WayStats> fetch() async {
    try {
      final req = await _client.getUrl(
        Uri.parse('http://127.0.0.1:${WayPorts.clashApi}/connections'),
      );
      final res = await req.close();
      if (res.statusCode != 200) {
        return WayStats.zero;
      }
      final text = await res.transform(utf8.decoder).join();
      final data = json.decode(text) as Map<String, dynamic>;
      final conns = data['connections'] as List?;
      int up = 0;
      int down = 0;
      if (conns != null) {
        for (final c in conns) {
          if (c is Map<String, dynamic>) {
            final upload = c['upload'] as num?;
            final download = c['download'] as num?;
            up += upload?.toInt() ?? 0;
            down += download?.toInt() ?? 0;
          }
        }
      }
      return WayStats(
        upBytes: up,
        downBytes: down,
        totalUp: (data['uploadTotal'] as num?)?.toInt() ?? 0,
        totalDown: (data['downloadTotal'] as num?)?.toInt() ?? 0,
        connections: conns?.length ?? 0,
      );
    } catch (_) {
      return WayStats.zero;
    }
  }

  void dispose() {
    _client.close(force: true);
  }
}
