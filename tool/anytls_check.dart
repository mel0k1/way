// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:way/core/config_builder.dart';
import 'package:way/core/formats.dart';
import 'package:way/core/parser.dart';

void main() {
  var failed = false;
  void check(bool ok, String label) {
    print('${ok ? 'ok' : 'FAIL'}: $label');
    if (!ok) failed = true;
  }

  // 1. URI parsing
  final p = LinkParser.parse(
      'anytls://p%40ss@1.2.3.4:8443?sni=example.com&insecure=1&fp=chrome&alpn=h2,h3#MyNode');
  check(p != null, 'anytls uri parsed');
  if (p != null) {
    check(p.protocol == 'anytls', 'protocol');
    check(p.server == '1.2.3.4' && p.port == 8443, 'host/port');
    check(p.password == 'p@ss', 'password decoded');
    check(p.sni == 'example.com', 'sni');
    check(p.insecure, 'insecure');
    check(p.fingerprint == 'chrome', 'fingerprint');
    check(p.alpn == 'h2,h3', 'alpn');
    check(p.supportedOn('singbox'), 'supported on singbox');
    check(!p.supportedOn('xray'), 'not supported on xray');

    // 2. sing-box config building
    final cfg = ConfigBuilder.singBoxConfig(
      p,
      tun: true,
      logPath: '/tmp/way.log',
    );
    final s = json.encode(cfg);
    check(s.contains('"type": "anytls"') || s.contains('"type":"anytls"'),
        'outbound type anytls');
    check(s.contains('p@ss') || s.contains('p\\u0040ss') || s.contains('p%40ss'),
        'password in config');
    check(s.contains('example.com'), 'tls server_name');
  }

  // 3. link roundtrip (QR export)
  if (p != null) {
    final link = LinkBuilder.build(p);
    check(link != null && link.startsWith('anytls://'), 'link built');
    if (link != null) {
      final p2 = LinkParser.parse(link);
      check(p2 != null && p2.password == p.password, 'roundtrip password');
      check(p2 != null && p2.sni == p.sni, 'roundtrip sni');
      check(p2 != null && p2.insecure == p.insecure, 'roundtrip insecure');
    }
  }

  // 4. sing-box JSON import
  final fromJson = SubFormats.singboxOutboundToProfile({
    'type': 'anytls',
    'tag': 'node',
    'server': '9.9.9.9',
    'server_port': 443,
    'password': 'topsecret',
    'tls': {
      'enabled': true,
      'server_name': 'cdn.example.net',
      'insecure': false,
    },
  });
  check(fromJson != null, 'singbox json import');
  if (fromJson != null) {
    check(fromJson.protocol == 'anytls', 'json protocol');
    check(fromJson.password == 'topsecret', 'json password');
    check(fromJson.sni == 'cdn.example.net', 'json sni');
  }

  // 5. no default sni when absent
  final p3 = LinkParser.parse('anytls://secret@5.6.7.8:443#NoSni');
  check(p3 != null && p3.sni == '5.6.7.8', 'sni fallback to host');

  if (failed) {
    print('ANYTLS_CHECK_FAILED');
    exit(1);
  }
  print('ANYTLS_ALL_OK');
}
