import 'dart:io';

/// Download speed test through the current route.
///
/// When the tunnel is up all traffic goes through the VPN, so a plain HTTPS
/// download measures the tunnel; when it is down it measures the direct link.
class SpeedTester {
  static const _endpoints = [
    'https://speed.cloudflare.com/__down?bytes=52428800',
    'https://proof.ovh.net/files/10Mb.dat',
  ];

  /// Streams a random payload for at most [limit] and returns Mbps.
  /// Returns null when nothing could be downloaded.
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
        // Truncated on purpose or by the proxy — the sample still counts.
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
