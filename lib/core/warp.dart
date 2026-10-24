import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import 'parser.dart';
import 'profile.dart';

class WarpService {
  static const _apiBase = 'https://api.cloudflareclient.com/v0a2158/reg';
  static const _peerKey = 'bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=';
  static const _endpointHost = 'engage.cloudflareclient.com';
  static const _endpointPort = 2408;

  static Future<Profile> register() async {
    final algo = X25519();
    final keyPair = await algo.newKeyPair();
    final pub = await keyPair.extractPublicKey();
    final priv = await keyPair.extractPrivateKeyBytes();
    final pubB64 = base64.encode(pub.bytes);
    final res = await http.post(
      Uri.parse(_apiBase),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'okhttp/3.12.1',
        'Accept': 'application/json',
      },
      body: json.encode({
        'key': pubB64,
        'install_id': '',
        'fcm_token': '',
        'tos': DateTime.now().toUtc().toIso8601String(),
        'model': 'Way',
        'serial_number': LinkParser.genId(),
        'locale': 'en_US',
      }),
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('WARP HTTP ${res.statusCode}');
    }
    final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final config = data['config'] as Map<String, dynamic>? ?? const {};
    final peers = config['peers'] as List? ?? const [];
    final peer = peers.isNotEmpty ? peers.first as Map<String, dynamic> : const {};
    final interface = config['interface'] as Map<String, dynamic>? ?? const {};
    final addresses = interface['addresses'] as Map<String, dynamic>? ?? const {};
    final clientId = _s(data['client_id']);
    var reserved = <int>[];
    if (clientId.isNotEmpty) {
      try {
        reserved = base64.decode(clientId).toList();
      } catch (_) {}
    }
    if (reserved.length != 3) reserved = [0, 0, 0];
    final endpoint = peer['endpoint'] as Map<String, dynamic>? ?? const {};
    final v4 = _s(endpoint['v4']);
    String host = _endpointHost;
    int port = _endpointPort;
    if (v4.contains(':')) {
      final parts = v4.split(':');
      host = parts.first;
      port = int.tryParse(parts.last) ?? port;
    }
    final extra = json.encode({
      'reserved': reserved,
      'address_v4': _s(addresses['v4']).isEmpty ? '172.16.0.2/32' : _s(addresses['v4']),
      'address_v6': _s(addresses['v6']),
    });
    return Profile(
      id: LinkParser.genId(),
      name: 'Cloudflare WARP',
      protocol: 'wireguard',
      server: host,
      port: port,
      password: base64.encode(priv),
      publicKey: _s(peer['public_key']).isEmpty ? _peerKey : _s(peer['public_key']),
      extra: extra,
    );
  }

  static String _s(dynamic v) => v == null ? '' : '$v'.trim();
}
