import 'dart:convert';

import 'profile.dart';

class LinkParser {
  static Profile? parse(String raw) {
    final line = raw.trim();
    if (line.isEmpty) return null;
    if (line.startsWith('vmess://')) return _parseVmess(line);
    if (line.startsWith('ss://')) return _parseSs(line);
    final scheme = line.split('://').first.toLowerCase();
    try {
      final uri = Uri.parse(line);
      switch (scheme) {
        case 'vless':
          return _parseVless(uri);
        case 'trojan':
          return _parseTrojan(uri);
        case 'hysteria2':
        case 'hy2':
          return _parseHysteria2(uri);
        case 'tuic':
          return _parseTuic(uri);
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  static List<Profile> parseMany(String text) {
    final result = <Profile>[];
    final decoded = _tryDecodeBase64(text);
    final source = decoded ?? text;
    for (final line in LineSplitter.split(source)) {
      final p = parse(line);
      if (p != null) result.add(p);
    }
    if (result.isEmpty) {
      final p = parse(text);
      if (p != null) result.add(p);
    }
    return result;
  }

  static String? _tryDecodeBase64(String s) {
    final t = s.replaceAll('\n', '').replaceAll('\r', '').trim();
    if (t.contains('://')) return null;
    try {
      final normalized = base64Url.normalize(t);
      return utf8.decode(base64Url.decode(normalized));
    } catch (_) {
      try {
        final normalized = base64.normalize(t);
        return utf8.decode(base64.decode(normalized));
      } catch (_) {
        return null;
      }
    }
  }

  static String _q(Uri uri, String key, [String fallback = '']) {
    return uri.queryParameters[key] ?? fallback;
  }

  static Profile _parseVless(Uri uri) {
    final type = _q(uri, 'type', 'tcp');
    return Profile(
      id: _genId(),
      name: Uri.decodeComponent(uri.fragment.isNotEmpty ? uri.fragment : 'VLESS'),
      protocol: 'vless',
      server: uri.host,
      port: uri.port,
      uuid: uri.userInfo,
      flow: _q(uri, 'flow'),
      network: type,
      path: _q(uri, 'path', '/'),
      host: _q(uri, 'host'),
      sni: _q(uri, 'sni').isEmpty ? _q(uri, 'host') : _q(uri, 'sni'),
      fingerprint: _q(uri, 'fp'),
      publicKey: _q(uri, 'pbk'),
      shortId: _q(uri, 'sid'),
      insecure: _q(uri, 'allowInsecure') == '1' || _q(uri, 'insecure') == '1',
      alpn: _q(uri, 'alpn'),
      mode: _q(uri, 'mode'),
      extra: _q(uri, 'extra'),
    );
  }

  static Profile _parseTrojan(Uri uri) {
    final type = _q(uri, 'type', 'tcp');
    return Profile(
      id: _genId(),
      name: Uri.decodeComponent(uri.fragment.isNotEmpty ? uri.fragment : 'Trojan'),
      protocol: 'trojan',
      server: uri.host,
      port: uri.port,
      password: Uri.decodeComponent(uri.userInfo),
      network: type,
      path: _q(uri, 'path', '/'),
      host: _q(uri, 'host'),
      sni: _q(uri, 'sni').isEmpty ? uri.host : _q(uri, 'sni'),
      fingerprint: _q(uri, 'fp'),
      insecure: _q(uri, 'allowInsecure') == '1',
      alpn: _q(uri, 'alpn'),
    );
  }

  static Profile _parseHysteria2(Uri uri) {
    final userInfo = Uri.decodeComponent(uri.userInfo);
    return Profile(
      id: _genId(),
      name: Uri.decodeComponent(uri.fragment.isNotEmpty ? uri.fragment : 'Hysteria2'),
      protocol: 'hysteria2',
      server: uri.host,
      port: uri.port,
      password: userInfo,
      sni: _q(uri, 'sni').isEmpty ? uri.host : _q(uri, 'sni'),
      insecure: _q(uri, 'insecure') == '1' || _q(uri, 'allowInsecure') == '1',
      upMbps: int.tryParse(_q(uri, 'upmbps')),
      downMbps: int.tryParse(_q(uri, 'downmbps')),
    );
  }

  static Profile _parseTuic(Uri uri) {
    final userInfo = Uri.decodeComponent(uri.userInfo);
    final parts = userInfo.split(':');
    return Profile(
      id: _genId(),
      name: Uri.decodeComponent(uri.fragment.isNotEmpty ? uri.fragment : 'TUIC'),
      protocol: 'tuic',
      server: uri.host,
      port: uri.port,
      uuid: parts.isNotEmpty ? parts[0] : '',
      password: parts.length > 1 ? parts.sublist(1).join(':') : '',
      congestion: _q(uri, 'congestion_control', 'bbr'),
      sni: _q(uri, 'sni').isEmpty ? uri.host : _q(uri, 'sni'),
      insecure: _q(uri, 'allow_insecure') == '1',
      alpn: _q(uri, 'alpn', 'h3'),
    );
  }

  static Profile _parseVmess(String raw) {
    final decoded = _tryDecodeBase64(raw.substring(8));
    if (decoded == null) {
      final uri = Uri.parse(raw);
      return Profile(
        id: _genId(),
        name: Uri.decodeComponent(uri.fragment),
        protocol: 'vmess',
        server: uri.host,
        port: uri.port,
        uuid: uri.userInfo,
        sni: _q(uri, 'sni'),
      );
    }
    final map = json.decode(decoded) as Map<String, dynamic>;
    final net = (map['net'] as String?) ?? 'tcp';
    final tls = (map['tls'] as String?) ?? '';
    return Profile(
      id: _genId(),
      name: (map['ps'] as String?) ?? 'VMess',
      protocol: 'vmess',
      server: (map['add'] as String?) ?? '',
      port: int.tryParse('${map['port']}') ?? 443,
      uuid: (map['id'] as String?) ?? '',
      alterId: int.tryParse('${map['aid'] ?? 0}') ?? 0,
      security: (map['scy'] as String?) ?? 'auto',
      network: net,
      path: (map['path'] as String?) ?? '/',
      host: (map['host'] as String?) ?? '',
      sni: (map['sni'] as String?) ?? (map['host'] as String?) ?? '',
      fingerprint: (map['fp'] as String?) ?? '',
      insecure: tls == 'tls' && ((map['allowInsecure'] as bool?) ?? false),
      alpn: (map['alpn'] as String?) ?? '',
    );
  }

  static Profile? _parseSs(String raw) {
    final body = raw.substring(5);
    final hashIndex = body.indexOf('#');
    final fragment = hashIndex >= 0 ? Uri.decodeComponent(body.substring(hashIndex + 1)) : 'SS';
    var main = hashIndex >= 0 ? body.substring(0, hashIndex) : body;
    final queryIndex = main.indexOf('?');
    main = queryIndex >= 0 ? main.substring(0, queryIndex) : main;
    String userInfo;
    String hostPart;
    if (main.contains('@')) {
      final at = main.lastIndexOf('@');
      userInfo = main.substring(0, at);
      hostPart = main.substring(at + 1);
      final decodedUser = _tryDecodeBase64(userInfo);
      userInfo = decodedUser ?? userInfo;
    } else {
      final decoded = _tryDecodeBase64(main);
      if (decoded == null) return null;
      final at = decoded.lastIndexOf('@');
      if (at < 0) return null;
      userInfo = decoded.substring(0, at);
      hostPart = decoded.substring(at + 1);
    }
    final colon = userInfo.indexOf(':');
    if (colon < 0) return null;
    final method = userInfo.substring(0, colon);
    final password = userInfo.substring(colon + 1);
    final hostColon = hostPart.lastIndexOf(':');
    if (hostColon < 0) return null;
    final port = int.tryParse(hostPart.substring(hostColon + 1));
    if (port == null) return null;
    return Profile(
      id: _genId(),
      name: fragment,
      protocol: 'shadowsocks',
      server: hostPart.substring(0, hostColon),
      port: port,
      method: method,
      password: password,
    );
  }

  static String _genId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      (1000 + (DateTime.now().microsecond % 9000)).toRadixString(36);
}
