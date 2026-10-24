import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'version.dart';

class UpdateInfo {
  final String version;
  final String? notes;
  final String? downloadUrl;
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.version,
    this.notes,
    this.downloadUrl,
    this.publishedAt,
  });
}

class UpdateChecker {
  static Uri _latestUri() =>
      Uri.parse('https://api.github.com/repos/$releaseRepo/releases/latest');

  static String _assetSuffix() {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return '-android.apk';
    if (Platform.isWindows) return '-setup.exe';
    return '';
  }

  static Future<UpdateInfo?> fetchLatest() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(_latestUri());
      req.headers.set('Accept', 'application/vnd.github+json');
      req.headers.set('User-Agent', 'Way/$appVersion');
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode != 200) return null;
      final data = json.decode(text) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?) ?? '';
      final version = tag.startsWith('v') ? tag.substring(1) : tag;
      if (version.isEmpty) return null;
      String? url;
      final suffix = _assetSuffix();
      final assets = (data['assets'] as List?) ?? const [];
      for (final a in assets) {
        if (a is Map && suffix.isNotEmpty) {
          final name = '${a['name']}';
          if (name.endsWith(suffix)) {
            url = '${a['browser_download_url']}';
            break;
          }
        }
      }
      final published = DateTime.tryParse('${data['published_at']}');
      return UpdateInfo(
        version: version,
        notes: data['body'] as String?,
        downloadUrl: url,
        publishedAt: published?.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  static bool isNewer(String latest, String current) {
    List<int> parse(String v) => v
        .split(RegExp(r'[.+\-]'))
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    final a = parse(latest);
    final b = parse(current);
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<void> openUrl(String url) async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      try {
        await const MethodChannel('way/core')
            .invokeMethod('open_url', {'url': url});
      } on PlatformException {
        return;
      }
      return;
    }
    try {
      if (Platform.isWindows) {
        await Process.run(
          'rundll32',
          ['url.dll,FileProtocolHandler', url],
          runInShell: false,
        );
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {
      return;
    }
  }
}
