import 'dart:convert';
import 'dart:io';

import 'package:way/core/config_builder.dart';
import 'package:way/core/subscriptions.dart';

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<void> main() async {
  final url = Platform.environment['WAY_TEST_SUB'] ?? '';
  if (url.isEmpty) {
    stderr.writeln('WAY_TEST_SUB required');
    exit(2);
  }
  final sub = Subscription(id: 't', name: 't', url: url);
  final service = SubscriptionService();
  final profiles = await service.fetch(
    sub,
    userAgent: 'v2rayTun/1.7.6',
    hwid: '5f1c2d3e-1111-4222-8333-444455556666',
  );
  print('fetched ${profiles.length} profiles');
  if (profiles.isEmpty) exit(3);
  final p = profiles.firstWhere(
    (x) => x.supportedOn('singbox'),
    orElse: () => profiles.first,
  );
  print('testing ${p.name} (${p.protocolLabel}) ${p.server}:${p.port}');
  final port = await _freePort();
  final config = json.encode(ConfigBuilder.probeSingBoxConfig(p, port));
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  final req = await client.postUrl(Uri.parse('http://127.0.0.1:20717/urltest'));
  req.headers.set('Content-Type', 'application/json');
  req.add(utf8.encode(json.encode({
    'singbox': config,
    'xray': '',
    'port': port,
    'timeout': 8000,
  })));
  final res = await req.close().timeout(const Duration(seconds: 25));
  final text = await res.transform(utf8.decoder).join();
  print('status ${res.statusCode}: $text');
  client.close();
  exit(0);
}
