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

  Subscription({
    required this.id,
    required this.name,
    required this.url,
    this.lastUpdate,
    this.count = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'last_update': lastUpdate?.toIso8601String(),
    'count': count,
  };

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    url: j['url'] as String? ?? '',
    lastUpdate: j['last_update'] != null
        ? DateTime.tryParse(j['last_update'] as String)
        : null,
    count: (j['count'] as num?)?.toInt() ?? 0,
  );
}

class SubscriptionService {
  Future<List<Profile>> fetch(Subscription sub, {String subId = ''}) async {
    final res = await http
        .get(Uri.parse(sub.url))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final profiles = LinkParser.parseMany(utf8.decode(res.bodyBytes));
    for (final p in profiles) {
      p.subId = subId.isEmpty ? sub.id : subId;
      if (p.name.isEmpty) p.name = sub.name;
    }
    return profiles;
  }
}
