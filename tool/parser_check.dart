// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:way/core/config_builder.dart';
import 'package:way/core/parser.dart';

void main(List<String> args) {
  final raw = File(args[0]).readAsStringSync();
  final decoded = utf8.decode(base64.decode(raw.trim().replaceAll('\n', '')));
  final profiles = LinkParser.parseMany(decoded);
  print('parsed: ${profiles.length}');
  final groups = <String, int>{};
  for (final p in profiles) {
    final net = p.network ?? 'tcp';
    groups[net] = (groups[net] ?? 0) + 1;
  }
  print('networks: $groups');

  final real = profiles.where((p) => p.server != '0.0.0.0').toList();
  print('real nodes: ${real.length}');
  for (final p in real.take(4)) {
    print('--- ${p.name}');
    print('    ${p.protocol} ${p.server}:${p.port} net=${p.network} sni=${p.sni} fp=${p.fingerprint}');
    print('    pbk=${p.publicKey?.substring(0, 8)}… sid=${p.shortId} flow=${p.flow} alpn=${p.alpn}');
  }

  final first = real.first;
  final sb = ConfigBuilder.singBoxConfig(first, tun: false, logPath: '/tmp/t.log');
  print('--- sing-box outbounds: ${sb['outbounds'].map((o) => o['tag']).toList()}');
  final proxy = sb['outbounds'].first as Map<String, dynamic>;
  print('    reality: ${proxy['tls']?['reality']}');
  print('    utls: ${proxy['tls']?['utls']}');

  final group = real;
  final sbGroup = ConfigBuilder.singBoxConfig(
    group.first,
    tun: false,
    logPath: '/tmp/t.log',
    group: group,
  );
  final ob = sbGroup['outbounds'] as List;
  final urltest = ob.firstWhere((o) => o['type'] == 'urltest') as Map<String, dynamic>;
  print('--- urltest members: ${(urltest['outbounds'] as List).length}');
  print('    outbounds total: ${ob.length}');

  final xhttp = real.firstWhere((p) => p.network == 'xhttp');
  final xr = ConfigBuilder.xrayConfig(xhttp, logPath: '/tmp/t.log');
  final xob = xr['outbounds'].first as Map<String, dynamic>;
  final xs = xob['streamSettings'] as Map<String, dynamic>;
  print('--- xray xhttp: net=${xs['network']} sec=${xs['security']}');
  print('    xhttpSettings keys: ${(xs['xhttpSettings'] as Map).keys.toList()}');
  print('    mode: ${(xs['xhttpSettings'] as Map)['mode']}');

  final sbAuto = profiles.where((p) => p.supportedOn('singbox')).length;
  final xrAuto = profiles.where((p) => p.supportedOn('xray')).length;
  print('--- capability: singbox=$sbAuto xray=$xrAuto');
}
