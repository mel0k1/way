import 'dart:convert';
import 'dart:io';

import 'config_builder.dart';

class WayStats {
  final int upSpeed;
  final int downSpeed;
  final int totalUp;
  final int totalDown;
  final int connections;

  const WayStats({
    this.upSpeed = 0,
    this.downSpeed = 0,
    this.totalUp = 0,
    this.totalDown = 0,
    this.connections = 0,
  });

  static const zero = WayStats();
}

class StatsPoller {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2);

  int _prevUp = -1;
  int _prevDown = -1;
  DateTime _prevTime = DateTime.now();

  void reset() {
    _prevUp = -1;
    _prevDown = -1;
  }

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
      final totalUp = (data['uploadTotal'] as num?)?.toInt() ?? 0;
      final totalDown = (data['downloadTotal'] as num?)?.toInt() ?? 0;
      final now = DateTime.now();
      var upSpeed = 0;
      var downSpeed = 0;
      if (_prevUp >= 0 &&
          totalUp >= _prevUp &&
          totalDown >= _prevDown &&
          _prevUp + _prevDown > 0) {
        final dt = now.difference(_prevTime).inMilliseconds;
        if (dt > 200) {
          upSpeed = ((totalUp - _prevUp) * 1000 / dt).round();
          downSpeed = ((totalDown - _prevDown) * 1000 / dt).round();
        }
      }
      _prevUp = totalUp;
      _prevDown = totalDown;
      _prevTime = now;
      return WayStats(
        upSpeed: upSpeed,
        downSpeed: downSpeed,
        totalUp: totalUp,
        totalDown: totalDown,
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
