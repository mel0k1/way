import 'dart:io';

class SpeedTester {
  static const _endpoints = [
    'https://speed.cloudflare.com/__down?bytes=52428800',
    'https://proof.ovh.net/files/10Mb.dat',
  ];

  static Future<double?> measure({Duration limit = const Duration(seconds: 8)}) async {
    for (final url in _endpoints) {
      final result = await _download(url, limit);
      if (result != null && result > 0.05) return result;
    }
    return null;
  }

  static Future<double?> _download(String url, Duration limit) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6)
      ..userAgent = 'Way/1.0 speedtest';
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(limit);
      if (response.statusCode != 200) return null;
      final watch = Stopwatch()..start();
      var bytes = 0;
      try {
        await for (final chunk in response) {
          bytes += chunk.length;
          if (watch.elapsed >= limit) break;
        }
      } catch (_) {
      }
      watch.stop();
      final seconds = watch.elapsedMilliseconds / 1000.0;
      if (seconds < 0.4 || bytes < 64 * 1024) return null;
      return bytes * 8 / seconds / 1e6;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
