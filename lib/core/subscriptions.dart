import 'dart:convert';

import 'package:http/http.dart' as http;

import 'parser.dart';
import 'profile.dart';

class Subscription {
  String id;
  String name;
  String url;
  DateTime? lastUpdate;
  int count;
  int usedBytes;
  int totalBytes;
  DateTime? expiresAt;

  Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.lastUpdate,
    this.count = 0,
    this.usedBytes = 0,
    this.totalBytes = 0,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'last_update': lastUpdate?.toIso8601String(),
    'count': count,
    'used_bytes': usedBytes,
    'total_bytes': totalBytes,
    'expires_at': expiresAt?.toIso8601String(),
  };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    url: j['url'] as String? ?? '',
    lastUpdate: j['last_update'] != null
        ? DateTime.tryParse(j['last_update'] as String)
        : null,
    count: (j['count'] as num?)?.toInt() ?? 0,
    usedBytes: (j['used_bytes'] as num?)?.toInt() ?? 0,
    totalBytes: (j['total_bytes'] as num?)?.toInt() ?? 0,
    expiresAt: j['expires_at'] != null
        ? DateTime.tryParse(j['expires_at'] as String)
        : null,
  );
}

class SubscriptionService {
  Future<List<Profile>> fetch(
    Subscription sub, {
    String subId = '',
    String? userAgent,
    String? hwid,
  }) async {
    final req = http.Request('GET', Uri.parse(sub.url));
    if (userAgent != null && userAgent.isNotEmpty) {
      req.headers['User-Agent'] = userAgent;
    }
    if (hwid != null && hwid.isNotEmpty) {
      req.headers['x-hwid'] = hwid;
    }
    final res = await req.send().timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final headers = res.headers;
    final bytes = <int>[];
    await for (final chunk in res.stream) {
      bytes.addAll(chunk);
    }
    final profiles = LinkParser.parseMany(utf8.decode(bytes));
    _applyHeaders(sub, headers);
    for (final p in profiles) {
      p.subId = subId.isEmpty ? sub.id : subId;
      if (p.name.isEmpty) p.name = sub.name;
    }
    return profiles;
  }

  String? _header(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) return entry.value;
    }
    return null;
  }

  void _applyHeaders(Subscription sub, Map<String, String> headers) {
    final info = _header(headers, 'subscription-userinfo');
    if (info != null) {
      var used = 0;
      for (final part in info.split(';')) {
        final kv = part.split('=');
        if (kv.length != 2) continue;
        final value = int.tryParse(kv[1].trim());
        if (value == null) continue;
        switch (kv[0].trim().toLowerCase()) {
          case 'upload':
            used += value;
            break;
          case 'download':
            used += value;
            break;
          case 'total':
            sub.totalBytes = value;
            break;
          case 'expire':
            if (value > 0) {
              sub.expiresAt =
                  DateTime.fromMillisecondsSinceEpoch(value * 1000);
            }
            break;
        }
      }
      sub.usedBytes = used;
    }
    final title = _header(headers, 'profile-title');
    if (title != null &&
        (sub.name.isEmpty || sub.name == 'Subscription')) {
      if (title.startsWith('base64:')) {
        try {
          final decoded = utf8.decode(
            base64.decode(title.substring(7).trim()),
          );
          if (decoded.isNotEmpty) sub.name = decoded;
        } catch (_) {}
      } else if (title.trim().isNotEmpty) {
        sub.name = title.trim();
      }
    }
  }
}
