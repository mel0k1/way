import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config_builder.dart';

/// One live connection as reported by the sing-box Clash API
/// (GET http://127.0.0.1:<clashApi>/connections).
class LiveConnection {
  final String id;
  final String host;
  final String destination;
  final String network;
  final String process;
  final String rule;
  final String rulePayload;
  final List<String> chains;
  final int upload;
  final int download;
  final int upSpeed;
  final int downSpeed;
  final DateTime start;

  const LiveConnection({
    required this.id,
    required this.host,
    required this.destination,
    required this.network,
    required this.process,
    required this.rule,
    required this.rulePayload,
    required this.chains,
    required this.upload,
    required this.download,
    required this.upSpeed,
    required this.downSpeed,
    required this.start,
  });

  String get bestHost => host.isNotEmpty ? host : destination;
}

class ConnectionsSnapshot {
  final List<LiveConnection> connections;
  final int totalUp;
  final int totalDown;
  /// False when the Clash API is unreachable (the VPN is not running).
  final bool ok;

  const ConnectionsSnapshot({
    required this.connections,
    required this.totalUp,
    required this.totalDown,
    required this.ok,
  });

  static const empty =
      ConnectionsSnapshot(connections: [], totalUp: 0, totalDown: 0, ok: false);

  int get upSpeed =>
      connections.fold(0, (n, c) => n + c.upSpeed);
  int get downSpeed =>
      connections.fold(0, (n, c) => n + c.downSpeed);
}

/// Polls the sing-box Clash API for live connections and derives
/// per-connection speeds from byte deltas between consecutive samples.
class ConnectionsPoller {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 2);

  final Map<String, List<int>> _prev = {}; // id -> [upload, download]
  DateTime _prevTime = DateTime.now();

  Future<ConnectionsSnapshot> fetch() async {
    try {
      final req = await _client.getUrl(
        Uri.parse('http://127.0.0.1:${WayPorts.clashApi}/connections'),
      );
      final res = await req.close();
      if (res.statusCode != 200) return ConnectionsSnapshot.empty;
      final text = await res.transform(utf8.decoder).join();
      final data = json.decode(text) as Map<String, dynamic>;
      final raw = (data['connections'] as List?) ?? const [];
      final totalUp = (data['uploadTotal'] as num?)?.toInt() ?? 0;
      final totalDown = (data['downloadTotal'] as num?)?.toInt() ?? 0;
      final now = DateTime.now();
      final dt = now.difference(_prevTime).inMilliseconds;
      final conns = <LiveConnection>[];
      final seen = <String>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final meta = (item['metadata'] as Map?) ?? const {};
        final id = '${item['id'] ?? ''}';
        final upload = (item['upload'] as num?)?.toInt() ?? 0;
        final download = (item['download'] as num?)?.toInt() ?? 0;
        var upSpeed = 0;
        var downSpeed = 0;
        final prev = _prev[id];
        if (prev != null &&
            dt > 200 &&
            upload >= prev[0] &&
            download >= prev[1]) {
          upSpeed = ((upload - prev[0]) * 1000 / dt).round();
          downSpeed = ((download - prev[1]) * 1000 / dt).round();
        }
        _prev[id] = [upload, download];
        seen.add(id);
        conns.add(LiveConnection(
          id: id,
          host: '${meta['host'] ?? ''}'.trim(),
          destination: '${meta['destinationIP'] ?? ''}:'
              '${meta['destinationPort'] ?? ''}',
          network: '${meta['network'] ?? ''}',
          process: '${meta['process'] ?? ''}'.trim(),
          rule: '${item['rule'] ?? ''}',
          rulePayload: '${item['rulePayload'] ?? ''}',
          chains: ((item['chains'] as List?) ?? const [])
              .map((e) => '$e')
              .toList(),
          upload: upload,
          download: download,
          upSpeed: upSpeed,
          downSpeed: downSpeed,
          start: DateTime.tryParse('${item['start'] ?? ''}') ?? now,
        ));
      }
      // Drop counters for connections that have already been closed, so a
      // reconnecting host starts with a clean speed baseline.
      _prev.removeWhere((k, _) => !seen.contains(k));
      _prevTime = now;
      conns.sort((a, b) {
        final bySpeed = (b.upSpeed + b.downSpeed).compareTo(a.upSpeed + a.downSpeed);
        if (bySpeed != 0) return bySpeed;
        return b.download.compareTo(a.download);
      });
      return ConnectionsSnapshot(
        connections: conns,
        totalUp: totalUp,
        totalDown: totalDown,
        ok: true,
      );
    } catch (_) {
      _prev.clear();
      _prevTime = DateTime.now();
      return ConnectionsSnapshot.empty;
    }
  }

  /// Kills one connection (Clash API: DELETE /connections/{id}).
  Future<bool> close(String id) async {
    try {
      final req = await _client.openUrl(
        'DELETE',
        Uri.parse('http://127.0.0.1:${WayPorts.clashApi}/connections/$id'),
      );
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Kills every connection (Clash API: DELETE /connections).
  Future<bool> closeAll() async {
    try {
      final req = await _client.openUrl(
        'DELETE',
        Uri.parse('http://127.0.0.1:${WayPorts.clashApi}/connections'),
      );
      final res = await req.close();
      await res.drain<void>();
      return res.statusCode == 200 || res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// One-shot fetch used by the rule-detect screen to find live evidence for
  /// a specific domain.
  Future<List<LiveConnection>> findForDomain(String domain) async {
    final snap = await fetch();
    if (!snap.ok || domain.isEmpty) return const [];
    final d = domain.toLowerCase();
    return snap.connections
        .where((c) =>
            c.host.toLowerCase() == d ||
            c.host.toLowerCase().endsWith('.$d') ||
            c.destination.toLowerCase().startsWith(d))
        .toList();
  }

  void dispose() {
    _client.close(force: true);
  }
}
