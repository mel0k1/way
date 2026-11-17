import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One day of tunnel traffic: every session's counters summed into the
/// day's bucket.
class DayTraffic {
  final int epochDay;
  final int rx;
  final int tx;

  const DayTraffic(this.epochDay, this.rx, this.tx);
}

/// The week's daily traffic totals, kept across runs so the weekly chart
/// survives restarts and disconnected days: Chumpy's DailyTrafficStore
/// ported. Only aggregate byte counts live here: no addresses, no keys,
/// nothing the panel ever said. Deltas are accumulated in memory and
/// flushed to today's bucket about once a minute: a write a minute at most.
class TrafficHistory {
  static const _fileName = 'daily-traffic.json';
  static const _version = 1;

  int _pendingRx = 0;
  int _pendingTx = 0;
  DateTime _lastFlush = DateTime.now();

  static int dayEpoch(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      86400000;

  static int _today() => dayEpoch(DateTime.now());

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// The last seven days' buckets, oldest first; missing days simply
  /// aren't in the list.
  Future<List<DayTraffic>> readWeek() async {
    try {
      final file = await _file();
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['version'] != _version) return const [];
      final raw = json['days'] as List? ?? const [];
      final firstDay = _today() - 6;
      final days = <DayTraffic>[];
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        final bucket = DayTraffic(
          (entry['day'] as num?)?.toInt() ?? 0,
          (entry['rx'] as num?)?.toInt() ?? 0,
          (entry['tx'] as num?)?.toInt() ?? 0,
        );
        if (bucket.epochDay >= firstDay &&
            bucket.epochDay <= firstDay + 6 &&
            bucket.rx >= 0 &&
            bucket.tx >= 0) {
          days.add(bucket);
        }
      }
      days.sort((a, b) => a.epochDay.compareTo(b.epochDay));
      return days;
    } catch (_) {
      return const [];
    }
  }

  /// Adds this tick's delta to the in-memory bucket; on the minute boundary
  /// the bucket is flushed to disk and the fresh week comes back (null —
  /// not flushed yet, keep the old chart).
  Future<List<DayTraffic>?> add(int up, int down) async {
    if (up < 0 || down < 0) return null;
    _pendingTx += up;
    _pendingRx += down;
    final now = DateTime.now();
    if (now.difference(_lastFlush).inMinutes >= 1) {
      _lastFlush = now;
      return flush();
    }
    return null;
  }

  /// Pushes whatever is pending (disconnect, pause, shutdown).
  Future<List<DayTraffic>> flush() async {
    _lastFlush = DateTime.now();
    final week = await _addDay(_today(), _pendingRx, _pendingTx);
    _pendingRx = 0;
    _pendingTx = 0;
    return week;
  }

  Future<List<DayTraffic>> _addDay(int today, int rx, int tx) async {
    final days = (await readWeek()).toList();
    if (rx > 0 || tx > 0) {
      final index = days.indexWhere((d) => d.epochDay == today);
      if (index >= 0) {
        days[index] = DayTraffic(today, days[index].rx + rx, days[index].tx + tx);
      } else {
        days.add(DayTraffic(today, rx, tx));
      }
      days.sort((a, b) => a.epochDay.compareTo(b.epochDay));
      if (days.length > 7) days.removeRange(0, days.length - 7);
      await _write(days);
    }
    return days;
  }

  Future<void> _write(List<DayTraffic> days) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    final json = jsonEncode({
      'version': _version,
      'days': [
        for (final d in days) {'day': d.epochDay, 'rx': d.rx, 'tx': d.tx},
      ],
    });
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(file.path);
  }
}
