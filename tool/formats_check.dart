// ignore_for_file: avoid_print, unnecessary_string_interpolations
import 'dart:convert';

import 'package:way/core/formats.dart';
import 'package:way/core/parser.dart';
import 'package:way/core/profile.dart';

void main() {
  final clash = '''
port: 7890
proxies:
  - name: "Reality Node"
    type: vless
    server: example.com
    port: 443
    uuid: 11111111-2222-3333-4444-555555555555
    flow: xtls-rprx-vision
    tls: true
    servername: www.example.com
    client-fingerprint: chrome
    reality-opts:
      public-key: PBKPBKPBK
      short-id: "0123abcd"
    network: tcp
  - name: "WS Node"
    type: vmess
    server: ws.example.com
    port: 443
    uuid: aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
    alterId: 0
    cipher: auto
    tls: true
    servername: ws.example.com
    network: ws
    ws-opts:
      path: /wspath
      headers:
        Host: host.example.com
  - name: "HY2"
    type: hysteria2
    server: hy.example.com
    port: 8443
    password: hunter2
    up: "30 Mbps"
    down: 200
  - name: "Unsupported SSH"
    type: ssh
    server: s.example.com
    port: 22
''';
  final fromClash = SubFormats.parseClashYaml(clash);
  _check('clash count', fromClash.length == 3, '${fromClash.length}');
  final r = fromClash[0];
  _check('clash reality', r.publicKey == 'PBKPBKPBK' && r.shortId == '0123abcd', '${r.publicKey}/${r.shortId}');
  _check('clash flow', r.flow == 'xtls-rprx-vision', '${r.flow}');
  _check('clash sni', r.sni == 'www.example.com', '${r.sni}');
  final w = fromClash[1];
  _check('clash ws', w.network == 'ws' && w.path == '/wspath' && w.host == 'host.example.com', '${w.network}/${w.path}/${w.host}');
  _check('clash vmess aid', w.alterId == 0, '${w.alterId}');
  final h = fromClash[2];
  _check('clash hy2', h.upMbps == 30 && h.downMbps == 200 && h.password == 'hunter2', '${h.upMbps}/${h.downMbps}');

  final sb = json.encode({
    'outbounds': [
      {
        'type': 'vless',
        'tag': 'SB Node',
        'server': 'sb.example.com',
        'server_port': 443,
        'uuid': '99999999-8888-7777-6666-555555555555',
        'flow': 'xtls-rprx-vision',
        'tls': {
          'enabled': true,
          'server_name': 'cdn.example.com',
          'utls': {'enabled': true, 'fingerprint': 'chrome'},
          'reality': {'enabled': true, 'public_key': 'SBPK', 'short_id': 'ab'},
        },
        'transport': {'type': 'ws', 'path': '/sb', 'headers': {'Host': 'h.com'}},
      },
      {'type': 'urltest', 'tag': 'auto'},
      {'type': 'direct', 'tag': 'direct'},
    ],
  });
  final fromSb = SubFormats.parseSingboxJson(sb);
  _check('sb count', fromSb.length == 1, '${fromSb.length}');
  final s0 = fromSb.first;
  _check('sb fields', s0.name == 'SB Node' && s0.server == 'sb.example.com' && s0.port == 443, '${s0.name}');
  _check('sb reality', s0.publicKey == 'SBPK' && s0.shortId == 'ab', '${s0.publicKey}');
  _check('sb fp', s0.fingerprint == 'chrome', '${s0.fingerprint}');
  _check('sb ws', s0.network == 'ws' && s0.path == '/sb' && s0.host == 'h.com', '${s0.network}');

  final link = LinkBuilder.build(s0);
  _check('link vless', link != null && link.startsWith('vless://99999999'), '$link');
  final round = LinkParser.parse(link!);
  _check('link roundtrip', round != null && round.publicKey == 'SBPK' && round.sni == 'cdn.example.com' && round.flow == 'xtls-rprx-vision', '${round?.publicKey}');
  final vm = LinkBuilder.build(fromClash[1]);
  final vmRound = LinkParser.parse(vm!);
  _check('vmess roundtrip', vmRound != null && vmRound.server == 'ws.example.com' && vmRound.path == '/wspath', '${vmRound?.server}');
  final ss = LinkBuilder.build(Profile(id: '1', name: 'SS', protocol: 'shadowsocks', server: 's.com', port: 8388, method: 'aes-128-gcm', password: 'pw'));
  final ssRound = LinkParser.parse(ss!);
  _check('ss roundtrip', ssRound != null && ssRound.method == 'aes-128-gcm' && ssRound.password == 'pw', '${ssRound?.method}');

  final uri = Uri.parse('clash://install-config?url=${Uri.encodeComponent('https://panel.example.com/sub?token=x')}&name=My');
  _check('wrapper uri', uri.host == 'install-config' && uri.queryParameters['url'] == 'https://panel.example.com/sub?token=x', '${uri.host} ${uri.queryParameters['url']}');

  print('ALL_OK');
}

void _check(String name, bool ok, String detail) {
  if (!ok) {
    throw StateError('FAIL: $name ($detail)');
  }
  print('ok: $name');
}
